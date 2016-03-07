/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2014-2016 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;
using TaskletSystem;

const uint16 ntkd_port = 60269;

namespace Netsukuku
{
    class MyIPRouteManager : Object, INeighborhoodIPRouteManager
    {
        public void add_address(
                            string my_addr,
                            string my_dev
                        )
        {
            try {
                TaskletCommandResult com_ret = client_tasklet.exec_command(@"ip address add $(my_addr) dev $(my_dev)");
                if (com_ret.exit_status != 0)
                    error(@"$(com_ret.stderr)\n");
            } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
        }

        public void add_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        )
        {
            try {
                TaskletCommandResult com_ret = client_tasklet.exec_command(@"ip route add $(neighbor_addr) dev $(my_dev) src $(my_addr)");
                if (com_ret.exit_status != 0)
                    error(@"$(com_ret.stderr)\n");
            } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
        }

        public void remove_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        )
        {
            try {
                TaskletCommandResult com_ret = client_tasklet.exec_command(@"ip route del $(neighbor_addr) dev $(my_dev) src $(my_addr)");
                if (com_ret.exit_status != 0)
                    error(@"$(com_ret.stderr)\n");
            } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
        }

        public void remove_address(
                            string my_addr,
                            string my_dev
                        )
        {
            try {
                TaskletCommandResult com_ret = client_tasklet.exec_command(@"ip address del $(my_addr)/32 dev $(my_dev)");
                if (com_ret.exit_status != 0)
                    error(@"$(com_ret.stderr)\n");
            } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
        }
    }

    class MyStubFactory: Object, INeighborhoodStubFactory
    {
        public IAddressManagerStub
                        get_broadcast(
                            Gee.List<string> devs,
                            Gee.List<string> src_ips,
                            ISourceID source_id,
                            IBroadcastID broadcast_id,
                            IAckCommunicator? ack_com
                        )
        {
            assert(! devs.is_empty);
            assert(devs.size == src_ips.size);
            var bc = get_addr_broadcast(devs, src_ips, ntkd_port, source_id, broadcast_id, ack_com);
            return bc;
        }

        public IAddressManagerStub
                        get_unicast(
                            string dev,
                            string src_ip,
                            ISourceID source_id,
                            IUnicastID unicast_id,
                            bool wait_reply
                        )
        {
            var uc = get_addr_unicast(dev, ntkd_port, src_ip, source_id, unicast_id, wait_reply);
            return uc;
        }

        public IAddressManagerStub
                        get_tcp(
                            string dest,
                            ISourceID source_id,
                            IUnicastID unicast_id,
                            bool wait_reply
                        )
        {
            var tc = get_addr_tcp_client(dest, ntkd_port, source_id, unicast_id);
            assert(tc is ITcpClientRootStub);
            ((ITcpClientRootStub)tc).wait_reply = wait_reply;
            return tc;
        }
    }

    public class MyNetworkInterface : Object, INeighborhoodNetworkInterface
    {
        public MyNetworkInterface(string dev,
                   string mac)
        {
            _dev = dev;
            _mac = mac;
        }

        private string _dev;
        private string _mac;

        /* Public interface INetworkInterface
         */

        public string dev
        {
            get {
                return _dev;
            }
        }

        public string mac
        {
            get {
                return _mac;
            }
        }

        public long measure_rtt(string peer_addr, string peer_mac, string my_dev, string my_addr) throws NeighborhoodGetRttError
        {
            TaskletCommandResult com_ret;
            try {
                com_ret = client_tasklet.exec_command(@"ping -n -q -c 1 $(peer_addr)");
            } catch (Error e) {
                throw new NeighborhoodGetRttError.GENERIC(@"Unable to spawn a command: $(e.message)");
            }
            if (com_ret.exit_status != 0)
                throw new NeighborhoodGetRttError.GENERIC(@"ping: error $(com_ret.stdout)");
            foreach (string line in com_ret.stdout.split("\n"))
            {
                /*  """rtt min/avg/max/mdev = 2.854/2.854/2.854/0.000 ms"""  */
                if (line.has_prefix("rtt ") && line.has_suffix(" ms"))
                {
                    string s2 = line.substring(line.index_of(" = ") + 3);
                    string s3 = s2.substring(0, s2.index_of("/"));
                    double x;
                    bool res = double.try_parse (s3, out x);
                    if (res)
                    {
                        return (long)(x * 1000);
                    }
                }
            }
            throw new NeighborhoodGetRttError.GENERIC(@"could not parse $(com_ret.stdout)");
        }
    }

    public class MyMessage : Object, IPeerMessage, IQspnEtpMessage
    {
        public MyMessage(string msg)
        {
            this.msg = msg;
        }
        public string msg {get; set;}
    }

    class AddressManagerForIdentity : Object, IAddressManagerSkeleton
    {
        public virtual unowned INeighborhoodManagerSkeleton
        neighborhood_manager_getter()
        {
            error("AddressManagerForIdentity.neighborhood_manager_getter: not for identity");
        }

        public FakeQspnManager qspn_manager;
        public virtual unowned IQspnManagerSkeleton
        qspn_manager_getter()
        {
            return qspn_manager;
        }

        public virtual unowned IPeersManagerSkeleton
        peers_manager_getter()
        {
            error("AddressManagerForIdentity.peers_manager_getter: not for identity");
        }

        public virtual unowned ICoordinatorManagerSkeleton
        coordinator_manager_getter()
        {
            error("AddressManagerForIdentity.coordinator_manager_getter: not in this test");
        }
    }

    class AddressManagerForNode : Object, IAddressManagerSkeleton
    {
        public weak NeighborhoodManager neighborhood_manager;
        public unowned INeighborhoodManagerSkeleton neighborhood_manager_getter()
        {
            return neighborhood_manager;
        }

        public virtual unowned IQspnManagerSkeleton
        qspn_manager_getter()
        {
            error("AddressManagerForNode.peers_manager_getter: not for node");
        }

        public FakePeersManager peers_manager;
        public virtual unowned IPeersManagerSkeleton
        peers_manager_getter()
        {
            return peers_manager;
        }

        public virtual unowned ICoordinatorManagerSkeleton
        coordinator_manager_getter()
        {
            error("AddressManagerForNode.coordinator_manager_getter: not in this test");
        }
    }

    class FakeQspnManager : Object, IQspnManagerSkeleton
    {
        public Identity id;
        public FakeQspnManager(Identity id)
        {
            this.id = id;
        }

        public IQspnEtpMessage get_full_etp(IQspnAddress requesting_address, CallerInfo? caller = null)
        throws QspnNotAcceptedError, QspnBootstrapInProgressError
        {
            error("not in this test");
        }

        public void send_etp(IQspnEtpMessage etp, bool is_full, CallerInfo? caller = null)
        throws QspnNotAcceptedError
        {
            assert(etp is MyMessage);
            MyMessage msg = (MyMessage)etp;
            ISourceID sourceid;
            string dev;
            if (caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo c = (TcpclientCallerInfo)caller;
                sourceid = c.sourceid;
                dev = "";
                foreach (string k in local_addresses.keys) if (local_addresses[k] == c.my_address) dev = k;
                if (dev == "")
                {
                    print("send_etp: called from a node which is not a neighbor.\n");
                    return;
                }
            }
            else if (caller is UnicastCallerInfo)
            {
                UnicastCallerInfo c = (UnicastCallerInfo)caller;
                sourceid = c.sourceid;
                dev = c.dev;
            }
            else if (caller is BroadcastCallerInfo)
            {
                BroadcastCallerInfo c = (BroadcastCallerInfo)caller;
                sourceid = c.sourceid;
                dev = c.dev;
            }
            else assert_not_reached();
            NodeID identity_aware_my_id = id.id;
            NodeID? identity_aware_peer_id = neighborhood_manager.get_identity(sourceid);
            if (identity_aware_peer_id == null)
            {
                error("send_etp: the caller did not prepare a message suited for identity-aware module");
            }
            print(@"As identity $(identity_aware_my_id.id), from peer-identity $(identity_aware_peer_id.id) on device $(dev), got message: \"$(msg.msg)\".\n");
        }
    }

    public class FakePeersManager : Object, IPeersManagerSkeleton
    {
        public void forward_peer_message(IPeerMessage peer_message, CallerInfo? caller = null)
        {
            assert(peer_message is MyMessage);
            MyMessage msg = (MyMessage)peer_message;
            ISourceID sourceid;
            string dev;
            if (caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo c = (TcpclientCallerInfo)caller;
                sourceid = c.sourceid;
                dev = "";
                foreach (string k in local_addresses.keys) if (local_addresses[k] == c.my_address) dev = k;
                if (dev == "")
                {
                    print("forward_peer_message: called from a node which is not a neighbor.\n");
                    return;
                }
            }
            else if (caller is UnicastCallerInfo)
            {
                UnicastCallerInfo c = (UnicastCallerInfo)caller;
                sourceid = c.sourceid;
                dev = c.dev;
            }
            else if (caller is BroadcastCallerInfo)
            {
                BroadcastCallerInfo c = (BroadcastCallerInfo)caller;
                sourceid = c.sourceid;
                dev = c.dev;
            }
            else assert_not_reached();
            INeighborhoodArc? arc = neighborhood_manager.get_node_arc(sourceid, dev);
            if (arc == null)
            {
                print("forward_peer_message: cannot find source node-arc.\n");
                return;
            }
            print(@"As a whole-node, from arc-id=$(find_arc_id(arc)), got message: \"$(msg.msg)\".\n");
        }

        public IPeerParticipantSet get_participant_set(int lvl, CallerInfo? caller = null)
        throws PeersInvalidRequest
        {
            error("not in this test");
        }

        public IPeersRequest get_request(int msg_id, IPeerTupleNode respondant, CallerInfo? caller = null)
        throws PeersUnknownMessageError, PeersInvalidRequest
        {
            error("not in this test");
        }

        public void set_failure(int msg_id, IPeerTupleGNode tuple, CallerInfo? caller = null)
        {
            error("not in this test");
        }

        public void set_next_destination(int msg_id, IPeerTupleGNode tuple, CallerInfo? caller = null)
        {
            error("not in this test");
        }

        public void set_non_participant(int msg_id, IPeerTupleGNode tuple, CallerInfo? caller = null)
        {
            error("not in this test");
        }

        public void set_participant(int p_id, IPeerTupleGNode tuple, CallerInfo? caller = null)
        {
            error("not in this test");
        }

        public void set_redo_from_start(int msg_id, IPeerTupleNode respondant, CallerInfo? caller = null)
        {
            error("not in this test");
        }

        public void set_refuse_message(int msg_id, string refuse_message, IPeerTupleNode respondant, CallerInfo? caller = null)
        {
            error("not in this test");
        }

        public void set_response(int msg_id, IPeersResponse response, IPeerTupleNode respondant, CallerInfo? caller = null)
        {
            error("not in this test");
        }
    }

    class MyServerDelegate : Object, IRpcDelegate
    {
        public Gee.List<IAddressManagerSkeleton> get_addr_set(CallerInfo caller)
        {
            if (caller is TcpclientCallerInfo)
            {
                TcpclientCallerInfo c = (TcpclientCallerInfo)caller;
                string peer_address = c.peer_address;
                ISourceID sourceid = c.sourceid;
                IUnicastID unicastid = c.unicastid;
                var ret = new ArrayList<IAddressManagerSkeleton>();
                IAddressManagerSkeleton? d = neighborhood_manager.get_dispatcher(sourceid, unicastid, peer_address, null);
                if (d != null) ret.add(d);
                return ret;
            }
            else if (caller is UnicastCallerInfo)
            {
                UnicastCallerInfo c = (UnicastCallerInfo)caller;
                string peer_address = c.peer_address;
                string dev = c.dev;
                ISourceID sourceid = c.sourceid;
                IUnicastID unicastid = c.unicastid;
                var ret = new ArrayList<IAddressManagerSkeleton>();
                IAddressManagerSkeleton? d = neighborhood_manager.get_dispatcher(sourceid, unicastid, peer_address, dev);
                if (d != null) ret.add(d);
                return ret;
            }
            else if (caller is BroadcastCallerInfo)
            {
                BroadcastCallerInfo c = (BroadcastCallerInfo)caller;
                string peer_address = c.peer_address;
                string dev = c.dev;
                ISourceID sourceid = c.sourceid;
                IBroadcastID broadcastid = c.broadcastid;
                return neighborhood_manager.get_dispatcher_set(sourceid, broadcastid, peer_address, dev);
            }
            else
            {
                error(@"Unexpected class $(caller.get_type().name())");
            }
        }
    }

    class MyServerErrorHandler : Object, IRpcErrorHandler
    {
        public void error_handler(Error e)
        {
            error(@"error_handler: $(e.message)");
        }
    }

    class Identity : Object
    {
        public Identity(int my_id)
        {
            id = new NodeID(my_id);
            qspn = new FakeQspnManager(this);
            identity_skeleton = new AddressManagerForIdentity();
            identity_skeleton.qspn_manager = qspn;
        }

        public NodeID id;
        public FakeQspnManager qspn;
        public AddressManagerForIdentity identity_skeleton;

        public string to_string()
        {
            return @"$(id.id)";
        }
    }

    class HandledNic : Object
    {
        public string dev;
        public string mac;
        public string linklocal;
    }

    class IdentityArc : Object
    {
        public NodeID peer_nodeid;
        public string peer_mac;
        public string peer_linklocal;
        public IdentityArc copy()
        {
            IdentityArc ret = new IdentityArc();
            ret.peer_nodeid = peer_nodeid;
            ret.peer_mac = peer_mac;
            ret.peer_linklocal = peer_linklocal;
            return ret;
        }
    }

    class MigrationData : Object
    {
        public int migration_id;
        public NodeID old_id;
        public NodeID new_id;
        public HashMap<string,MigrationDeviceData> devices;
    }

    class MigrationDeviceData : Object
    {
        public string real_mac;
        public string old_id_new_dev;
        public string old_id_new_mac;
        public string old_id_new_linklocal;
    }

    class MigratedWithMe : Object
    {
        public INeighborhoodArc arc;
        public NodeID peer_old_id;
        public NodeID peer_new_id;
        public string peer_old_id_new_mac;
        public string peer_old_id_new_linklocal;
    }

    AddressManagerForNode node_skeleton;
    MyServerDelegate dlg;
    MyServerErrorHandler err;
    ArrayList<ITaskletHandle> t_udp_list;

    ITasklet client_tasklet;
    NeighborhoodManager? neighborhood_manager;
    ArrayList<Identity> identities;
    HashMap<string,string> node_ns;
    HashMap<string,HashMap<string,HandledNic>> node_in;
    HashMap<string,ArrayList<IdentityArc>> node_f;
    HashMap<int,INeighborhoodArc> node_arcs;
    int next_arc_id;
    HashMap<string, string> local_addresses;

    int main(string[] args)
    {
        if (args.length != 3) error(@"usage: $(args[0]) first-id max-arcs");
        int first_id = int.parse(args[1]);
        if (first_id <= 0) error(@"usage: $(args[0]) first-id max-arcs");
        int max_arcs = int.parse(args[2]);
        if (max_arcs <= 0) error(@"usage: $(args[0]) first-id max-arcs");

        // Initialize tasklet system
        PthTaskletImplementer.init();
        client_tasklet = PthTaskletImplementer.get_tasklet_system();

        Time n = Time.local(time_t());
        print(@"$(n)\n");
        prepare_all_nics();

        // Prepare for storing stuff
        node_arcs = new HashMap<int,INeighborhoodArc>();
        next_arc_id = 1;
        identities = new ArrayList<Identity>();
        local_addresses = new HashMap<string,string>();
        // Set up associations (ns, in, f)
        node_ns = new HashMap<string,string>();
        node_in = new HashMap<string,HashMap<string,HandledNic>>();
        node_f = new HashMap<string,ArrayList<IdentityArc>>();
        // generate my first identity: NodeID and associations
        create_identity(first_id, ""); // in namespace default

        //
        node_skeleton = new AddressManagerForNode();
        node_skeleton.peers_manager = new FakePeersManager();

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(client_tasklet);
        // Initialize module neighborhood
        NeighborhoodManager.init(client_tasklet);
        // Initialize my serializables
        typeof(MyMessage).class_peek();

        // create neighborhood_manager
        neighborhood_manager = new NeighborhoodManager(
                (/*NodeID*/ source_id, /*NodeID*/ unicast_id, /*string*/ peer_address) => {
                    Identity my_id;
                    try {
                        my_id = find_identity(@"$(unicast_id.id)");
                    } catch (FindIdentityError e) {
                        return null;
                    }
                    int arc_id = -1;
                    foreach (int _arc_id in node_arcs.keys)
                    {
                        INeighborhoodArc arc = node_arcs[_arc_id];
                        if (arc.neighbour_nic_addr == peer_address)
                        {
                            arc_id = _arc_id;
                            break;
                        }
                    }
                    if (arc_id == -1) return null;
                    string k = @"$(my_id)-$(arc_id)";
                    foreach (IdentityArc identity_arc in node_f[k])
                    {
                        if (identity_arc.peer_nodeid.equals(source_id))
                        {
                            return my_id.identity_skeleton;
                        }
                    }
                    return null;
                },
                (/*NodeID*/ source_id, /*Gee.List<NodeID>*/ broadcast_set, /*string*/ peer_address, /*string*/ dev) => {
                    ArrayList<IAddressManagerSkeleton> ret = new ArrayList<IAddressManagerSkeleton>();
                    int arc_id = -1;
                    foreach (int _arc_id in node_arcs.keys)
                    {
                        INeighborhoodArc arc = node_arcs[_arc_id];
                        if (arc.neighbour_nic_addr == peer_address)
                        {
                            arc_id = _arc_id;
                            break;
                        }
                    }
                    if (arc_id == -1) return ret;
                    ArrayList<Identity> my_id_set = new ArrayList<Identity>();
                    foreach (NodeID one_id in broadcast_set)
                    {
                        try {
                            my_id_set.add(find_identity(@"$(one_id.id)"));
                        } catch (FindIdentityError e) {
                        }
                    }
                    foreach (Identity my_id in my_id_set)
                    {
                        string k = @"$(my_id)-$(arc_id)";
                        foreach (IdentityArc identity_arc in node_f[k])
                        {
                            if (identity_arc.peer_nodeid.equals(source_id))
                            {
                                ret.add(my_id.identity_skeleton);
                            }
                        }
                    }
                    return ret;
                },
                /*IAddressManagerSkeleton*/ node_skeleton,
                max_arcs, new MyStubFactory(), new MyIPRouteManager());
        node_skeleton.neighborhood_manager = neighborhood_manager;
        // connect signals
        neighborhood_manager.nic_address_set.connect(
            (dev, linklocal) => {
                Time m = Time.local(time_t());
                print(@"$(m) ");
                print(@"Set linklocal address $(linklocal) to $(dev)\n");
                local_addresses[dev] = linklocal;
            }
        );
        neighborhood_manager.nic_address_unset.connect(
            (dev) => {
                Time m = Time.local(time_t());
                print(@"$(m) ");
                print(@"Unset linklocal address from $(dev)\n");
                local_addresses.unset(dev);
            }
        );
        neighborhood_manager.arc_added.connect(
            (arc) => {
                Time m = Time.local(time_t());
                int arc_id = next_arc_id++;
                print(@"$(m) ");
                print(@"Added arc (arc-id=$(arc_id)) from $(arc.nic.dev) with $(arc.neighbour_mac), RTT $(arc.cost)\n");
                node_arcs[arc_id] = arc;
                // identities and this arc
                foreach (Identity my_id in identities)
                {
                    string k = @"$(my_id)-$(arc_id)";
                    node_f[k] = new ArrayList<IdentityArc>();
                }
            }
        );
        neighborhood_manager.arc_removed.connect(
            (arc) => {
                Time m = Time.local(time_t());
                int arc_id = find_arc_id(arc);
                print(@"$(m) ");
                print(@"Removed arc (arc-id=$(arc_id)) with $(arc.neighbour_mac)\n");
                node_arcs.unset(arc_id);
                // identities and this arc
                foreach (Identity my_id in identities)
                {
                    string k = @"$(my_id)-$(arc_id)";
                    node_f.unset(k);
                }
            }
        );
        neighborhood_manager.arc_changed.connect(
            (arc) => {
                Time m = Time.local(time_t());
                int arc_id = find_arc_id(arc);
                print(@"$(m) ");
                print(@"Changed arc (arc-id=$(arc_id)) with $(arc.neighbour_mac), RTT $(arc.cost)\n");
            }
        );

        dlg = new MyServerDelegate();
        err = new MyServerErrorHandler();

        // Handle for TCP
        ITaskletHandle t_tcp;
        // Handles for UDP
        t_udp_list = new ArrayList<ITaskletHandle>();

        // start listen TCP
        t_tcp = tcp_listen(dlg, err, ntkd_port);

        // create module for whole-node messages
        node_skeleton.peers_manager = new FakePeersManager();

        // start a tasklet to get commands from stdin.
        CommandLineInterfaceTasklet ts = new CommandLineInterfaceTasklet();
        client_tasklet.spawn(ts);

        // register handlers for SIGINT and SIGTERM to exit
        Posix.signal(Posix.SIGINT, safe_exit);
        Posix.signal(Posix.SIGTERM, safe_exit);
        // Main loop
        while (true)
        {
            client_tasklet.ms_wait(100);
            if (do_me_exit) break;
        }
        print("\n");

        cleanup();

        // This will destroy the object NeighborhoodManager and hence call
        //  its stop_monitor_all.
        // Beware that node_skeleton.neighborhood_manager
        //  is a weak reference.
        // Beware also that since we destroy the object, we won't receive
        //  any more signal from it, such as nic_address_unset for all the
        //  linklocal addresses that will be removed from the NICs.
        neighborhood_manager = null;

        foreach (ITaskletHandle t_udp in t_udp_list) t_udp.kill();
        t_tcp.kill();

        client_tasklet.ms_wait(100);
        PthTaskletImplementer.kill();
        return 0;
    }

    bool do_me_exit = false;
    void safe_exit(int sig)
    {
        // We got here because of a signal. Quick processing.
        do_me_exit = true;
    }

    void manage_nic(string dev)
    {
        prepare_nic(dev);
        // start listen UDP on dev
        t_udp_list.add(udp_listen(dlg, err, ntkd_port, dev));
        // prepare a NIC and run monitor
        string my_mac = macgetter.get_mac(dev).up();
        MyNetworkInterface nic = new MyNetworkInterface(dev, my_mac);
        // run monitor
        neighborhood_manager.start_monitor(nic);
        // here the linklocal address has been added, and the signal handler for
        //  nic_address_set has been processed
        print(@"Monitoring dev $(nic.dev), MAC $(nic.mac), linklocal $(local_addresses[nic.dev])\n");
        // manage associations: add to the "main identity"
        foreach (Identity i in identities) if (node_ns[@"$(i)"] == "")
        {
            HandledNic hnic = new HandledNic();
            hnic.dev = dev;
            hnic.mac = my_mac;
            hnic.linklocal = local_addresses[nic.dev];
            node_in[@"$(i)"][dev] = hnic;
        }
    }

    void add_identity_arc(INeighborhoodArc arc, Identity my_id, NodeID its_id, string peer_mac, string peer_linklocal)
    {
        int arc_id = find_arc_id(arc);
        string k = @"$(my_id)-$(arc_id)";
        IdentityArc identity_arc = new IdentityArc();
        identity_arc.peer_nodeid = its_id;
        identity_arc.peer_mac = peer_mac;
        identity_arc.peer_linklocal = peer_linklocal;
        node_f[k].add(identity_arc);
    }

    void change_data_identity_arc(IdentityArc identity_arc, string peer_mac, string peer_linklocal)
    {
        identity_arc.peer_mac = peer_mac;
        identity_arc.peer_linklocal = peer_linklocal;
    }

    void whole_node_unicast(INeighborhoodArc arc, string msg)
    {
        MyMessage _msg = new MyMessage(msg);
        try {
            neighborhood_manager.get_stub_whole_node_unicast(arc).peers_manager.forward_peer_message(_msg);
        } catch (StubError.DID_NOT_WAIT_REPLY e) {
            // the method is void, so:
            assert_not_reached();
        } catch (StubError e) {
            print(@"Got a stub-error: $(e.message)\n");
        } catch (DeserializeError e) {
            print(@"Got a deserialize-error: $(e.message)\n");
        }
    }

    void whole_node_broadcast(Gee.List<INeighborhoodArc> arcs, string msg)
    {
        MyMessage _msg = new MyMessage(msg);
        try {
            MissedHandler miss = new MissedHandler();
            neighborhood_manager.get_stub_whole_node_broadcast(arcs, miss).peers_manager.forward_peer_message(_msg);
        } catch (StubError.DID_NOT_WAIT_REPLY e) {
            // the method is void, so:
            assert_not_reached();
        } catch (StubError e) {
            // the method is broadcast, so:
            assert_not_reached();
        } catch (DeserializeError e) {
            // the method is broadcast, so:
            assert_not_reached();
        }
    }
    class MissedHandler : Object, INeighborhoodMissingArcHandler
    {
        public void missing(INeighborhoodArc arc)
        {
            print(@"A broadcast message missed the arc arc-id=$(find_arc_id(arc)).\n");
        }
    }

    void identity_aware_unicast(INeighborhoodArc arc, Identity my_id, NodeID its_id, string msg)
    {
        MyMessage _msg = new MyMessage(msg);
        try {
            neighborhood_manager.get_stub_identity_aware_unicast(arc, my_id.id, its_id).qspn_manager.send_etp(_msg, true);
        } catch (QspnNotAcceptedError e) {
            assert_not_reached();
        } catch (StubError.DID_NOT_WAIT_REPLY e) {
            // the method is void, so:
            assert_not_reached();
        } catch (StubError e) {
            print(@"Got a stub-error: $(e.message)\n");
        } catch (DeserializeError e) {
            print(@"Got a deserialize-error: $(e.message)\n");
        }
    }

    void identity_aware_broadcast(Identity my_id, Gee.List<NodeID> id_set, string msg)
    {
        MyMessage _msg = new MyMessage(msg);
        try {
            MissedHandler miss = new MissedHandler();
            neighborhood_manager.get_stub_identity_aware_broadcast(my_id.id, id_set, miss).qspn_manager.send_etp(_msg, true);
        } catch (QspnNotAcceptedError e) {
            assert_not_reached();
        } catch (StubError.DID_NOT_WAIT_REPLY e) {
            // the method is broadcast, so:
            assert_not_reached();
        } catch (StubError e) {
            // the method is broadcast, so:
            assert_not_reached();
        } catch (DeserializeError e) {
            // the method is broadcast, so:
            assert_not_reached();
        }
    }

    MigrationData prepare_migration_data(Gee.List<string> devs, string prefix,
                int migration_id,
                NodeID old_id,
                NodeID new_id)
    {
        MigrationData ret = new MigrationData();
        ret.migration_id = migration_id;
        ret.old_id = old_id;
        ret.new_id = new_id;
        ret.devices = new HashMap<string,MigrationDeviceData>();
        foreach (string dev in devs)
        {
            MigrationDeviceData pseudodev = new MigrationDeviceData();
            pseudodev.real_mac = macgetter.get_mac(dev).up(); // do we need?
            pseudodev.old_id_new_dev = @"$(prefix)_$(dev)";
            try {
                TaskletCommandResult com_ret = client_tasklet.exec_command(
                        @"ip link add dev $(pseudodev.old_id_new_dev) link $(dev) type macvlan");
                if (com_ret.exit_status != 0) error(@"$(com_ret.stderr)\n");
            } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
            pseudodev.old_id_new_mac = macgetter.get_mac(pseudodev.old_id_new_dev).up();
            // generate a random IP for this pseudodev
            int i2 = Random.int_range(0, 255);
            int i3 = Random.int_range(0, 255);
            pseudodev.old_id_new_linklocal = @"169.254.$(i2).$(i3)";
            ret.devices[dev] = pseudodev;
        }
        return ret;
    }

    int a_i_next_namespace = 0;
    string a_i_new_ns_name;
    ArrayList<string> a_i_devs;
    MigrationData? a_i_migration_data=null;
    Identity a_i_my_old_id;
    NodeID a_i_my_new_id;
    void prepare_add_identity(Identity my_old_id, NodeID my_new_id)
    {
        a_i_my_old_id = my_old_id;
        a_i_my_new_id = my_new_id;
        // Choose a name for namespace.
        int this_namespace = a_i_next_namespace++;
        a_i_new_ns_name = @"ntkv$(this_namespace)";
        // Retrieve names of real devices
        a_i_devs = new ArrayList<string>();
        a_i_devs.add_all(node_in[@"$(my_old_id)"].keys);
        // The unique code for the migration is not used in this proof-of-concept
        int migration_id = 12;
        // Prepare migration_data
        a_i_migration_data = prepare_migration_data(a_i_devs, a_i_new_ns_name, migration_id, my_old_id.id, my_new_id);
        // Show on console collected data
        foreach (string dev in a_i_migration_data.devices.keys)
        {
            MigrationDeviceData dev_data = a_i_migration_data.devices[dev];
            print(@"From real interface $(dev) ($(dev_data.real_mac))\n");
            print(@"     constructed pseudo-interface $(dev_data.old_id_new_dev) with MAC $(dev_data.old_id_new_mac)\n");
            print(@"     which will get $(dev_data.old_id_new_linklocal)\n");
        }
    }

    void finish_add_identity(ArrayList<MigratedWithMe> migr_set)
    {
        // Prepare new namespace and move pseudo-devices
        HashMap<string,HandledNic> new_nics;
        prepare_network_namespace(a_i_migration_data, a_i_new_ns_name, out new_nics);
        a_i_migration_data = null;
        // Create new identity. Swap ns for new and old identities.
        int _my_new_id = a_i_my_new_id.id;
        string old_ns_name = node_ns[@"$(a_i_my_old_id)"];
        create_identity(_my_new_id, old_ns_name);
        node_ns[@"$(a_i_my_old_id)"] = a_i_new_ns_name;
        // Swap handled nics.
        foreach (string dev in a_i_devs)
        {
            node_in[@"$(_my_new_id)"][dev] = node_in[@"$(a_i_my_old_id)"][dev];
            node_in[@"$(a_i_my_old_id)"][dev] = new_nics[dev];
        }
        // Duplicate arcs and modify them in old identity
        foreach (int arc_id in node_arcs.keys)
        {
            INeighborhoodArc arc = node_arcs[arc_id];
            // ir(arc) = arc.nic.dev
            // HashMap<string,ArrayList<IdentityArc>> node_f
            string k_old = @"$(a_i_my_old_id)-$(arc_id)";
            string k_new = @"$(_my_new_id)-$(arc_id)";
            node_f[k_new] = new ArrayList<IdentityArc>();
            foreach (IdentityArc w_old in node_f[k_old])
            {
                IdentityArc w_new = w_old.copy();
                node_f[k_new].add(w_new);
                // Did w_old.peer_nodeid migrate too?
                foreach (MigratedWithMe migr in migr_set)
                {
                    if (migr.arc == arc && migr.peer_old_id.equals(w_old.peer_nodeid))
                    {
                        w_old.peer_mac = migr.peer_old_id_new_mac;
                        w_old.peer_linklocal = migr.peer_old_id_new_linklocal;
                        w_new.peer_nodeid = migr.peer_new_id;
                        break;
                    }
                }
            }
        }
    }

    void prepare_network_namespace(MigrationData migration_data, string ns_name, out HashMap<string,HandledNic> hnics)
    {
        try {
            TaskletCommandResult com_ret = client_tasklet.exec_command(@"ip netns add $(ns_name)");
            if (com_ret.exit_status != 0) error(@"$(com_ret.stderr)\n");
            prepare_all_nics(@"ip netns exec $(ns_name) ");
            hnics = new HashMap<string,HandledNic>();
            foreach (string dev in migration_data.devices.keys)
            {
                MigrationDeviceData dev_data = migration_data.devices[dev];
                com_ret = client_tasklet.exec_command(@"ip link set dev $(dev_data.old_id_new_dev) netns $(ns_name)");
                if (com_ret.exit_status != 0) error(@"$(com_ret.stderr)\n");
                prepare_nic(dev_data.old_id_new_dev, @"ip netns exec $(ns_name) ");
                HandledNic hnic = new HandledNic();
                hnic.dev = dev_data.old_id_new_dev;
                hnic.mac = dev_data.old_id_new_mac;
                hnic.linklocal = dev_data.old_id_new_linklocal;
                com_ret = client_tasklet.exec_command(@"ip netns exec $(ns_name) ip link set $(hnic.dev) up");
                if (com_ret.exit_status != 0) error(@"$(com_ret.stderr)\n");
                com_ret = client_tasklet.exec_command(@"ip netns exec $(ns_name) ip address add $(hnic.linklocal) dev $(hnic.dev)");
                if (com_ret.exit_status != 0) error(@"$(com_ret.stderr)\n");
                hnics[dev] = hnic;
            }
        } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
    }

    errordomain MakePeerIdentityError {GENERIC}
    NodeID make_peer_id(string its_id) throws MakePeerIdentityError
    {
        int i_its_id = int.parse(its_id);
        if (i_its_id <= 0) throw new MakePeerIdentityError.GENERIC("");
        return new NodeID(i_its_id);
    }

    errordomain FindArcError {GENERIC}
    INeighborhoodArc find_arc(string arc_id) throws FindArcError
    {
        int i_arc_id = int.parse(arc_id);
        if (i_arc_id <= 0) throw new FindArcError.GENERIC("");
        if (!node_arcs.has_key(i_arc_id)) throw new FindArcError.GENERIC("");
        return node_arcs[i_arc_id];
    }
    int find_arc_id(INeighborhoodArc arc)
    {
        foreach (Map.Entry<int,INeighborhoodArc> e in node_arcs.entries)
            if (e.@value == arc) return e.key;
        assert_not_reached();
    }

    errordomain FindIdentityError {GENERIC}
    Identity find_identity(string my_id) throws FindIdentityError
    {
        int i_my_id = int.parse(my_id);
        if (i_my_id <= 0) throw new FindIdentityError.GENERIC("");
        foreach (Identity _id in identities)
        {
            if (_id.id.id == i_my_id) return _id;
        }
        throw new FindIdentityError.GENERIC("");
    }

    errordomain FindIdentityArcError {GENERIC}
    IdentityArc find_identity_arc(Identity my_id, INeighborhoodArc arc, NodeID its_id)
    throws FindIdentityArcError
    {
        int arc_id = find_arc_id(arc);
        string k = @"$(my_id)-$(arc_id)";
        if (node_f.has_key(k))
        {
            foreach (IdentityArc identity_arc in node_f[k])
            {
                if (identity_arc.peer_nodeid.equals(its_id))
                {
                    return identity_arc;
                }
            }
            throw new FindIdentityArcError.GENERIC("");
        }
        throw new FindIdentityArcError.GENERIC("");
    }

    void create_identity(int id, string ns)
    {
        Identity i = new Identity(id);
        identities.add(i);
        node_ns[@"$(i)"] = ns;
        node_in[@"$(i)"] = new HashMap<string,HandledNic>();
    }

    void cleanup()
    {
        // cleanup pseudo device in preparation for a new identity that was not finished.
        if (a_i_migration_data != null)
        {
            foreach (string dev in a_i_migration_data.devices.keys)
            {
                string pseudodev = a_i_migration_data.devices[dev].old_id_new_dev;
                try {
                    TaskletCommandResult com_ret = client_tasklet.exec_command(
                            @"ip link delete $(pseudodev) type macvlan");
                    if (com_ret.exit_status != 0) error(@"$(com_ret.stderr)\n");
                } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
            }
        }
        // cleanup pseudo device and namespaces for all non-main identities.
        foreach (Identity i in identities) if (node_ns[@"$(i)"] != "")
        {
            string ns_name = node_ns[@"$(i)"];
            foreach (string dev in node_in[@"$(i)"].keys)
            {
                HandledNic hnic = node_in[@"$(i)"][dev];
                assert(hnic.dev != dev);
                try {
                    TaskletCommandResult com_ret = client_tasklet.exec_command(
                            @"ip netns exec $(ns_name) ip link delete $(hnic.dev) type macvlan");
                    if (com_ret.exit_status != 0) error(@"$(com_ret.stderr)\n");
                } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
            }
            try {
                TaskletCommandResult com_ret = client_tasklet.exec_command(
                        @"ip netns del $(ns_name)");
                if (com_ret.exit_status != 0) error(@"$(com_ret.stderr)\n");
            } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
        }
    }

    void prepare_all_nics(string ns_prefix="")
    {
        // disable rp_filter
        set_sys_ctl("net.ipv4.conf.all.rp_filter", "0", ns_prefix);
        // arp policies
        set_sys_ctl("net.ipv4.conf.all.arp_ignore", "1", ns_prefix);
        set_sys_ctl("net.ipv4.conf.all.arp_announce", "2", ns_prefix);
    }

    void prepare_nic(string nic, string ns_prefix="")
    {
        // disable rp_filter
        set_sys_ctl(@"net.ipv4.conf.$(nic).rp_filter", "0", ns_prefix);
        // arp policies
        set_sys_ctl(@"net.ipv4.conf.$(nic).arp_ignore", "1", ns_prefix);
        set_sys_ctl(@"net.ipv4.conf.$(nic).arp_announce", "2", ns_prefix);
    }

    void set_sys_ctl(string key, string val, string ns_prefix="")
    {
        try {
            TaskletCommandResult com_ret = client_tasklet.exec_command(@"$(ns_prefix)sysctl $(key)=$(val)");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.stderr)\n");
            com_ret = client_tasklet.exec_command(@"$(ns_prefix)sysctl -n $(key)");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.stderr)\n");
            if (com_ret.stdout != @"$(val)\n")
                error(@"Failed to set key '$(key)' to val '$(val)': now it reports '$(com_ret.stdout)'\n");
        } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
    }

    class CommandLineInterfaceTasklet : Object, ITaskletSpawnable
    {
        public void * func()
        {
            try {
                while (true)
                {
                    print("Ok> ");
                    uint8 buf[256];
                    size_t len = client_tasklet.read(0, (void*)buf, buf.length);
                    if (len > 255) error("Error during read of CLI: line too long");
                    string line = (string)buf;
                    if (line.has_suffix("\n")) line = line.substring(0, line.length-1);
                    ArrayList<string> _args = new ArrayList<string>();
                    foreach (string s_piece in line.split(" ")) _args.add(s_piece);
                    if (_args.size == 0)
                    {
                    }
                    else if (_args[0] == "quit" && _args.size == 1)
                    {
                        do_me_exit = true;
                    }
                    else if (_args[0] == "info" && _args.size == 1)
                    {
                        print(@"My identities: $(identities.size).\n");
                        foreach (Identity my_id in identities)
                        {
                            print(@"  $(my_id):\n");
                            string nsid = (node_ns[@"$(my_id)"] == "") ? "default" : node_ns[@"$(my_id)"];
                            print(@"    in network namespace $(nsid)\n");
                            if (node_in[@"$(my_id)"].size > 0)
                            {
                                print("    handles:\n");
                                foreach (string real_dev in node_in[@"$(my_id)"].keys)
                                {
                                    HandledNic nic = node_in[@"$(my_id)"][real_dev];
                                    print(@"      $(nic.dev)($(real_dev)) $(nic.mac) $(nic.linklocal)\n");
                                }
                            }
                        }
                        Gee.List<INeighborhoodArc> arcs = neighborhood_manager.current_arcs();
                        print(@"Current arcs: $(arcs.size).\n");
                        assert(arcs.size == node_arcs.size);
                        foreach (int arc_id in node_arcs.keys)
                        {
                            INeighborhoodArc arc = node_arcs[arc_id];
                            print(@"  $(arc_id) - from $(arc.nic.dev) with $(arc.neighbour_mac) $(arc.neighbour_nic_addr), RTT $(arc.cost)\n");
                            foreach (Identity my_id in identities)
                            {
                                string k = @"$(my_id)-$(arc_id)";
                                assert(node_f.has_key(k));
                                foreach (IdentityArc identity_arc in node_f[k])
                                {
                                    print(@"    IdentityArc $(my_id) to $(identity_arc.peer_nodeid.id) $(identity_arc.peer_mac) $(identity_arc.peer_linklocal)\n");
                                }
                            }
                        }
                        // TODO
                    }
                    else if (_args[0] == "manage-nic" && _args.size == 2)
                    {
                        manage_nic(_args[1]);
                    }
                    else if (_args[0] == "add-arc" && _args.size == 6)
                    {
                        INeighborhoodArc arc;
                        try {
                            arc = find_arc(_args[1]);
                        } catch (FindArcError e) {
                            print(@"wrong arc-id '$(_args[1])'\n");
                            continue;
                        }
                        Identity my_id;
                        try {
                            my_id = find_identity(_args[2]);
                        } catch (FindIdentityError e) {
                            print(@"wrong my-id '$(_args[2])'\n");
                            continue;
                        }
                        NodeID its_id;
                        try {
                            its_id = make_peer_id(_args[3]);
                        } catch (MakePeerIdentityError e) {
                            print(@"wrong its-id '$(_args[3])'\n");
                            continue;
                        }
                        add_identity_arc(arc, my_id, its_id, _args[4], _args[5]);
                    }
                    else if (_args[0] == "change-data-arc" && _args.size == 6)
                    {
                        INeighborhoodArc arc;
                        try {
                            arc = find_arc(_args[1]);
                        } catch (FindArcError e) {
                            print(@"wrong arc-id '$(_args[1])'\n");
                            continue;
                        }
                        Identity my_id;
                        try {
                            my_id = find_identity(_args[2]);
                        } catch (FindIdentityError e) {
                            print(@"wrong my-id '$(_args[2])'\n");
                            continue;
                        }
                        NodeID its_id;
                        try {
                            its_id = make_peer_id(_args[3]);
                        } catch (MakePeerIdentityError e) {
                            print(@"wrong its-id '$(_args[3])'\n");
                            continue;
                        }
                        IdentityArc identity_arc;
                        try {
                            identity_arc = find_identity_arc(my_id, arc, its_id);
                        } catch (FindIdentityArcError e) {
                            print("couldnt find arc\n");
                            continue;
                        }
                        change_data_identity_arc(identity_arc, _args[4], _args[5]);
                    }
                    else if (_args[0] == "prepare-add-id" && _args.size == 3)
                    {
                        Identity my_old_id;
                        try {
                            my_old_id = find_identity(_args[1]);
                        } catch (FindIdentityError e) {
                            print(@"wrong my-old-id '$(_args[1])'\n");
                            continue;
                        }
                        NodeID my_new_id;
                        try {
                            my_new_id = make_peer_id(_args[2]);
                        } catch (MakePeerIdentityError e) {
                            print(@"wrong my-new-id '$(_args[2])'\n");
                            continue;
                        }
                        prepare_add_identity(my_old_id, my_new_id);
                    }
                    else if (_args[0] == "finish-add-id")
                    {
                        if (a_i_migration_data == null)
                        {
                            print("use prepare-add-id first.'\n");
                            continue;
                        }
                        ArrayList<MigratedWithMe> migr_set = new ArrayList<MigratedWithMe>();
                        bool need_break = false;
                        for (int i = 1; i < _args.size; i+=5)
                        {
                            if (i+5 > _args.size) {
                                print("bad args\n");
                                need_break = true;
                                break;
                            }
                            MigratedWithMe migr = new MigratedWithMe();
                            migr_set.add(migr);
                            try {
                                migr.arc = find_arc(_args[i]);
                            } catch (FindArcError e) {
                                print(@"wrong arc-id '$(_args[i])'\n");
                                need_break = true;
                                break;
                            }
                            try {
                                migr.peer_old_id = make_peer_id(_args[i+1]);
                            } catch (MakePeerIdentityError e) {
                                print(@"wrong peer-old-id '$(_args[i+1])'\n");
                                need_break = true;
                                break;
                            }
                            try {
                                migr.peer_new_id = make_peer_id(_args[i+2]);
                            } catch (MakePeerIdentityError e) {
                                print(@"wrong peer-new-id '$(_args[i+2])'\n");
                                need_break = true;
                                break;
                            }
                            migr.peer_old_id_new_mac = _args[i+3];
                            migr.peer_old_id_new_linklocal = _args[i+4];
                        }
                        if (need_break) continue;
                        finish_add_identity(migr_set);
                    }
                    else if (_args[0] == "remove-arc" && _args.size == 4)
                    {
                        error("not implemented yet");
                    }
                    else if (_args[0] == "remove-id" && _args.size == 2)
                    {
                        error("not implemented yet");
                    }
                    else if (_args[0] == "whole-node-unicast" && _args.size == 4)
                    {
                        INeighborhoodArc arc;
                        try {
                            arc = find_arc(_args[1]);
                        } catch (FindArcError e) {
                            print(@"wrong arc-id '$(_args[1])'\n");
                            continue;
                        }
                        if (_args[2] != "--")
                        {
                            print("bad args\n");
                            continue;
                        }
                        whole_node_unicast(arc, _args[3]);
                    }
                    else if (_args[0] == "whole-node-broadcast" && _args.size >= 4)
                    {
                        ArrayList<INeighborhoodArc> arcs = new ArrayList<INeighborhoodArc>();
                        for (int i = 1; i < _args.size-2; i++)
                        {
                            try {
                                arcs.add(find_arc(_args[i]));
                            } catch (FindArcError e) {
                                print(@"wrong arc-id '$(_args[i])'\n");
                            }
                        }
                        if (arcs.is_empty) continue;
                        if (_args[_args.size-2] != "--")
                        {
                            print("bad args\n");
                            continue;
                        }
                        whole_node_broadcast(arcs, _args[_args.size-1]);
                    }
                    else if (_args[0] == "identity-aware-unicast" && _args.size == 6)
                    {
                        INeighborhoodArc arc;
                        try {
                            arc = find_arc(_args[1]);
                        } catch (FindArcError e) {
                            print(@"wrong arc-id '$(_args[1])'\n");
                            continue;
                        }
                        Identity my_id;
                        try {
                            my_id = find_identity(_args[2]);
                        } catch (FindIdentityError e) {
                            print(@"wrong my-id '$(_args[2])'\n");
                            continue;
                        }
                        NodeID its_id;
                        try {
                            its_id = make_peer_id(_args[3]);
                        } catch (MakePeerIdentityError e) {
                            print(@"wrong its-id '$(_args[3])'\n");
                            continue;
                        }
                        if (_args[4] != "--")
                        {
                            print("bad args\n");
                            continue;
                        }
                        identity_aware_unicast(arc, my_id, its_id, _args[5]);
                    }
                    else if (_args[0] == "identity-aware-broadcast" && _args.size >= 5)
                    {
                        Identity my_id;
                        try {
                            my_id = find_identity(_args[1]);
                        } catch (FindIdentityError e) {
                            print(@"wrong my-id '$(_args[1])'\n");
                            continue;
                        }
                        ArrayList<NodeID> id_set = new ArrayList<NodeID>();
                        for (int i = 2; i < _args.size-2; i++)
                        {
                            try {
                                id_set.add(make_peer_id(_args[i]));
                            } catch (MakePeerIdentityError e) {
                                print(@"wrong its-id '$(_args[i])'\n");
                            }
                        }
                        if (id_set.is_empty) continue;
                        if (_args[_args.size-2] != "--")
                        {
                            print("bad args\n");
                            continue;
                        }
                        identity_aware_broadcast(my_id, id_set, _args[_args.size-1]);
                    }
                    else if (_args[0] == "help")
                    {
                        print("""
Command list:

> info
  Shows informations gathered by this node.

> manage-nic <my-dev>
  Starts to manage a NIC.

> add-arc <arc-id> <my-id> <its-id> <peer-mac> <peer-linklocal>
  Adds an identity-arc.

> change-data-arc <arc-id> <my-id> <its-id> <peer-mac> <peer-linklocal>
  Changes MAC and linklocal for an identity-arc.

> prepare-add-id <my-old-id> <my-new-id>
  Prepare pseudo-interfaces and collect data to make a new identity.

> finish-add-id
         [ <arc-id>
           <peer-old-id>
           <peer-new-id>
           <peer-old-id-new-mac>
           <peer-old-id-new-linklocal> ] [...]
  Creates a new identity for this node based on a previous one.
  Provides the data for any neighbor identity that has changed too.

> remove-arc <arc-id> <my-id> <its-id>
  Removes an identity-arc.

> remove-id <my-old-id>
  Removes an identity of this node.

> whole-node-unicast <arc-id> -- <argument>
  Invokes a remote method of an identity-agnostic module
   on one specific neighbour (node).

> whole-node-broadcast <arc-id> [<arc-id> ...] -- <argument>
  Invokes a remote method of an identity-agnostic module
   on a set of specific neighbours (nodes).

> identity-aware-unicast <arc-id> <my-id> <its-id> -- <argument>
  Invokes a remote method of an identity-aware module
   on one specific neighbour (identity).

> identity-aware-broadcast <my-id> <its-id> [<its-id> ...] -- <argument>
  Invokes a remote method of an identity-agnostic module
   on a set of specific neighbours (nodes).

> help
  Shows this menu.

> Ctrl-C, quit
  Exits.

""");
                    }
                    else
                    {
                        print("CLI: unknown command or bad arguments. Try help.\n");
                    }
                }
            } catch (Error e) {
                error(@"Error during read of CLI: $(e.message)");
            }
        }
    }
}

