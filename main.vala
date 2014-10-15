using Tasklets;
using Gee;
using zcd;

namespace Netsukuku
{
    public void log_debug(string msg)     {print(msg);}
    public void log_trace(string msg)     {print(msg);}
    public void log_verbose(string msg)     {print(msg);}
    public void log_info(string msg)     {print(msg);}
    public void log_notice(string msg)     {print(msg);}
    public void log_warn(string msg)     {print(msg);}
    public void log_error(string msg)     {print(msg);}
    public void log_critical(string msg)     {print(msg);}

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
            /*PrepareForAcknowledgements*/
            () => {
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
        );
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
        // TODO prepare a list of expected receivers (in form of IArc).
        // Wait for the timeout and receive from the channel the list of ACKs.
        Value v = ch.recv();
        // TODO prepare a list of 'missing' and foreach launch a tasklet.
    }

    public class MyNodeID : Object, ISerializable, INodeID
    {
        private int id;
        private int netid;
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

    void main()
    {
        // generate my nodeID
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

            // Handle UDP eth0
            UDPServer udpserver_eth0 = new UDPServer(udp_unicast_callback, udp_broadcast_callback, "eth0");
            udpserver_eth0.listen();
            Nic nic_eth0 = new Nic("eth0", "b8:70:f4:9f:78:9b",
                    /*long GetRTTSecondPart(uint guid)*/
                    (guid) => {
                        try
                        {
                            return udpserver_eth0.ping(guid);
                        }
                        catch (Tasklets.ChannelError e)
                        {
                            throw new GetRttError.GENERIC("Not reached");
                        }
                    },
                    /*void PreparePing(uint guid)*/
                    (guid) => {
                        udpserver_eth0.expect_ping(guid);
                    }
            );

            // create manager
            address_manager = new AddressManager();
            address_manager.neighborhood_manager = new NeighborhoodManager(id, 12, get_unicast, get_broadcast);
            // run eth0
            address_manager.neighborhood_manager.start_monitor(nic_eth0);
            Tasklet.nap(5, 0);
            // here address_manager.neighborhood_manager will be destroyed
            address_manager = null;

            udpserver_eth0.stop();
        }
        Tasklet.nap(1, 0);
        assert(Tasklet.kill());
    }
}

