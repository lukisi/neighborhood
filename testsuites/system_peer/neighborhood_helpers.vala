using Gee;
using Netsukuku;
using Netsukuku.Neighborhood;
using TaskletSystem;

namespace TestHereiam
{
    class NeighborhoodIPRouteManager : Object, INeighborhoodIPRouteManager
    {
        public void add_address(string my_addr, string my_dev)
        {
            print(@"NeighborhoodIPRouteManager.add_address($my_addr, $my_dev)\n");
        }

        public void add_neighbor(string my_addr, string my_dev, string neighbor_addr)
        {
            print(@"NeighborhoodIPRouteManager.add_neighbor($my_addr, $my_dev, $neighbor_addr)\n");
        }

        public void remove_neighbor(string my_addr, string my_dev, string neighbor_addr)
        {
            print(@"NeighborhoodIPRouteManager.remove_neighbor($my_addr, $my_dev, $neighbor_addr)\n");
        }

        public void remove_address(string my_addr, string my_dev)
        {
            print(@"NeighborhoodIPRouteManager.remove_address($my_addr, $my_dev)\n");
        }
    }

    class NeighborhoodStubFactory : Object, INeighborhoodStubFactory
    {
        public INeighborhoodManagerStub
        get_broadcast_for_radar(INeighborhoodNetworkInterface nic)
        {
            IAddressManagerStub addrstub = stub_factory.get_stub_whole_node_broadcast_for_radar(nic);
            NeighborhoodManagerStubHolder ret = new NeighborhoodManagerStubHolder(addrstub);
            return ret;
        }

        public INeighborhoodManagerStub
        get_unicast(
            INeighborhoodArc arc,
            bool wait_reply = true)
        {
            IAddressManagerStub addrstub = stub_factory.get_stub_whole_node_unicast(arc, wait_reply);
            NeighborhoodManagerStubHolder ret = new NeighborhoodManagerStubHolder(addrstub);
            return ret;
        }
    }

    class NeighborhoodQueryCallerInfo : Object, INeighborhoodQueryCallerInfo
    {
        public INeighborhoodNetworkInterface?
        is_from_broadcast(CallerInfo _rpc_caller)
        {
            string? my_dev = skeleton_factory.from_caller_get_mydev(_rpc_caller);
            if (my_dev == null) return null;
            PseudoNetworkInterface pseudonic = pseudonic_map[my_dev];
            return pseudonic.nic;
        }

        public INeighborhoodArc?
        is_from_unicast(CallerInfo _rpc_caller, Gee.List<INeighborhoodArc> arcs)
        {
            if (_rpc_caller is StreamCallerInfo)
            {
                StreamCallerInfo rpc_caller = (StreamCallerInfo)_rpc_caller;
                if (rpc_caller.listener is StreamSystemListener)
                {
                    string st_listen_pathname = ((StreamSystemListener)rpc_caller.listener).listen_pathname;
                    if (rpc_caller.src_nic is NeighbourSrcNic)
                    {
                        string neighbour_mac = ((NeighbourSrcNic)rpc_caller.src_nic).mac;
                        foreach (INeighborhoodArc arc in arcs)
                        {
                            if (arc.neighbour_mac == neighbour_mac)
                            {
                                PseudoNetworkInterface pseudonic = ((NeighborhoodNetworkInterface)arc.nic).pseudonic;
                                if (pseudonic.st_listen_pathname == st_listen_pathname)
                                    return arc;
                            }
                        }
                        return null;
                    }
                    else error("not rpc_caller.src_nic is NeighbourSrcNic");
                }
                else error("not rpc_caller.listener is StreamSystemListener");
            }
            else return null;
        }
    }

    class NeighborhoodNetworkInterface : Object, INeighborhoodNetworkInterface
    {
        public NeighborhoodNetworkInterface(PseudoNetworkInterface pseudonic)
        {
            this.pseudonic = pseudonic;
        }
        public PseudoNetworkInterface pseudonic {get; private set;}

        public string dev {
            get {
                return pseudonic.dev;
            }
        }

        public string mac {
            get {
                return pseudonic.mac;
            }
        }

        public long measure_rtt(string peer_addr, string peer_mac, string my_dev, string my_addr) throws NeighborhoodGetRttError
        {
            return 1000;
            // TODO
        }
    }
}
