using Gee;
using Netsukuku;
using Netsukuku.Neighborhood;
using TaskletSystem;

namespace TestHereiam
{
    class SkeletonFactory : Object
    {
        public SkeletonFactory()
        {
            this.node_skeleton = new NodeSkeleton();
            dlg = new ServerDelegate(this);
        }

        private NodeSkeleton node_skeleton;
        public NeighborhoodNodeID whole_node_id {
            get {
                return node_skeleton.id;
            }
            set {
                node_skeleton.id = value;
            }
        }
        // private List<IdentitySkeleton>...

        private ServerDelegate dlg;
        HashMap<string,IListenerHandle> handles_by_listen_pathname;

        public void start_stream_system_listen(string listen_pathname)
        {
            IErrorHandler stream_system_err = new ServerErrorHandler(@"for stream_system_listen $(listen_pathname)");
            if (handles_by_listen_pathname == null) handles_by_listen_pathname = new HashMap<string,IListenerHandle>();
            handles_by_listen_pathname[listen_pathname] = stream_system_listen(dlg, stream_system_err, listen_pathname);
        }
        public void stop_stream_system_listen(string listen_pathname)
        {
            assert(handles_by_listen_pathname != null);
            assert(handles_by_listen_pathname.has_key(listen_pathname));
            IListenerHandle lh = handles_by_listen_pathname[listen_pathname];
            lh.kill();
            handles_by_listen_pathname.unset(listen_pathname);
        }

        public void start_datagram_system_listen(string listen_pathname, string send_pathname, ISrcNic src_nic)
        {
            IErrorHandler datagram_system_err = new ServerErrorHandler(@"for datagram_system_listen $(listen_pathname) $(send_pathname) TODO SrcNic.tostring()");
            if (handles_by_listen_pathname == null) handles_by_listen_pathname = new HashMap<string,IListenerHandle>();
            handles_by_listen_pathname[listen_pathname] = datagram_system_listen(dlg, datagram_system_err, listen_pathname, send_pathname, src_nic);
        }
        public void stop_datagram_system_listen(string listen_pathname)
        {
            assert(handles_by_listen_pathname != null);
            assert(handles_by_listen_pathname.has_key(listen_pathname));
            IListenerHandle lh = handles_by_listen_pathname[listen_pathname];
            lh.kill();
            handles_by_listen_pathname.unset(listen_pathname);
        }

        [NoReturn]
        private void abort_tasklet(string msg_warning)
        {
            warning(msg_warning);
            tasklet.exit_tasklet();
        }

        private IAddressManagerSkeleton? get_dispatcher(StreamCallerInfo caller_info)
        {
            if (! (caller_info.source_id is WholeNodeSourceID)) abort_tasklet(@"Bad caller_info.source_id");
            WholeNodeSourceID _source_id = (WholeNodeSourceID)caller_info.source_id;
            NeighborhoodNodeID neighbour_id = _source_id.id;
            if (! (caller_info.unicast_id is WholeNodeUnicastID)) abort_tasklet(@"Bad caller_info.unicast_id");
            WholeNodeUnicastID _unicast_id = (WholeNodeUnicastID)caller_info.unicast_id;
            NeighborhoodNodeID my_id = _unicast_id.neighbour_id;
            if (! my_id.equals(node_skeleton.id)) abort_tasklet(@"caller_info.unicast_id is not me.");
            // TODO cicla i suoi archi
            error("not implemented yet");
        }

        private Gee.List<IAddressManagerSkeleton> get_dispatcher_set(DatagramCallerInfo caller_info)
        {
            if (! (caller_info.source_id is WholeNodeSourceID)) abort_tasklet(@"Bad caller_info.source_id");
            if (! (caller_info.broadcast_id is EveryWholeNodeBroadcastID)) abort_tasklet(@"Bad caller_info.broadcast_id");
            Gee.List<IAddressManagerSkeleton> ret = new ArrayList<IAddressManagerSkeleton>();
            ret.add(node_skeleton);
            return ret;
        }

        public string?
        from_caller_get_mydev(CallerInfo _rpc_caller)
        {
            if (_rpc_caller is StreamCallerInfo)
            {error("not implemented yet");}
            else if (_rpc_caller is DatagramCallerInfo)
            {
                DatagramCallerInfo rpc_caller = (DatagramCallerInfo)_rpc_caller;
                assert(rpc_caller.listener is DatagramSystemListener);
                DatagramSystemListener _listener = (DatagramSystemListener)rpc_caller.listener;
                foreach (string dev in pseudonic_map.keys)
                {
                    PseudoNetworkInterface pseudonic = pseudonic_map[dev];
                    if (pseudonic.listen_pathname != _listener.listen_pathname) continue;
                    if (pseudonic.send_pathname != _listener.send_pathname) continue;
                    return dev;
                }
                assert_not_reached();
            }
            else abort_tasklet(@"Unknown caller_info: $(_rpc_caller.get_type().name())");
        }

        public INeighborhoodArc?
        from_caller_get_nodearc(CallerInfo rpc_caller)
        {
            error("not implemented yet");
        }

        // from_caller_get_identityarc not in this test

        private class ServerErrorHandler : Object, IErrorHandler
        {
            private string name;
            public ServerErrorHandler(string name)
            {
                this.name = name;
            }

            public void error_handler(Error e)
            {
                error(@"ServerErrorHandler '$(name)': $(e.message)");
            }
        }

        private class ServerDelegate : Object, IDelegate
        {
            public ServerDelegate(SkeletonFactory skeleton_factory)
            {
                this.skeleton_factory = skeleton_factory;
            }
            private SkeletonFactory skeleton_factory;

            public Gee.List<IAddressManagerSkeleton> get_addr_set(CallerInfo caller_info)
            {
                if (caller_info is StreamCallerInfo)
                {
                    StreamCallerInfo c = (StreamCallerInfo)caller_info;
                    var ret = new ArrayList<IAddressManagerSkeleton>();
                    IAddressManagerSkeleton? d = skeleton_factory.get_dispatcher(c);
                    if (d != null) ret.add(d);
                    return ret;
                }
                else if (caller_info is DatagramCallerInfo)
                {
                    DatagramCallerInfo c = (DatagramCallerInfo)caller_info;
                    return skeleton_factory.get_dispatcher_set(c);
                }
                else
                {
                    error(@"Unexpected class $(caller_info.get_type().name())");
                }
            }
        }

        /* A skeleton for the whole-node remotable methods
         */
        private class NodeSkeleton : Object, IAddressManagerSkeleton
        {
            public NeighborhoodNodeID id;

            public unowned INeighborhoodManagerSkeleton
            neighborhood_manager_getter()
            {
                // global var neighborhood_mgr is NeighborhoodManager, which is a INeighborhoodManagerSkeleton
                return neighborhood_mgr;
            }

            protected unowned IIdentityManagerSkeleton
            identity_manager_getter()
            {
                error("not in this test");
            }

            public unowned IQspnManagerSkeleton
            qspn_manager_getter()
            {
                error("not in this test");
            }

            public unowned IPeersManagerSkeleton
            peers_manager_getter()
            {
                error("not in this test");
            }

            public unowned ICoordinatorManagerSkeleton
            coordinator_manager_getter()
            {
                error("not in this test");
            }

            public unowned IHookingManagerSkeleton
            hooking_manager_getter()
            {
                error("not in this test");
            }

            /* TODO in ntkdrpc
            public unowned IAndnaManagerSkeleton
            andna_manager_getter()
            {
                error("not in this test");
            }
            */
        }
    }
}