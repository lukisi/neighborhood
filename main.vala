using Tasklets;
using Gee;
using zcd;

namespace Netsukuku
{
    public void log_debug(string msg)     {print(msg+"\n");}
    public void log_trace(string msg)     {print(msg+"\n");}
    public void log_verbose(string msg)     {print(msg+"\n");}
    public void log_info(string msg)     {print(msg+"\n");}
    public void log_notice(string msg)     {print(msg+"\n");}
    public void log_warn(string msg)     {print(msg+"\n");}
    public void log_error(string msg)     {print(msg+"\n");}
    public void log_critical(string msg)     {print(msg+"\n");}

    /* Get a client to call a unicast remote method
     */
    IAddressManagerRootDispatcher
    get_unicast(UnicastID ucid, INetworkInterface nic, bool wait_reply)
    {
        Nic _nic = (Nic)nic;
        var uc = new AddressManagerNeighbourClient(ucid, {_nic.dev}, null, wait_reply);
        return uc;
    }

    class DelegateContainer : Object
    {
        public unowned MissingAckFrom missing;
    }

    class MyAcknowledgementsCommunicator : Object, IAcknowledgementsCommunicator
    {
        public BroadcastID bcid;
        public Gee.Collection<INetworkInterface> nics;
        public unowned MissingAckFrom missing;

        public MyAcknowledgementsCommunicator(BroadcastID bcid,
                  Gee.Collection<INetworkInterface> nics,
                  MissingAckFrom missing)
        {
            this.bcid = bcid;
            this.nics = nics;
            this.missing = missing;
        }

        public Channel prepare()
        {
            Channel ch = new Channel();
            DelegateContainer cnt = new DelegateContainer();
            cnt.missing = missing;
            Tasklet.tasklet_callback(
                (t_bcid, t_nics, t_ch, t_cnt) => {
                    gather_acks((BroadcastID)t_bcid,
                        (Gee.Collection<INetworkInterface>)t_nics,
                        (Channel)t_ch,
                        ((DelegateContainer)t_cnt).missing);
                },
                bcid, nics, ch, cnt
            );
            return ch;
        }
    }

    /* Get a client to call a broadcast remote method
     */
    IAddressManagerRootDispatcher
    get_broadcast(BroadcastID bcid,
                  Gee.Collection<INetworkInterface> nics,
                  MissingAckFrom missing) throws RPCError
    {
        assert(! nics.is_empty);
        var devs = new ArrayList<string>();
        foreach (INetworkInterface nic in nics)
        {
            Nic _nic = (Nic)nic;
            devs.add(_nic.dev);
        }
        var bc = new AddressManagerBroadcastClient(bcid, devs.to_array(),
            new MyAcknowledgementsCommunicator(bcid, nics, missing));
        return bc;
    }

    /* Gather ACKs from expected receivers of a broadcast message
     */
    void
    gather_acks(BroadcastID bcid,
                Gee.Collection<INetworkInterface> nics,
                Channel ch,
                MissingAckFrom missing)
    {
        // prepare a list of expected receivers (in form of IArc).
        var lst_expected = new ArrayList<IArc>();
        var cur_arcs = address_manager.neighborhood_manager.current_arcs();
        foreach (IArc arc in cur_arcs)
        {
            // test arc against bcid (e.g. ignore_neighbour)
            if (arc.neighbour_id.equals(bcid.ignore_nodeid as INodeID)) continue;
            // test arc against nics.
            bool is_in_nics = false;
            foreach (INetworkInterface nic in nics)
            {
                if (arc.is_nic(nic))
                {
                    is_in_nics = true;
                    break;
                }
            }
            if (! is_in_nics) continue;
            // This should receive
            lst_expected.add(arc);
        }
        // Wait for the timeout and receive from the channel the list of ACKs.
        Value v = ch.recv();
        Gee.List<string> responding_macs = (Gee.List<string>)v;
        // prepare a list of missed arcs.
        var lst_missed = new ArrayList<IArc>();
        foreach (IArc expected in lst_expected)
        {
            bool has_responded = false;
            foreach (string responding_mac in responding_macs)
            {
                if (expected.mac == responding_mac)
                {
                    has_responded = true;
                    break;
                }
            }
            if (! has_responded) lst_missed.add(expected);
        }
        // foreach missed arc launch in a tasklet
        // the 'missing' callback.
        foreach (IArc missed in lst_missed)
        {
            Tasklet.tasklet_callback(
                (t_missed) => {
                    missing((IArc)t_missed);
                },
                missed
            );
        }
    }

    public class MyNodeID : Object, ISerializable, INodeID
    {
        public int id {get; private set;}
        public int netid {get; private set;}
        public MyNodeID(int netid)
        {
            id = Random.int_range(0, 10000);
            this.netid = netid;
        }

        public bool equals(INodeID other)
        {
            if (!(other is MyNodeID)) return false;
            return id == (other as MyNodeID).id;
        }

        public bool is_on_same_network(INodeID other)
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
    public class Nic : Object, INetworkInterface
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

        public bool equals(INetworkInterface other)
        {
            // This kind of equality test is ok because main.vala
            // is the only able to create an instance
            // of INetworkInterface and it won't create more than one
            // instance per device at start.
            return other == this;
        }

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
        public long get_usec_rtt(uint guid) throws GetRttError
        {
            return _get_usec_rtt(guid);
        }

        public void prepare_ping(uint guid)
        {
            _prepare_ping(guid);
        }
    }

    public class AddressManager : Object, IAddressManagerRootDispatcher
    {
        public NeighborhoodManager neighborhood_manager;
		public unowned INeighborhoodManager _neighborhood_manager_getter()
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
        INetworkInterface? nic = null;
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

    int main(string[] args)
    {
        string iface = args[1];
        // generate my nodeID on network 1
        INodeID id = new MyNodeID(1);
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
            address_manager.neighborhood_manager = new NeighborhoodManager(id, 12, get_unicast, get_broadcast);
            // connect signals
            address_manager.neighborhood_manager.network_collision.connect(
                (o) => {
                    MyNodeID other = o as MyNodeID;
                    if (other == null) return;
                    print(@"Collision with netid $(other.netid)\n");
                }
            );
            address_manager.neighborhood_manager.arc_added.connect(
                (arc) => {
                    print(@"Added arc with $(arc.mac)\n");
                }
            );
            address_manager.neighborhood_manager.arc_removed.connect(
                (arc) => {
                    print(@"Removed arc with $(arc.mac)\n");
                }
            );
            address_manager.neighborhood_manager.arc_changed.connect(
                (arc) => {
                    print(@"Changed arc with $(arc.mac)\n");
                }
            );
            // run monitor
            address_manager.neighborhood_manager.start_monitor(nic);

            // register handlers for SIGINT and SIGTERM to exit
            Posix.signal(Posix.SIGINT, safe_exit);
            Posix.signal(Posix.SIGTERM, safe_exit);
            // Main loop
            while (true)
            {
                Tasklet.nap(0, 100000);
                if (do_me_exit) break;
            }
            // here address_manager.neighborhood_manager will be destroyed
            address_manager = null;

            udpserver.stop();
        }
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

