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
                throw new NeighborhoodGetRttError.GENERIC(@"ping: error $(com_ret.stderr)");
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

    public class AddressManagerForIdentity : Object, IAddressManagerSkeleton
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

    public class AddressManagerForNode : Object, IAddressManagerSkeleton
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

    public class FakeQspnManager : Object, IQspnManagerSkeleton
    {
		public IQspnEtpMessage get_full_etp (IQspnAddress requesting_address, CallerInfo? caller = null)
		throws QspnNotAcceptedError, QspnBootstrapInProgressError
		{
		    error("not in this test");
		}

		public void send_etp (IQspnEtpMessage etp, bool is_full, CallerInfo? caller = null)
		throws QspnNotAcceptedError
		{
		    error("not implemented yet");
		}
    }

    public class FakePeersManager : Object, IPeersManagerSkeleton
    {
		public void forward_peer_message (IPeerMessage peer_message, CallerInfo? caller = null)
		{
		    error("not implemented yet");
		}

		public IPeerParticipantSet get_participant_set (int lvl, CallerInfo? caller = null)
		throws PeersInvalidRequest
		{
		    error("not in this test");
		}

		public IPeersRequest get_request (int msg_id, IPeerTupleNode respondant, CallerInfo? caller = null)
		throws PeersUnknownMessageError, PeersInvalidRequest
		{
		    error("not in this test");
		}

		public void set_failure (int msg_id, IPeerTupleGNode tuple, CallerInfo? caller = null)
		{
		    error("not in this test");
		}

		public void set_next_destination (int msg_id, IPeerTupleGNode tuple, CallerInfo? caller = null)
		{
		    error("not in this test");
		}

		public void set_non_participant (int msg_id, IPeerTupleGNode tuple, CallerInfo? caller = null)
		{
		    error("not in this test");
		}

		public void set_participant (int p_id, IPeerTupleGNode tuple, CallerInfo? caller = null)
		{
		    error("not in this test");
		}

		public void set_redo_from_start (int msg_id, IPeerTupleNode respondant, CallerInfo? caller = null)
		{
		    error("not in this test");
		}

		public void set_refuse_message (int msg_id, string refuse_message, IPeerTupleNode respondant, CallerInfo? caller = null)
		{
		    error("not in this test");
		}

		public void set_response (int msg_id, IPeersResponse response, IPeerTupleNode respondant, CallerInfo? caller = null)
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
        public NodeID id;
        public FakeQspnManager qspn;
        public string to_string()
        {
            return @"id.id";
        }
    }

    class HandledNic : Object
    {
        public string dev;
        public string mac;
        public string linklocal;
    }

    class ArcIdentity : Object
    {
        public NodeID peer_nodeid;
        public string peer_mac;
        public string peer_linklocal;
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
    HashMap<string,ArrayList<ArcIdentity>> node_f;
    HashMap<int,INeighborhoodArc> node_arcs;
    int next_arc_id;
    HashMap<string, string> local_addresses;

    int main(string[] args)
    {
        if (args.length != 3) error(@"usage: $(args[0]) first-id max-arcs");
        int first_id = int.parse(args[1]);
        int max_arcs = int.parse(args[2]);

        // Initialize tasklet system
        PthTaskletImplementer.init();
        client_tasklet = PthTaskletImplementer.get_tasklet_system();

        Time n = Time.local(time_t());
        print(@"$(n)\n");
        try {
            TaskletCommandResult com_ret = client_tasklet.exec_command(@"sysctl net.ipv4.conf.all.rp_filter=0");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.stderr)\n");
            com_ret = client_tasklet.exec_command(@"sysctl -n net.ipv4.conf.all.rp_filter");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.stderr)\n");
            if (com_ret.stdout != "0\n")
                error(@"Failed to unset net.ipv4.conf.all.rp_filter '$(com_ret.stdout)'\n");
        } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}

        // Prepare for storing stuff
        node_arcs = new HashMap<int,INeighborhoodArc>();
        next_arc_id = 0;
        identities = new ArrayList<Identity>();
        local_addresses = new HashMap<string,string>();
        // Set up associations (ns, in, f)
        node_ns = new HashMap<string,string>();
        node_in = new HashMap<string,HashMap<string,HandledNic>>();
        node_f = new HashMap<string,ArrayList<ArcIdentity>>();
        // generate my first identity: NodeID and associations
        Identity i_one = new Identity();
        i_one.id = new NodeID(first_id);
        i_one.qspn = new FakeQspnManager();
        identities.add(i_one);
        node_ns[@"$(i_one)"] = ""; // namespace default
        node_in[@"$(i_one)"] = new HashMap<string,HandledNic>();

        //
        node_skeleton = new AddressManagerForNode();
        node_skeleton.peers_manager = new FakePeersManager();

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(client_tasklet);
        // Initialize module neighborhood
        NeighborhoodManager.init(client_tasklet);

        // create neighborhood_manager
        neighborhood_manager = new NeighborhoodManager(
                (/*NodeID*/ source_id, /*NodeID*/ unicast_id, /*string*/ peer_address) => {
                    IAddressManagerSkeleton? ret;
                    error("not yet implemented");
                    /**L'utilizzatore del modulo, che conosce le identità del nodo e gli archi-identità
                     * che li collegano ad altri nodi, restituisce, se esiste, lo skeleton relativo alla
                     * identità identity_aware_unicast_id, ma solo se questa è collegata tramite un
                     * arco-identità alla identità identity_aware_source_id. Inoltre deve trattarsi di un
                     * arco-identità che si appoggia all'arco reale formato con peer_address. Altrimenti null. 
                    */
                },
                (/*NodeID*/ source_id, /*Gee.List<NodeID>*/ broadcast_set, /*string*/ peer_address, /*string*/ dev) => {
                    Gee.List<IAddressManagerSkeleton> ret;
                    error("not yet implemented");
                    /**L'utilizzatore del modulo restituisce una lista con gli skeleton relativi alle sue
                     * identità che sono incluse in identity_aware_broadcast_set, ma solo quelle che sono
                     * collegate tramite un arco-identità alla identità identity_aware_source_id e tale
                     * arco-identità si appoggia all'arco reale formato su dev con peer_address.
                    */
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
                print(@"$(m) ");
                print(@"Added arc (arc-id=$(next_arc_id)) from $(arc.nic.dev) with $(arc.neighbour_mac), RTT $(arc.cost)\n");
                node_arcs[next_arc_id] = arc;
                next_arc_id++;
            }
        );
        neighborhood_manager.arc_removed.connect(
            (arc) => {
                Time m = Time.local(time_t());
                int arc_id = -1;
                foreach (Map.Entry<int,INeighborhoodArc> e in node_arcs.entries)
                    if (e.@value == arc) arc_id = e.key;
                print(@"$(m) ");
                print(@"Removed arc (arc-id=$(arc_id)) with $(arc.neighbour_mac)\n");
            }
        );
        neighborhood_manager.arc_changed.connect(
            (arc) => {
                Time m = Time.local(time_t());
                int arc_id = -1;
                foreach (Map.Entry<int,INeighborhoodArc> e in node_arcs.entries)
                    if (e.@value == arc) arc_id = e.key;
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
        try {
            TaskletCommandResult com_ret = client_tasklet.exec_command(@"sysctl net.ipv4.conf.$(dev).rp_filter=0");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.stderr)\n");
            com_ret = client_tasklet.exec_command(@"sysctl -n net.ipv4.conf.$(dev).rp_filter");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.stderr)\n");
            if (com_ret.stdout != "0\n")
                error(@"Failed to unset net.ipv4.conf.$(dev).rp_filter '$(com_ret.stdout)'\n");
        } catch (Error e) {error(@"Unable to spawn a command: $(e.message)");}
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
                        Gee.List<INeighborhoodArc> arcs = neighborhood_manager.current_arcs();
                        print(@"Current arcs: $(arcs.size).\n");
                        // TODO
                    }
                    else if (_args[0] == "manage-nic" && _args.size == 2)
                    {
                        manage_nic(_args[1]);
                    }
                    else if (_args[0] == "add-arc" && _args.size == 4)
                    {
                        error("not implemented yet");
                    }
                    else if (_args[0] == "add-id" && _args.size >= 3)
                    {
                        error("not implemented yet");
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
                        error("not implemented yet");
                    }
                    else if (_args[0] == "whole-node-broadcast" && _args.size >= 4)
                    {
                        error("not implemented yet");
                    }
                    else if (_args[0] == "identity-aware-unicast" && _args.size == 6)
                    {
                        error("not implemented yet");
                    }
                    else if (_args[0] == "identity-aware-broadcast" && _args.size >= 5)
                    {
                        error("not implemented yet");
                    }
                    else if (_args[0] == "help")
                    {
                        print("""
Command list:

> info
  Shows informations gathered by this node.

> manage-nic <my-dev>
  Starts to manage a NIC.

> add-arc <arc-id> <my-id> <its-id>
  Adds an identity-arc.

> add-id <my-old-id> <my-new-id> [<arc-id> <its-old-id> <its-new-id>] [...]
  Creates a new identity for this node based on a previous one.
  Provides the identification of any neighbor identity that has changed too.

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
                        print("CLI: unknown command. Try help.\n");
                    }
                }
            } catch (Error e) {
                error(@"Error during read of CLI: $(e.message)");
            }
        }
    }
}

