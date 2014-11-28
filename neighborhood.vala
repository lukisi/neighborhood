using Gee;
using zcd;
using Tasklets;

namespace Netsukuku
{
    internal class NeighborhoodRealArc : Object, INeighborhoodArc
    {
        private INeighborhoodNodeID _neighbour_id;
        private string _mac;
        private string _nic_addr;
        private REM _cost;
        private INeighborhoodNetworkInterface _my_nic;
        public bool available;

        public NeighborhoodRealArc(INeighborhoodNodeID neighbour_id,
                       string mac,
                       string nic_addr,
                       INeighborhoodNetworkInterface my_nic)
        {
            _neighbour_id = neighbour_id;
            _mac = mac;
            _nic_addr = nic_addr;
            _my_nic = my_nic;
            available = false;
        }

        public INeighborhoodNetworkInterface my_nic {
            get {
                return _my_nic;
            }
        }

        public string nic_addr {
            get {
                return _nic_addr;
            }
        }

        public void set_cost(REM cost)
        {
            _cost = cost;
            available = true;
        }

        /* Public interface IArc
         */

        public bool i_neighborhood_is_nic(INeighborhoodNetworkInterface nic)
        {
            return my_nic.i_neighborhood_equals(nic);
        }

        public bool i_neighborhood_equals(INeighborhoodArc other)
        {
            // This kind of equality test is ok as long as I am sure
            // that this module is the only able to create an instance
            // of IArc and that it won't create more than one instance
            // for each arc.
            return other == this;
        }

        public INeighborhoodNodeID i_neighborhood_neighbour_id {
            get {
                return _neighbour_id;
            }
        }

        public string i_neighborhood_mac {
            get {
                return _mac;
            }
        }

        public REM i_neighborhood_cost {
            get {
                return _cost;
            }
        }
    }

    /* Interface of NeighborhoodManager to be used by who needs to gather the,
     * arcs that should be reached by a certain broadcast message.
     */
    public interface INeighborhoodArcFinder : Object
    {
        public abstract Gee.List<INeighborhoodArc>
                        i_neighborhood_current_arcs_for_broadcast(
                            BroadcastID bcid,
                            Gee.Collection<INeighborhoodNetworkInterface> nics
                        );
    }

    /* This interface is implemented by an object passed to the Neighbor manager
     * which uses it to actually obtain a stub to send messages to other nodes.
     */
    public interface INeighborhoodStubFactory : Object
    {
        public abstract IAddressManagerRootDispatcher
                        i_neighborhood_get_broadcast(
                            BroadcastID bcid,
                            Gee.Collection<INeighborhoodNetworkInterface> nics,
                            INeighborhoodArcFinder arc_finder,
                            INeighborhoodArcRemover arc_remover,
                            INeighborhoodMissingArcHandler missing_handler
                        );
        public abstract IAddressManagerRootDispatcher
                        i_neighborhood_get_unicast(
                            UnicastID ucid,
                            INeighborhoodNetworkInterface nic,
                            bool wait_reply=true
                        );
        public abstract IAddressManagerRootDispatcher
                        i_neighborhood_get_tcp(
                            string dest,
                            bool wait_reply=true
                        );
        public  IAddressManagerRootDispatcher
                i_neighborhood_get_broadcast_to_nic(
                    BroadcastID bcid,
                    INeighborhoodNetworkInterface nic,
                    INeighborhoodArcFinder arc_finder,
                    INeighborhoodArcRemover arc_remover,
                    INeighborhoodMissingArcHandler missing_handler
                )
        {
            var _nics = new ArrayList<INeighborhoodNetworkInterface>();
            _nics.add(nic);
            return i_neighborhood_get_broadcast(bcid, _nics,
                        arc_finder, arc_remover, missing_handler);
        }
    }

    /* This interface is implemented by an object passed to the Neighbor manager
     * which uses it to manage addresses and routes of the O.S. (specifically in
     * order to have a fixed address for each NIC and be able to contact via TCP
     * its neighbors with their fixed addresses)
     */
    public interface INeighborhoodIPRouteManager : Object
    {
        public abstract void i_neighborhood_add_address(
                            string my_addr,
                            string my_dev
                        );

        public abstract void i_neighborhood_add_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        );

        public abstract void i_neighborhood_remove_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        );

        public abstract void i_neighborhood_remove_address(
                            string my_addr,
                            string my_dev
                        );
    }

    class NeighborhoodIgnoreMissing : Object, INeighborhoodMissingArcHandler
    {
        public void i_neighborhood_missing(INeighborhoodArc arc, INeighborhoodArcRemover arc_remover) {}
    }

    public class NeighborhoodManager : Object,
                                       INeighborhoodManager,
                                       INeighborhoodArcToStub,
                                       INeighborhoodArcFinder,
                                       INeighborhoodArcRemover
    {
        public NeighborhoodManager(INeighborhoodNodeID my_id,
                                   int max_arcs,
                                   INeighborhoodStubFactory stub_factory,
                                   INeighborhoodIPRouteManager ip_mgr)
        {
            this.my_id = my_id;
            this.max_arcs = max_arcs;
            this.stub_factory = stub_factory;
            this.ip_mgr = ip_mgr;
            nics = new HashMap<string, INeighborhoodNetworkInterface>();
            local_addresses = new HashMap<string, string>();
            monitoring_devs = new HashMap<string, Tasklet>();
            arcs = new ArrayList<NeighborhoodRealArc>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.i_neighborhood_equals(b);
                }
            );
            monitoring_arcs = new HashMap<NeighborhoodRealArc, Tasklet>(
                /*HashDataFunc key_hash_func*/
                (a) => {
                    return 1; // all the work to the equal_func
                },
                /*EqualDataFunc key_equal_func*/
                (a, b) => {
                    return a.i_neighborhood_equals(b);
                }
            );
        }

        private INeighborhoodNodeID my_id;
        private int max_arcs;
        private INeighborhoodStubFactory stub_factory;
        private INeighborhoodIPRouteManager ip_mgr;
        private HashMap<string, INeighborhoodNetworkInterface> nics;
        private HashMap<string, string> local_addresses;
        private HashMap<string, Tasklet> monitoring_devs;
        private ArrayList<NeighborhoodRealArc> arcs;
        private HashMap<NeighborhoodRealArc, Tasklet> monitoring_arcs;

        // Signals:
        // Network collision detected.
        public signal void network_collision(INeighborhoodNodeID other);
        // New arc formed.
        public signal void arc_added(INeighborhoodArc arc);
        // An arc removed.
        public signal void arc_removed(INeighborhoodArc arc);
        // An arc changed its cost.
        public signal void arc_changed(INeighborhoodArc arc);

        public void start_monitor(INeighborhoodNetworkInterface nic)
        {
            string dev = nic.i_neighborhood_dev;
            string mac = nic.i_neighborhood_mac;
            // is dev or mac already present?
            foreach (INeighborhoodNetworkInterface present in nics.values)
            {
                if (present.i_neighborhood_dev == dev && present.i_neighborhood_mac == mac) return;
                assert(present.i_neighborhood_dev != dev);
                assert(present.i_neighborhood_mac != mac);
            }
            // generate a random IP for this nic
            int i1 = Random.int_range(64, 127);
            int i2 = Random.int_range(0, 255);
            int i3 = Random.int_range(0, 255);
            string local_address = @"100.$(i1).$(i2).$(i3)";
            ip_mgr.i_neighborhood_add_address(local_address, dev);
            // start monitor
            Tasklet t = Tasklet.tasklet_callback(
                (t_nic, t_local_address) => {
                    monitor_run(t_nic as INeighborhoodNetworkInterface,
                                (t_local_address as SerializableString).s);
                },
                nic,
                new SerializableString(local_address));
            // private members
            monitoring_devs[dev] = t;
            nics[dev] = nic;
            local_addresses[dev] = local_address;
        }

        public void stop_monitor(string dev)
        {
            // search nic
            if (! nics.has_key(dev)) return;
            // nic found
            INeighborhoodNetworkInterface nic = nics[dev];
            // remove arcs on this nic
            ArrayList<NeighborhoodRealArc> todel = new ArrayList<NeighborhoodRealArc>();
            foreach (NeighborhoodRealArc arc in arcs) if (arc.my_nic.i_neighborhood_equals(nic)) todel.add(arc);
            foreach (NeighborhoodRealArc arc in todel)
            {
                remove_my_arc(arc);
            }
            // stop monitor
            monitoring_devs[dev].abort();
            // remove local address
            string local_address = local_addresses[dev];
            ip_mgr.i_neighborhood_remove_address(local_address, dev);
            // cleanup private members
            monitoring_devs.unset(dev);
            nics.unset(dev);
            local_addresses.unset(dev);
        }

        public bool is_monitoring(string dev)
        {
            return monitoring_devs.has_key(dev);
        }

        public INeighborhoodNetworkInterface get_monitoring_interface_from_dev(string dev)
        throws RPCError
        {
            if (is_monitoring(dev)) return nics[dev];
            throw new RPCError.GENERIC(@"Not handling interface $(dev)");
        }

        /* Runs in a tasklet foreach device
         */
        private void monitor_run(INeighborhoodNetworkInterface nic, string local_address)
        {
            while (true)
            {
                try
                {
                    IAddressManagerRootDispatcher bc =
                        i_neighborhood_get_broadcast_to_nic(nic);
                        // nothing to do for missing ACK from known neighbours
                        // because this message would be not important for them anyway.
                    bc.neighborhood_manager.here_i_am(my_id, nic.i_neighborhood_mac, local_address);
                }
                catch (RPCError e)
                {
                    log_warn("Neighborhood.monitor_run: " +
                    @"Error '$(e.message)' while sending in broadcast to $(nic.i_neighborhood_mac).");
                }
                Tasklet.nap(60, 0);
            }
        }

        public bool is_unicast_for_me(UnicastID ucid, INeighborhoodNetworkInterface nic)
        {
            // Is it me?
            if (nic.i_neighborhood_mac != ucid.mac) return false;
            if (!(ucid.nodeid is INeighborhoodNodeID)) return false;
            return my_id.i_neighborhood_equals((INeighborhoodNodeID)ucid.nodeid);
        }

        private void start_arc_monitor(NeighborhoodRealArc arc)
        {
            Tasklet t = Tasklet.tasklet_callback(
                (t_arc) => {
                    arc_monitor_run(t_arc as NeighborhoodRealArc);
                },
                arc);
            monitoring_arcs[arc] = t;
        }

        private void stop_arc_monitor(NeighborhoodRealArc arc)
        {
            if (! monitoring_arcs.has_key(arc)) return;
            monitoring_arcs[arc].abort();
            monitoring_arcs.unset(arc);
        }

        /* Runs in a tasklet foreach arc
         */
        private void arc_monitor_run(NeighborhoodRealArc arc)
        {
            try
            {
                long last_rtt = -1;
                while (true)
                {
                    try
                    {
                        // Use a tcp_client to prepare the neighbor.
                        // It can throw RPCError.
                        var uc = i_neighborhood_get_tcp(arc);
                        int guid = Random.int_range(0, 1000000);
                        uc.neighborhood_manager.expect_ping(guid);
                        Tasklet.nap(1, 0);
                        // Use the callback saved in the INetworkInterface to get the
                        // RTT. It can throw GetRttError.
                        long rtt = arc.my_nic.i_neighborhood_get_usec_rtt((uint)guid);
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
                            if (last_rtt < (arc.i_neighborhood_cost as RTT).delay * 0.5 ||
                                last_rtt > (arc.i_neighborhood_cost as RTT).delay * 2)
                            {
                                REM cost = new RTT(last_rtt);
                                arc.set_cost(cost);
                                // signal changed arc
                                arc_changed(arc);
                            }
                        }

                        Tasklet.nap(30, 0);
                    }
                    catch (GetRttError e)
                    {
                        // failed getting the RTT
                        // Since UDP is not reliable, this is ignorable. Try again soon.
                        Tasklet.nap(1, 0);
                    }
                }
            }
            catch (RPCError e)
            {
                // failed sending the GUID
                // Since it was sent via TCP this is worrying.
                remove_my_arc(arc);
            }
        }

        /* This implements interface IArcRemover; it is usually called as a
         * consequence of a missed acknowledgement for a broadcast call, so it
         * will remove its own arc without bothering to tell the other.
         */
        public void i_neighborhood_arc_remover_remove(INeighborhoodArc arc)
        {
            remove_my_arc(arc, false);
        }

        public void remove_my_arc(INeighborhoodArc arc, bool do_tell=true)
        {
            if (!(arc is NeighborhoodRealArc)) return;
            NeighborhoodRealArc _arc = (NeighborhoodRealArc)arc;
            // do just once
            if (! arcs.contains(_arc)) return;
            // remove the fixed address of the neighbor
            ip_mgr.i_neighborhood_remove_neighbor(
                        /*my_addr*/ local_addresses[_arc.my_nic.i_neighborhood_dev],
                        /*my_dev*/ _arc.my_nic.i_neighborhood_dev,
                        /*neighbor_addr*/ _arc.nic_addr);
            // remove the arc
            arcs.remove(_arc);
            // try and tell the neighbour to do the same
            if (do_tell)
            {
                var uc = i_neighborhood_get_tcp(arc, false);
                try {
                    uc.neighborhood_manager
                        .remove_arc(my_id,
                                   _arc.my_nic.i_neighborhood_mac,
                                   local_addresses[_arc.my_nic.i_neighborhood_dev]);
                } catch (RPCError e) {}
            }
            // signal removed arc
            if (_arc.available) arc_removed(arc);
            // stop monitoring the cost of the arc
            stop_arc_monitor(_arc);
        }

        /* Expose current valid arcs
         */
        public Gee.List<INeighborhoodArc> current_arcs()
        {
            var ret = new ArrayList<INeighborhoodArc>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.i_neighborhood_equals(b);
                }
            );
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available) ret.add(arc);
            return ret;
        }

        /* Implements IArcFinder: current arcs for a given broadcast message
         */
        public Gee.List<INeighborhoodArc> i_neighborhood_current_arcs_for_broadcast(
                            BroadcastID bcid,
                            Gee.Collection<INeighborhoodNetworkInterface> nics)
        {
            var ret = new ArrayList<INeighborhoodArc>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.i_neighborhood_equals(b);
                }
            );
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available)
            {
                // test arc against bcid (e.g. ignore_neighbour)
                if (bcid.ignore_nodeid != null)
                    if (arc.i_neighborhood_neighbour_id.i_neighborhood_equals(bcid.ignore_nodeid as INeighborhoodNodeID)) continue;
                // test arc against nics.
                bool is_in_nics = false;
                foreach (INeighborhoodNetworkInterface nic in nics)
                {
                    if (arc.i_neighborhood_is_nic(nic))
                    {
                        is_in_nics = true;
                        break;
                    }
                }
                if (! is_in_nics) continue;
                // This should receive
                ret.add(arc);
            }
            return ret;
        }

        /* Get a client to call a unicast remote method via TCP
         */
        public
        IAddressManagerRootDispatcher
        i_neighborhood_get_tcp(INeighborhoodArc arc, bool wait_reply=true)
        {
            NeighborhoodRealArc _arc = (NeighborhoodRealArc)arc;
            var uc = stub_factory.i_neighborhood_get_tcp(_arc.nic_addr, wait_reply);
            return uc;
        }

        /* Get a client to call a unicast remote method via UDP
         */
        public
        IAddressManagerRootDispatcher
        i_neighborhood_get_unicast(INeighborhoodArc arc, bool wait_reply=true)
        {
            NeighborhoodRealArc _arc = (NeighborhoodRealArc)arc;
            UnicastID ucid = new UnicastID(_arc.i_neighborhood_mac, _arc.i_neighborhood_neighbour_id);
            var uc = stub_factory.i_neighborhood_get_unicast(ucid, _arc.my_nic, wait_reply);
            return uc;
        }

        /* Get a client to call a broadcast remote method
         */
        public
        IAddressManagerRootDispatcher
        i_neighborhood_get_broadcast(INeighborhoodMissingArcHandler? missing_handler=null,
                      INeighborhoodNodeID? ignore_neighbour=null)
        {
            INeighborhoodMissingArcHandler _missing;
            if (missing_handler == null) _missing = new NeighborhoodIgnoreMissing();
            else _missing = missing_handler;
            var bcid = new BroadcastID(ignore_neighbour);
            var bc = stub_factory.i_neighborhood_get_broadcast(bcid, nics.values,
                         /*finder*/ this,
                         /*remover*/ this,
                         _missing);
            return bc;
        }

        /* Get a client to call a broadcast remote method to one nic
         */
        public
        IAddressManagerRootDispatcher
        i_neighborhood_get_broadcast_to_nic(INeighborhoodNetworkInterface nic,
                             INeighborhoodMissingArcHandler? missing_handler=null,
                             INeighborhoodNodeID? ignore_neighbour=null)
        {
            INeighborhoodMissingArcHandler _missing;
            if (missing_handler == null) _missing = new NeighborhoodIgnoreMissing();
            else _missing = missing_handler;
            var bcid = new BroadcastID(ignore_neighbour);
            var bc = stub_factory.i_neighborhood_get_broadcast_to_nic(bcid, nic,
                         /*finder*/ this,
                         /*remover*/ this,
                         _missing);
            return bc;
        }

        /* Remotable methods
         */

        public void here_i_am(INeighborhoodNodeID its_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // This is called in broadcast. Maybe it's me.
            if (its_id.i_neighborhood_equals(my_id)) return;
            // It's a neighbour. The message comes from my_nic and its mac is mac.
            string my_dev = rpc_caller.dev;
            INeighborhoodNetworkInterface my_nic = null;
            try {
                my_nic = get_monitoring_interface_from_dev(my_dev);
            } catch (RPCError e) {
                log_warn(@"Neighborhood.here_i_am: $(e.message)");
                return;
            }
            // Did I already meet it? Did I already make an arc?
            foreach (NeighborhoodRealArc arc in arcs)
            {
                if (arc.i_neighborhood_neighbour_id.i_neighborhood_equals(its_id))
                {
                    // I already met him. Same MAC and same NIC?
                    if (arc.i_neighborhood_mac == mac && arc.my_nic.i_neighborhood_equals(my_nic))
                    {
                        // I already made this arc. Ignore this message.
                        return;
                    }
                    if (arc.i_neighborhood_mac == mac || arc.my_nic.i_neighborhood_equals(my_nic))
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
            if (! its_id.i_neighborhood_is_on_same_network(my_id))
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
            // Since we haven't yet an arc with this node, we cannot use TCP.
            // We use unicast UDP, if it fails not a big problem, we'll retry soon.
            // UnicastID is such that if I send a message to it, the message will
            // be elaborated by the neighbor only once, when received through
            // the interface of this arc; hence, UnicastID will contain
            // as an identification:
            //  * INeighborhoodNodeID
            //  * mac
            UnicastID ucid = new UnicastID(mac, its_id);
            var uc = stub_factory.i_neighborhood_get_unicast(ucid, my_nic);
            bool refused = false;
            bool failed = false;
            try
            {
                uc.neighborhood_manager.request_arc(my_id, my_nic.i_neighborhood_mac, local_addresses[my_dev]);
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
                NeighborhoodRealArc new_arc = new NeighborhoodRealArc(its_id, mac, nic_addr, my_nic);
                arcs.add(new_arc);
                // add the fixed address of the neighbor
                ip_mgr.i_neighborhood_add_neighbor(
                            /*my_addr*/ local_addresses[my_dev],
                            /*my_dev*/ my_dev,
                            /*neighbor_addr*/ nic_addr);
                // start periodical ping
                start_arc_monitor(new_arc);
            }
        }

        public void request_arc(INeighborhoodNodeID its_id, string mac, string nic_addr,
                                zcd.CallerInfo? _rpc_caller=null) throws RequestArcError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from my_nic and its mac is mac.
            // TODO check that nic_addr is in 100.64.0.0/10 class.
            // TODO check that nic_addr is not conflicting with mine or my neighbors' ones.
            string my_dev = rpc_caller.dev;
            INeighborhoodNetworkInterface my_nic = null;
            try {
                my_nic = get_monitoring_interface_from_dev(my_dev);
            } catch (RPCError e) {
                log_warn(@"Neighborhood.request_arc: $(e.message)");
                throw new RequestArcError.GENERIC(e.message);
            }
            // Did I already make an arc?
            foreach (NeighborhoodRealArc arc in arcs)
            {
                if (arc.i_neighborhood_neighbour_id.i_neighborhood_equals(its_id))
                {
                    // I already met him. Same MAC and same NIC?
                    if (arc.i_neighborhood_mac == mac && arc.my_nic.i_neighborhood_equals(my_nic))
                    {
                        // I already made this arc. Confirm arc.
                        log_warn("Neighborhood.request_arc: " +
                        @"Already got $(mac) on $(my_nic.i_neighborhood_mac)");
                        return;
                    }
                    if (arc.i_neighborhood_mac == mac || arc.my_nic.i_neighborhood_equals(my_nic))
                    {
                        // Not willing to make a new arc on same collision
                        // domain.
                        throw new RequestArcError.TWO_ARCS_ON_COLLISION_DOMAIN(
                        @"Refusing $(mac) on $(my_nic.i_neighborhood_mac).");
                    }
                    // Not this same arc. Continue searching for a previous arc.
                    continue;
                }
            }
            // Is it on my network?
            if (! its_id.i_neighborhood_is_on_same_network(my_id))
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
            NeighborhoodRealArc new_arc = new NeighborhoodRealArc(its_id, mac, nic_addr, my_nic);
            arcs.add(new_arc);
            // add the fixed address of the neighbor
            ip_mgr.i_neighborhood_add_neighbor(
                        /*my_addr*/ local_addresses[my_dev],
                        /*my_dev*/ my_dev,
                        /*neighbor_addr*/ nic_addr);
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
            INeighborhoodNetworkInterface my_nic = get_monitoring_interface_from_dev(my_dev);
            // Use the callback saved in the INetworkInterface to prepare to
            // receive the ping.
            my_nic.i_neighborhood_prepare_ping((uint)guid);
        }

        public void remove_arc(INeighborhoodNodeID its_id, string mac, string nic_addr,
                                zcd.CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from my_nic and its mac is mac.
            string my_dev = rpc_caller.dev;
            INeighborhoodNetworkInterface my_nic = null;
            try {
                my_nic = get_monitoring_interface_from_dev(my_dev);
            } catch (RPCError e) {
                log_warn(@"Neighborhood.remove_arc: $(e.message)");
                return;
            }
            // Have I that arc?
            foreach (NeighborhoodRealArc arc in arcs)
            {
                if (arc.i_neighborhood_neighbour_id.i_neighborhood_equals(its_id) &&
                    arc.i_neighborhood_mac == mac &&
                    arc.my_nic.i_neighborhood_equals(my_nic))
                {
                    remove_my_arc(arc, false);
                }
            }
        }

        public void stop_monitor_all()
        {
            var copy_devs = new ArrayList<string>();
            copy_devs.add_all(monitoring_devs.keys);
            foreach (string dev in copy_devs)
            {
                stop_monitor(dev);
            }
        }

        ~NeighborhoodManager()
        {
            print("NeighborhoodManager destructor\n");
            stop_monitor_all();
        }
    }
}

