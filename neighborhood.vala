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
    }

    public class REM : Object
    {
    }

    public interface IArc : Object
    {
        public abstract INodeID neighbour_id {get;}
        public abstract string mac {get;}
        public abstract REM cost {get;}
        public abstract bool equals(IArc other);
    }

    internal class RealArc : Object, IArc
    {
        private INodeID _neighbour_id;
        private string _mac;
        private REM _cost;
        private string _my_dev;

        public RealArc(INodeID neighbour_id,
                       REM cost,
                       string mac,
                       string my_dev)
        {
            _neighbour_id = neighbour_id;
            _mac = mac;
            _cost = cost;
            _my_dev = my_dev;
        }

        public string my_dev {
            get {
                return _my_dev;
            }
        }

        /* Public interface IArc
         */

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

    public class NeighborhoodManager : Object, INeighborhoodManager
    {
        public NeighborhoodManager(INodeID my_id,
                                   int max_neighbours)
        {
            this.my_id = my_id;
            this.max_neighbours = max_neighbours;
            nics = new ArrayList<INetworkInterface>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.dev == b.dev && a.mac == b.mac;
                }
            );
            monitoring_devs = new HashMap<string, Tasklet>();
            arcs = new ArrayList<RealArc>(
                /*EqualDataFunc*/
                (a, b) => {
                    return a.equals(b);
                }
            );
        }

        private INodeID my_id;
        private int max_neighbours;
        private ArrayList<INetworkInterface> nics;
        private HashMap<string, Tasklet> monitoring_devs;
        private HashMap<string, string> dev_to_mac;
        private ArrayList<RealArc> arcs;

        public void start_monitor(INetworkInterface nic)
        {
            string dev = nic.dev;
            string mac = nic.mac;
            // is dev or mac already present?
            foreach (INetworkInterface present in nics)
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
            dev_to_mac[dev] = mac;
            nics.add(nic);
        }

        public void stop_monitor(string dev)
        {
            // search nic
            INetworkInterface? nic = null;
            foreach (INetworkInterface present in nics)
            {
                if (present.dev == dev)
                {
                    nic = present;
                    break;
                }
            }
            if (nic == null) return;
            // nic found
            monitoring_devs[dev].abort();
            monitoring_devs.unset(dev);
            dev_to_mac.unset(dev);
            nics.remove(nic);
        }

        public bool is_monitoring(string dev)
        {
            return monitoring_devs.has_key(dev);
        }

        /* Runs in a tasklet foreach device
         */
        private void monitor_run(INetworkInterface nic)
        {
            string dev = nic.dev;
            while (true)
            {
                AddressManagerBroadcastClient bc = new AddressManagerBroadcastClient(new BroadcastID(), {dev});
                bc.neighborhood_manager.here_i_am(my_id, nic.mac);
                print(@"$(dev)\n");
                Tasklet.nap(60, 0);
            }
        }

        public bool is_unicast_for_me(UnicastID ucid, string dev)
        {
            // Do I handle a NIC with these dev and mac?
            if (! dev_to_mac.has_key(dev)) return false;
            if (dev_to_mac[dev] != ucid.mac) return false;
            // Is it me?
            if (!(ucid.nodeid is INodeID)) return false;
            return my_id.equals((INodeID)ucid.nodeid);
        }

        /*
         */
        // public Gee.List<IArc> current_arcs()
        // {
        // }

        /* Remotable methods
         */

        public void here_i_am(ISerializable id, string mac, zcd.CallerInfo? _rpc_caller=null) throws RPCError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            if (!(id is INodeID)) throw new RPCError.GENERIC("Not an instance of INodeID");
            INodeID its_id = (INodeID)id;
            // This is called in broadcast. Maybe it's me.
            if (its_id.equals(my_id)) return;
            // It's a neighbour. The message comes from my_dev and its mac is mac.
            string my_dev = rpc_caller.dev;
            // Did I already meet it? Did I already make an arc?
            foreach (RealArc arc in arcs)
            {
                if (arc.neighbour_id.equals(its_id))
                {
                    // I already met him. Same mac and same dev?
                    if (arc.mac == mac && arc.my_dev == my_dev)
                    {
                        // I already made this arc. Ignore this message.
                        return;
                    }
                    if (arc.mac == mac || arc.my_dev == my_dev)
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
                // TODO signal.
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
            var uc = new AddressManagerNeighbourClient(ucid, {my_dev});
            bool refused = false;
            try
            {
                uc.neighborhood_manager.request_arc(my_id, dev_to_mac[my_dev]);
            }
            catch (RequestArcError e)
            {
                // arc refused
                refused = true;
            }
            if (! refused)
            {
                // TODO
            }
        }

        public void request_arc(ISerializable id, string mac,
                                zcd.CallerInfo? _rpc_caller=null) throws RequestArcError, RPCError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            if (!(id is INodeID)) throw new RPCError.GENERIC("Not an instance of INodeID");
            INodeID its_id = (INodeID)id;
            // The message comes from my_dev and its mac is mac.
            string my_dev = rpc_caller.dev;
            // Did I already make an arc?
            foreach (RealArc arc in arcs)
            {
                if (arc.neighbour_id.equals(its_id))
                {
                    // I already met him. Same mac and same dev?
                    if (arc.mac == mac && arc.my_dev == my_dev)
                    {
                        // I already made this arc. Confirm arc.
                        // TODO log_warn("Neighborhood.request_arc: " +
                        // TODO @"Already got $(mac) on $(dev_to_mac[my_dev])");
                        return;
                    }
                    if (arc.mac == mac || arc.my_dev == my_dev)
                    {
                        // Not willing to make a new arc on same collision
                        // domain.
                        throw new RequestArcError.TWO_ARCS_ON_COLLISION_DOMAIN(
                        @"Refusing $(mac) on $(dev_to_mac[my_dev]).");
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

            throw new RequestArcError.GENERIC("Not implemented");
        }

        public void expect_ping(int guid)
        {
            //prepare_ping((uint)guid);
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

