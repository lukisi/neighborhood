using Gee;
using zcd;
using Tasklets;

namespace Netsukuku
{
    public interface INodeID : Object, ISerializable
    {
        public abstract bool equals(INodeID other);
        public abstract bool is_on_same_network(INodeID other);
    }

    public errordomain GetRttError {
        GENERIC
    }

    public interface INetworkInterface : Object
    {
        public abstract string dev {get;}
        public abstract string mac {get;}
        public abstract long get_usec_rtt(uint guid) throws GetRttError;
        public abstract void prepare_ping(uint guid);
        public abstract bool equals(INetworkInterface other);
    }

    public interface IArc : Object
    {
        public abstract INodeID neighbour_id {get;}
        public abstract string mac {get;}
        public abstract REM cost {get;}
        public abstract bool is_nic(INetworkInterface nic);
        public abstract bool equals(IArc other);
    }

    internal class RealArc : Object, IArc
    {
        private INodeID _neighbour_id;
        private string _mac;
        private REM _cost;
        private INetworkInterface _my_nic;
        public bool available;

        public RealArc(INodeID neighbour_id,
                       string mac,
                       INetworkInterface my_nic)
        {
            _neighbour_id = neighbour_id;
            _mac = mac;
            _my_nic = my_nic;
            available = true;
        }

        public INetworkInterface my_nic {
            get {
                return _my_nic;
            }
        }

        public void set_cost(REM cost)
        {
            _cost = cost;
            available = true;
        }

        /* Public interface IArc
         */

        public bool is_nic(INetworkInterface nic)
        {
            return my_nic.equals(nic);
        }

        public bool equals(IArc other)
        {
            // This kind of equality test is ok as long as I am sure
            // that this module is the only able to create an instance
            // of IArc and that it won't create more than one instance
            // for each arc.
            return other == this;
        }

        public INodeID neighbour_id {
            get {
                return _neighbour_id;
            }
        }
        public string mac {
            get {
                return _mac;
            }
        }
        public REM cost {
            get {
                return _cost;
            }
        }
    }

    /* Get a client to call a unicast remote method
     */
    public delegate IAddressManagerRootDispatcher
    GetUnicast(UnicastID ucid, INetworkInterface nic, bool wait_reply=true);

    /* Get a client to call a broadcast remote method
     */
    public delegate void MissingAckFrom(IArc arc);
    public delegate IAddressManagerRootDispatcher
    GetBroadcast(BroadcastID bcid,
                 Gee.Collection<INetworkInterface> nics,
                 MissingAckFrom missing) throws RPCError;

    public class NeighborhoodManager : Object, INeighborhoodManager
    {
        public NeighborhoodManager(INodeID my_id,
                                   int max_arcs,
                                   GetUnicast callback_unicast,
                                   GetBroadcast callback_broadcast)
        {
            this.my_id = my_id;
            this.max_arcs = max_arcs;
            this.callback_unicast = callback_unicast;
            this.callback_broadcast = callback_broadcast;
            nics = new HashMap<string, INetworkInterface>();
            monitoring_devs = new HashMap<string, Tasklet>();
            arcs = new ArrayList<RealArc>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.equals(b);
                }
            );
            monitoring_arcs = new HashMap<RealArc, Tasklet>(
                /*HashDataFunc key_hash_func*/
                (a) => {
                    return 1; // all the work to the equal_func
                },
                /*EqualDataFunc key_equal_func*/
                (a, b) => {
                    return a.equals(b);
                }
            );
        }

        private INodeID my_id;
        private int max_arcs;
        private unowned GetUnicast callback_unicast;
        private unowned GetBroadcast callback_broadcast;
        private IAddressManagerRootDispatcher
        callback_broadcast_to_nic(INetworkInterface nic, MissingAckFrom missing)
        {
            IAddressManagerRootDispatcher bc = null;
            try {
                var _nics = new ArrayList<INetworkInterface>();
                _nics.add(nic);
                bc = callback_broadcast(new BroadcastID(), _nics, missing);
            } catch (RPCError e) {assert(false);}
            return bc;
        }
        private HashMap<string, INetworkInterface> nics;
        private HashMap<string, Tasklet> monitoring_devs;
        private ArrayList<RealArc> arcs;
        private HashMap<RealArc, Tasklet> monitoring_arcs;

        // Signals:
        // Network collision detected.
        public signal void network_collision(INodeID other);
        // New arc formed.
        public signal void arc_added(IArc arc);
        // An arc removed.
        public signal void arc_removed(IArc arc);
        // An arc changed its cost.
        public signal void arc_changed(IArc arc);

        public void start_monitor(INetworkInterface nic)
        {
            string dev = nic.dev;
            string mac = nic.mac;
            // is dev or mac already present?
            foreach (INetworkInterface present in nics.values)
            {
                if (present.dev == dev && present.mac == mac) return;
                assert(present.dev != dev);
                assert(present.mac != mac);
            }
            Tasklet t = Tasklet.tasklet_callback(
                (t_nic) => {
                    monitor_run(t_nic as INetworkInterface);
                },
                nic);
            monitoring_devs[dev] = t;
            nics[dev] = nic;
        }

        public void stop_monitor(string dev)
        {
            // search nic
            if (! nics.has_key(dev)) return;
            // nic found
            INetworkInterface nic = nics[dev];
            // remove arcs on this nic
            ArrayList<RealArc> todel = new ArrayList<RealArc>();
            foreach (RealArc arc in arcs) if (arc.my_nic.equals(nic)) todel.add(arc);
            foreach (RealArc arc in todel)
            {
                remove_my_arc(arc);
            }
            // remove nic
            monitoring_devs[dev].abort();
            monitoring_devs.unset(dev);
            nics.unset(dev);
        }

        public bool is_monitoring(string dev)
        {
            return monitoring_devs.has_key(dev);
        }

        public INetworkInterface get_monitoring_interface_from_dev(string dev)
        throws RPCError
        {
            if (is_monitoring(dev)) return nics[dev];
            throw new RPCError.GENERIC(@"Not handling interface $(dev)");
        }

        /* Runs in a tasklet foreach device
         */
        private void monitor_run(INetworkInterface nic)
        {
            while (true)
            {
                try
                {
                    IAddressManagerRootDispatcher bc =
                        get_broadcast_to_nic(nic,
                        // nothing to do for missing ACK from known neighbours
                        // because this message would be not important for them anyway.
                        (arc) => {}
                        );
                    bc.neighborhood_manager.here_i_am(my_id, nic.mac);
                    print(@"$(nic.mac)\n");
                }
                catch (RPCError e)
                {
                    log_warn("Neighborhood.monitor_run: " +
                    @"Error '$(e.message)' while sending in broadcast to $(nic.mac).");
                }
                Tasklet.nap(60, 0);
            }
        }

        public bool is_unicast_for_me(UnicastID ucid, INetworkInterface nic)
        {
            // Is it me?
            if (nic.mac != ucid.mac) return false;
            if (!(ucid.nodeid is INodeID)) return false;
            return my_id.equals((INodeID)ucid.nodeid);
        }

        private void start_arc_monitor(RealArc arc)
        {
            Tasklet t = Tasklet.tasklet_callback(
                (t_arc) => {
                    arc_monitor_run(t_arc as RealArc);
                },
                arc);
            monitoring_arcs[arc] = t;
        }

        private void stop_arc_monitor(RealArc arc)
        {
            if (! monitoring_arcs.has_key(arc)) return;
            monitoring_arcs[arc].abort();
            monitoring_arcs.unset(arc);
        }

        /* Runs in a tasklet foreach arc
         */
        private void arc_monitor_run(RealArc arc)
        {
            try
            {
                long last_rtt = -1;
                while (true)
                {
                    // Use a unicast to prepare the neighbor.
                    // It can throw RPCError.
                    var uc = get_unicast(arc);
                    int guid = Random.int_range(0, 1000000);
                    uc.neighborhood_manager.expect_ping(guid);
                    Tasklet.nap(1, 0);
                    // Use the callback saved in the INetworkInterface to get the
                    // RTT. It can throw GetRttError.
                    long rtt = arc.my_nic.get_usec_rtt((uint)guid);
                    // If all goes right, the arc is still valid and we have the
                    // cost up-to-date.
                    if (last_rtt == -1)
                    {
                        // First cost measure
                        last_rtt = rtt;
                        REM cost = new RTT(last_rtt);
                        arc.set_cost(cost);
                        // signal new arc
                        arc_added(arc);
                    }
                    else
                    {
                        // Following cost measures
                        long delta_rtt = rtt - last_rtt;
                        if (delta_rtt > 0) delta_rtt = delta_rtt / 10;
                        if (delta_rtt < 0) delta_rtt = delta_rtt / 3;
                        last_rtt = last_rtt + delta_rtt;
                        if (last_rtt < (arc.cost as RTT).delay * 0.5 ||
                            last_rtt > (arc.cost as RTT).delay * 2)
                        {
                            REM cost = new RTT(last_rtt);
                            arc.set_cost(cost);
                            // signal changed arc
                            arc_changed(arc);
                        }
                    }

                    Tasklet.nap(30, 0);
                }
            }
            catch (GetRttError e)
            {
                // remove arc
                remove_my_arc(arc);
            }
            catch (RPCError e)
            {
                // remove arc
                remove_my_arc(arc);
            }
        }

        public void remove_my_arc(IArc arc, bool do_tell=true)
        {
            if (!(arc is RealArc)) return;
            RealArc _arc = (RealArc)arc;
            // do just once
            if (! arcs.contains(_arc)) return;
            // remove the arc
            arcs.remove(_arc);
            // try and tell the neighbour to do the same
            if (do_tell)
            {
                var uc = get_unicast(arc, false);
                try {
                    uc.neighborhood_manager.remove_arc(my_id, _arc.my_nic.mac);
                } catch (RPCError e) {}
            }
            // signal removed arc
            arc_removed(arc);
            // stop monitoring the cost of the arc
            stop_arc_monitor(_arc);
        }

        /* Expose current valid arcs
         */
        public Gee.List<IArc> current_arcs()
        {
            var ret = new ArrayList<IArc>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.equals(b);
                }
            );
            foreach (RealArc arc in arcs) if (arc.available) ret.add(arc);
            return ret;
        }

        /* Get a client to call a unicast remote method
         */
        public
        IAddressManagerRootDispatcher
        get_unicast(IArc arc, bool wait_reply=true)
        {
            RealArc _arc = (RealArc)arc;
            UnicastID ucid = new UnicastID(_arc.mac, _arc.neighbour_id);
            var uc = callback_unicast(ucid, _arc.my_nic, wait_reply);
            return uc;
        }

        /* Get a client to call a broadcast remote method
         */
        public
        IAddressManagerRootDispatcher
        get_broadcast(INodeID? ignore_neighbour=null,
                      MissingAckFrom missing) throws RPCError
        {
            var bcid = new BroadcastID(ignore_neighbour);
            if (nics.is_empty) throw new RPCError.GENERIC("No NIC managed");
            var bc = callback_broadcast(bcid, nics.values, missing);
            return bc;
        }

        /* Get a client to call a broadcast remote method to one nic
         */
        public
        IAddressManagerRootDispatcher
        get_broadcast_to_nic(INetworkInterface nic, MissingAckFrom missing)
        {
            var bc = callback_broadcast_to_nic(nic, missing);
            return bc;
        }

        /* Remotable methods
         */

        public void here_i_am(ISerializable id, string mac, zcd.CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            if (!(id is INodeID))
            {
                log_warn("Neighborhood.here_i_am: Not an instance of INodeID");
                return;
            }
            INodeID its_id = (INodeID)id;
            // This is called in broadcast. Maybe it's me.
            if (its_id.equals(my_id)) return;
            // It's a neighbour. The message comes from my_nic and its mac is mac.
            string my_dev = rpc_caller.dev;
            INetworkInterface my_nic = null;
            try {
                my_nic = get_monitoring_interface_from_dev(my_dev);
            } catch (RPCError e) {
                log_warn(@"Neighborhood.here_i_am: $(e.message)");
                return;
            }
            // Did I already meet it? Did I already make an arc?
            foreach (RealArc arc in arcs)
            {
                if (arc.neighbour_id.equals(its_id))
                {
                    // I already met him. Same MAC and same NIC?
                    if (arc.mac == mac && arc.my_nic.equals(my_nic))
                    {
                        // I already made this arc. Ignore this message.
                        return;
                    }
                    if (arc.mac == mac || arc.my_nic.equals(my_nic))
                    {
                        // Not willing to make a new arc on same collision
                        // domain. Ignore this message.
                        return;
                    }
                    // Not this same arc. Continue searching for a previous arc.
                    continue;
                }
            }
            // Is it on my network?
            if (! its_id.is_on_same_network(my_id))
            {
                // It's on different network. Emit signal and ignore message.
                network_collision(its_id);
                return;
            }
            // Do I have too many arcs?
            if (arcs.size >= max_arcs)
            {
                // Ignore message.
                return;
            }
            // We can try and make a new arc.
            // UnicastID is such that if I send a message to it, the message will
            // be elaborated by the neighbor only once, when received through
            // the interface of this arc; hence, UnicastID will contain
            // as an identification:
            //  * INodeID
            //  * mac
            UnicastID ucid = new UnicastID(mac, id);
            var uc = callback_unicast(ucid, my_nic);
            bool refused = false;
            bool failed = false;
            try
            {
                uc.neighborhood_manager.request_arc(my_id, my_nic.mac);
            }
            catch (RequestArcError e)
            {
                // arc refused
                refused = true;
            }
            catch (RPCError e)
            {
                // failed
                failed = true;
            }
            if (! (refused || failed))
            {
                // Let's make an arc
                RealArc new_arc = new RealArc(its_id, mac, my_nic);
                arcs.add(new_arc);
                // start periodical ping
                start_arc_monitor(new_arc);
            }
        }

        public void request_arc(ISerializable id, string mac,
                                zcd.CallerInfo? _rpc_caller=null) throws RequestArcError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            if (!(id is INodeID))
            {
                log_warn("Neighborhood.request_arc: Not an instance of INodeID");
                throw new RequestArcError.GENERIC("Not an instance of INodeID");
            }
            INodeID its_id = (INodeID)id;
            // The message comes from my_nic and its mac is mac.
            string my_dev = rpc_caller.dev;
            INetworkInterface my_nic = null;
            try {
                my_nic = get_monitoring_interface_from_dev(my_dev);
            } catch (RPCError e) {
                log_warn(@"Neighborhood.request_arc: $(e.message)");
                throw new RequestArcError.GENERIC(e.message);
            }
            // Did I already make an arc?
            foreach (RealArc arc in arcs)
            {
                if (arc.neighbour_id.equals(its_id))
                {
                    // I already met him. Same MAC and same NIC?
                    if (arc.mac == mac && arc.my_nic.equals(my_nic))
                    {
                        // I already made this arc. Confirm arc.
                        log_warn("Neighborhood.request_arc: " +
                        @"Already got $(mac) on $(my_nic.mac)");
                        return;
                    }
                    if (arc.mac == mac || arc.my_nic.equals(my_nic))
                    {
                        // Not willing to make a new arc on same collision
                        // domain.
                        throw new RequestArcError.TWO_ARCS_ON_COLLISION_DOMAIN(
                        @"Refusing $(mac) on $(my_nic.mac).");
                    }
                    // Not this same arc. Continue searching for a previous arc.
                    continue;
                }
            }
            // Is it on my network?
            if (! its_id.is_on_same_network(my_id))
            {
                // It's on different network. Refuse.
                throw new RequestArcError.NOT_SAME_NETWORK(
                @"Refusing $(mac) because on different network.");
            }
            // Do I have too many arcs?
            if (arcs.size >= max_arcs)
            {
                // Refuse.
                throw new RequestArcError.TOO_MANY_ARCS(
                @"Refusing $(mac) because too many arcs.");
            }
            // Let's make an arc
            RealArc new_arc = new RealArc(its_id, mac, my_nic);
            arcs.add(new_arc);
            // start periodical ping
            start_arc_monitor(new_arc);
        }

        public void expect_ping(int guid,
                                zcd.CallerInfo? _rpc_caller=null) throws RPCError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from my_nic.
            string my_dev = rpc_caller.dev;
            INetworkInterface my_nic = get_monitoring_interface_from_dev(my_dev);
            // Use the callback saved in the INetworkInterface to prepare to
            // receive the ping.
            my_nic.prepare_ping((uint)guid);
        }

        public void remove_arc(ISerializable id, string mac,
                                zcd.CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            if (!(id is INodeID))
            {
                log_warn("Neighborhood.remove_arc: Not an instance of INodeID");
                return;
            }
            INodeID its_id = (INodeID)id;
            // The message comes from my_nic and its mac is mac.
            string my_dev = rpc_caller.dev;
            INetworkInterface my_nic = null;
            try {
                my_nic = get_monitoring_interface_from_dev(my_dev);
            } catch (RPCError e) {
                log_warn(@"Neighborhood.remove_arc: $(e.message)");
                return;
            }
            // Have I that arc?
            foreach (RealArc arc in arcs)
            {
                if (arc.neighbour_id.equals(its_id) &&
                    arc.mac == mac &&
                    arc.my_nic.equals(my_nic))
                {
                    remove_my_arc(arc, false);
                }
            }
        }

        ~NeighborhoodManager()
        {
            var copy_devs = new ArrayList<string>();
            copy_devs.add_all(monitoring_devs.keys);
            foreach (string dev in copy_devs)
            {
                stop_monitor(dev);
            }
        }
    }
}

