using Tasklets;
using Gee;
using zcd;

namespace Netsukuku
{
    public void    log_debug(string msg)   {print(msg+"\n");}
    public void    log_trace(string msg)   {print(msg+"\n");}
    public void  log_verbose(string msg)   {print(msg+"\n");}
    public void     log_info(string msg)   {print(msg+"\n");}
    public void   log_notice(string msg)   {print(msg+"\n");}
    public void     log_warn(string msg)   {print(msg+"\n");}
    public void    log_error(string msg)   {print(msg+"\n");}
    public void log_critical(string msg)   {print(msg+"\n");}

    class MyIPRouteManager : Object, INeighborhoodIPRouteManager
    {
        public void i_neighborhood_add_address(
                            string my_addr,
                            string my_dev
                        )
        {
            CommandResult com_ret = Tasklet.exec_command(@"ip address add $(my_addr) dev $(my_dev)");
            if (com_ret.exit_status != 0)
            {
                print(@"$(com_ret.cmderr)\n");
                assert(false);
            }
        }

        public void i_neighborhood_add_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        )
        {
            CommandResult com_ret = Tasklet.exec_command(@"ip route add $(neighbor_addr) dev $(my_dev) src $(my_addr)");
            if (com_ret.exit_status != 0)
            {
                print(@"$(com_ret.cmderr)\n");
                assert(false);
            }
        }

        public void i_neighborhood_remove_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        )
        {
            CommandResult com_ret = Tasklet.exec_command(@"ip route del $(neighbor_addr) dev $(my_dev) src $(my_addr)");
            if (com_ret.exit_status != 0)
            {
                print(@"$(com_ret.cmderr)\n");
                assert(false);
            }
        }

        public void i_neighborhood_remove_address(
                            string my_addr,
                            string my_dev
                        )
        {
            CommandResult com_ret = Tasklet.exec_command(@"ip address del $(my_addr)/32 dev $(my_dev)");
            if (com_ret.exit_status != 0)
            {
                print(@"$(com_ret.cmderr)\n");
                assert(false);
            }
        }
    }

    class MyStubFactory: Object, INeighborhoodStubFactory
    {
        public IAddressManagerRootDispatcher
                        i_neighborhood_get_broadcast(
                            BroadcastID bcid,
                            Gee.Collection<INeighborhoodNetworkInterface> nics,
                            INeighborhoodArcFinder arc_finder,
                            INeighborhoodArcRemover arc_remover,
                            INeighborhoodMissingArcHandler missing_handler
                        )
        {
            assert(! nics.is_empty);
            var devs = new ArrayList<string>();
            foreach (INeighborhoodNetworkInterface nic in nics)
            {
                Nic _nic = (Nic)nic;
                devs.add(_nic.i_neighborhood_dev);
            }
            var bc = new AddressManagerBroadcastClient(bcid, devs.to_array(),
                new MyAcknowledgementsCommunicator(bcid, nics, arc_finder, arc_remover, missing_handler));
            return bc;
        }

        public IAddressManagerRootDispatcher
                        i_neighborhood_get_unicast(
                            UnicastID ucid,
                            INeighborhoodNetworkInterface nic,
                            bool wait_reply=true
                        )
        {
            Nic _nic = (Nic)nic;
            var uc = new AddressManagerNeighbourClient(ucid, {_nic.i_neighborhood_dev}, null, wait_reply);
            return uc;
        }

        public IAddressManagerRootDispatcher
                        i_neighborhood_get_tcp(
                            string dest,
                            bool wait_reply=true
                        )
        {
            var uc = new AddressManagerTCPClient(dest, null, null, wait_reply);
            return uc;
        }
    }

    /* The instance of this class is created when th stub factory is invoked to
     * obtain a stub. In theory, the stub could be used for more than one call
     * and asynchronously, hence the method prepare...
     * When a remote call is made, immediately the tasklet spawned my the method
     * 'prepare' will use the arc_finder to get the list.
     */
    class MyAcknowledgementsCommunicator : Object, IAcknowledgementsCommunicator
    {
        public BroadcastID bcid;
        public Gee.Collection<INeighborhoodNetworkInterface> nics;
        public INeighborhoodArcFinder arc_finder;
        public INeighborhoodArcRemover arc_remover;
        public INeighborhoodMissingArcHandler missing_handler;

        public MyAcknowledgementsCommunicator(BroadcastID bcid,
                            Gee.Collection<INeighborhoodNetworkInterface> nics,
                            INeighborhoodArcFinder arc_finder,
                            INeighborhoodArcRemover arc_remover,
                            INeighborhoodMissingArcHandler missing_handler)
        {
            this.bcid = bcid;
            this.nics = nics;
            this.arc_finder = arc_finder;
            this.arc_remover = arc_remover;
            this.missing_handler = missing_handler;
        }

        public Channel prepare()
        {
            Channel ch = new Channel();
            Tasklet.tasklet_callback(
                (t_ack_comm, t_ch) => {
                    MyAcknowledgementsCommunicator ack_comm = (MyAcknowledgementsCommunicator)t_ack_comm;
                    ack_comm.gather_acks((Channel)t_ch);
                },
                this,
                ch
            );
            return ch;
        }

        /* Gather ACKs from expected receivers of a broadcast message
         */
        void
        gather_acks(Channel ch)
        {
            // prepare a list of expected receivers.
            var lst_expected = arc_finder.i_neighborhood_current_arcs_for_broadcast(bcid, nics);
            // Wait for the timeout and receive from the channel the list of ACKs.
            Value v = ch.recv();
            Gee.List<string> responding_macs = (Gee.List<string>)v;
            // prepare a list of missed arcs.
            var lst_missed = new ArrayList<INeighborhoodArc>();
            foreach (INeighborhoodArc expected in lst_expected)
            {
                bool has_responded = false;
                foreach (string responding_mac in responding_macs)
                {
                    if (expected.i_neighborhood_mac == responding_mac)
                    {
                        has_responded = true;
                        break;
                    }
                }
                if (! has_responded) lst_missed.add(expected);
            }
            // foreach missed arc launch in a tasklet
            // the 'missing' callback.
            foreach (INeighborhoodArc missed in lst_missed)
            {
                Tasklet.tasklet_callback(
                    (t_ack_comm, t_missed) => {
                        MyAcknowledgementsCommunicator ack_comm = (MyAcknowledgementsCommunicator)t_ack_comm;
                        ack_comm.missing_handler.i_neighborhood_missing((INeighborhoodArc)t_missed, ack_comm.arc_remover);
                    },
                    this,
                    missed
                );
            }
        }
    }

    public class MyNodeID : Object, ISerializable, INeighborhoodNodeID
    {
        public int id {get; private set;}
        public int netid {get; private set;}
        public MyNodeID(int netid)
        {
            id = Random.int_range(0, 10000);
            this.netid = netid;
        }

        public bool i_neighborhood_equals(INeighborhoodNodeID other)
        {
            if (!(other is MyNodeID)) return false;
            return id == (other as MyNodeID).id;
        }

        public bool i_neighborhood_is_on_same_network(INeighborhoodNodeID other)
        {
            if (!(other is MyNodeID)) return false;
            return netid == (other as MyNodeID).netid;
        }

        public Variant serialize_to_variant()
        {
            Variant v0 = Serializer.int_to_variant(id);
            Variant v1 = Serializer.int_to_variant(netid);
            Variant vret = Serializer.tuple_to_variant(v0, v1);
            return vret;
        }
        public void deserialize_from_variant(Variant v) throws SerializerError
        {
            Variant v0;
            Variant v1;
            Serializer.variant_to_tuple(v, out v0, out v1);
            id = Serializer.variant_to_int(v0);
            netid = Serializer.variant_to_int(v1);
        }
    }

    public delegate long GetRTT(uint guid) throws GetRttError;
    public delegate void PreparePing(uint guid);
    public class Nic : Object, INeighborhoodNetworkInterface
    {
        public Nic(string dev,
                   string mac,
                   GetRTT get_usec_rtt,
                   PreparePing prepare_ping)
        {
            _dev = dev;
            _mac = mac;
            _get_usec_rtt = get_usec_rtt;
            _prepare_ping = prepare_ping;
        }

        private string _dev;
        private string _mac;
        private unowned GetRTT _get_usec_rtt;
        private unowned PreparePing _prepare_ping;

        /* Public interface INetworkInterface
         */

        public bool i_neighborhood_equals(INeighborhoodNetworkInterface other)
        {
            // This kind of equality test is ok because main.vala
            // is the only able to create an instance
            // of INetworkInterface and it won't create more than one
            // instance per device at start.
            return other == this;
        }

        public string i_neighborhood_dev
        {
            get {
                return _dev;
            }
        }
        public string i_neighborhood_mac
        {
            get {
                return _mac;
            }
        }
        public long i_neighborhood_get_usec_rtt(uint guid) throws GetRttError
        {
            return _get_usec_rtt(guid);
        }

        public void i_neighborhood_prepare_ping(uint guid)
        {
            _prepare_ping(guid);
        }
    }

    public class AddressManager : FakeAddressManager
    {
        public NeighborhoodManager neighborhood_manager;
        public override unowned INeighborhoodManager _neighborhood_manager_getter()
        {
            return neighborhood_manager;
        }
    }
    AddressManager? address_manager;

    public void udp_unicast_callback(CallerInfo caller,
                                      UDPPayload payload,
                                      out RPCDispatcher? rpcdispatcher,
                                      out uchar[] data,
                                      out Gee.List<string> devs_response)
    {
        UDPServer.ignore_unicast(caller, payload,
            out rpcdispatcher,
            out data,
            out devs_response);
        UnicastID? ucid = null;
        try {
            ucid = (UnicastID)ISerializable.deserialize(payload.ser);
        } catch (SerializerError e) {return;}
        INeighborhoodNetworkInterface? nic = null;
        try {
            nic = address_manager.neighborhood_manager
                .get_monitoring_interface_from_dev(caller.dev);
        } catch (RPCError e) {return;}
        if (address_manager.neighborhood_manager
                .is_unicast_for_me(ucid, nic))
        {
            rpcdispatcher = new AddressManagerDispatcher(address_manager);
            data = payload.data.serialize();
            devs_response = new ArrayList<string>();
            devs_response.add(caller.dev);
        }
    }

    public void udp_broadcast_callback(CallerInfo caller,
                                        UDPPayload payload,
                                        out Gee.List<RPCDispatcher> rpcdispatchers,
                                        out uchar[] data)
    {
        UDPServer.ignore_broadcast(caller, payload,
            out rpcdispatchers,
            out data);
        BroadcastID? bcid = null;
        try {
            bcid = (BroadcastID)ISerializable.deserialize(payload.ser);
        } catch (SerializerError e) {return;}
        rpcdispatchers = new ArrayList<RPCDispatcher>();
        rpcdispatchers.add(new AddressManagerDispatcher(address_manager));
        data = payload.data.serialize();
    }

    public void tcp_callback(CallerInfo caller,
                                          TCPRequest tcprequest,
                                          out RPCDispatcher? rpcdispatcher,
                                          out uchar[] data,
                                          out uchar[] response)
    {
        rpcdispatcher = null;
        data = null;
        response = null;
        rpcdispatcher = new AddressManagerDispatcher(address_manager);
        data = tcprequest.data.serialize();
    }

    int main(string[] args)
    {
        Time n = Time.local(time_t());
        print(@"$(n)\n");
        string iface = args[1];
        // generate my nodeID on network 1
        INeighborhoodNodeID id = new MyNodeID(1);
        // init tasklet
        assert(Tasklet.init());
        {
            // Initialize rpc library
            Serializer.init();
            // Register serializable types from model
            RpcNtk.init();
            // Register more serializable types
            typeof(MyNodeID).class_peek();

            // Handle UDP on iface
            string my_mac = get_mac(iface).up();
            UDPServer udpserver = new UDPServer(udp_unicast_callback, udp_broadcast_callback, iface);
            udpserver.listen();
            // Handle TCP
            TCPServer tcpserver = new TCPServer(tcp_callback);
            tcpserver.listen();

            Nic nic = new Nic(iface, my_mac,
                    /*long GetRTTSecondPart(uint guid)*/
                    (guid) => {
                        try
                        {
                            return udpserver.ping(guid);
                        }
                        catch (Tasklets.ChannelError e)
                        {
                            throw new GetRttError.GENERIC("Not reached");
                        }
                    },
                    /*void PreparePing(uint guid)*/
                    (guid) => {
                        udpserver.expect_ping(guid);
                    }
            );

            // create manager
            address_manager = new AddressManager();
            // create module neighborhood
            address_manager.neighborhood_manager = new NeighborhoodManager(id, 12, new MyStubFactory(), new MyIPRouteManager());
            // connect signals
            address_manager.neighborhood_manager.network_collision.connect(
                (o) => {
                    MyNodeID other = o as MyNodeID;
                    if (other == null) return;
                    Time m = Time.local(time_t());
                    print(@"$(m) ");
                    print(@"Collision with netid $(other.netid)\n");
                }
            );
            address_manager.neighborhood_manager.arc_added.connect(
                (arc) => {
                    Time m = Time.local(time_t());
                    print(@"$(m) ");
                    print(@"Added arc with $(arc.i_neighborhood_mac), RTT $(arc.i_neighborhood_cost as RTT)\n");
                }
            );
            address_manager.neighborhood_manager.arc_removed.connect(
                (arc) => {
                    Time m = Time.local(time_t());
                    print(@"$(m) ");
                    print(@"Removed arc with $(arc.i_neighborhood_mac)\n");
                }
            );
            address_manager.neighborhood_manager.arc_changed.connect(
                (arc) => {
                    Time m = Time.local(time_t());
                    print(@"$(m) ");
                    print(@"Changed arc with $(arc.i_neighborhood_mac), RTT $(arc.i_neighborhood_cost as RTT)\n");
                }
            );
            // run monitor
            address_manager.neighborhood_manager.start_monitor(nic);
            print(@"Monitoring iface $(nic.i_neighborhood_dev), MAC $(nic.i_neighborhood_mac)\n");

            // register handlers for SIGINT and SIGTERM to exit
            Posix.signal(Posix.SIGINT, safe_exit);
            Posix.signal(Posix.SIGTERM, safe_exit);
            // Main loop
            while (true)
            {
                Tasklet.nap(0, 100000);
                if (do_me_exit) break;
            }
            address_manager.neighborhood_manager.stop_monitor_all();
            // here address_manager.neighborhood_manager should be destroyed but it doesnt.
            address_manager.neighborhood_manager = null;
            address_manager = null;

            udpserver.stop();
        }
        Tasklet.nap(0, 100000);
        assert(Tasklet.kill());
        return 0;
    }

    bool do_me_exit = false;
    void safe_exit(int sig)
    {
        // We got here because of a signal. Quick processing.
        do_me_exit = true;
    }
}

