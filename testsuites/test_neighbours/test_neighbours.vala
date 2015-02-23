/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2014-2015 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

using Tasklets;
using Gee;
using zcd;
using Netsukuku;

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
}

bool init_done = false;
ArrayList<SimulatorCollisionDomain> collision_domains;
ArrayList<SimulatorNode> nodes;
void init()
{
    if (!init_done)
    {
        collision_domains = new ArrayList<SimulatorCollisionDomain>();
        nodes = new ArrayList<SimulatorNode>();
        init_done = true;
    }
}

public class SimulatorCollisionDomain : Object
{
    public bool active;
    public long delay_min;
    public long delay_max;
    public ArrayList<uint> ping_guids;
    public SimulatorCollisionDomain()
    {
        collision_domains.add(this);
        active = true;
        delay_min = 9700;
        delay_max = 10200;
        ping_guids = new ArrayList<uint>();
    }
}

public class SimulatorNode : Object
{
    public HashMap<string, SimulatorDevice> devices;
    public MyNodeID id;
    public SimulatorNode(int netid)
    {
        nodes.add(this);
        devices = new HashMap<string, SimulatorDevice>();
        id = new MyNodeID(netid);
    }

    public void print_signals(NeighborhoodManager mgr)
    {
        mgr.network_collision.connect(
            (o) => {
                MyNodeID other = o as MyNodeID;
                if (other == null) return;
                print(@"Manager for node $(id.id) signals: ");
                print(@"Collision with netid $(other.netid)\n");
            }
        );
        mgr.arc_added.connect(
            (arc) => {
                print(@"Manager for node $(id.id) signals: ");
                print(@"Added arc with $(arc.i_neighborhood_mac), RTT $(arc.i_neighborhood_cost)\n");
            }
        );
        mgr.arc_removed.connect(
            (arc) => {
                print(@"Manager for node $(id.id) signals: ");
                print(@"Removed arc with $(arc.i_neighborhood_mac)\n");
            }
        );
        mgr.arc_changed.connect(
            (arc) => {
                print(@"Manager for node $(id.id) signals: ");
                print(@"Changed arc with $(arc.i_neighborhood_mac), RTT $(arc.i_neighborhood_cost)\n");
            }
        );
    }

    public class SimulatorDevice : Object
    {
        public bool working;
        public SimulatorCollisionDomain? collision_domain;
        public string mac;
        public ArrayList<string> addresses;
        public ArrayList<string> neighbors;
        public NeighborhoodManager? mgr;
        public SimulatorDevice(SimulatorCollisionDomain? collision_domain)
        {
            this.collision_domain = collision_domain;
            working = true;
            mgr = null;
            addresses = new ArrayList<string>();
            neighbors = new ArrayList<string>();
            string letters = "0123456789ABCDEF";
            mac = "";
            for (int i = 0; i < 6; i++)
            {
                if (i > 0) mac += ":";
                for (int j = 0; j < 2; j++)
                {
                    mac += letters.substring(Random.int_range(0, letters.length), 1);
                }
            }
        }
    }
}

int main()
{
    init();
    // init tasklet
    assert(Tasklet.init());
    // Initialize rpc library
    Serializer.init();
    // Register serializable types from model
    RpcNtk.init();
    // Register more serializable types
    typeof(MyNodeID).class_peek();
    // Initialize module
    NeighborhoodManager.init();

    var col_a = new SimulatorCollisionDomain();
    var col_b = new SimulatorCollisionDomain();
    var node_a = new SimulatorNode(1);
    node_a.devices["eth0"] = new SimulatorNode.SimulatorDevice(col_a);
    node_a.devices["eth1"] = new SimulatorNode.SimulatorDevice(col_b);
    node_a.devices["eth2"] = new SimulatorNode.SimulatorDevice(null);
    var node_b = new SimulatorNode(1);
    node_b.devices["eth0"] = new SimulatorNode.SimulatorDevice(col_a);
    var node_c = new SimulatorNode(1);
    node_c.devices["eth0"] = new SimulatorNode.SimulatorDevice(col_b);

    var node_a_mgr = new NeighborhoodManager(node_a.id, 12, new FakeStubFactory(node_a), new FakeIPRouteManager(node_a));
    node_a.print_signals(node_a_mgr);
    node_a_mgr.start_monitor(new FakeNic(node_a.devices["eth0"]));
        node_a.devices["eth0"].mgr = node_a_mgr;
        ms_wait(10);
    node_a_mgr.start_monitor(new FakeNic(node_a.devices["eth1"]));
        node_a.devices["eth1"].mgr = node_a_mgr;
        ms_wait(10);
    node_a_mgr.start_monitor(new FakeNic(node_a.devices["eth2"]));
        node_a.devices["eth2"].mgr = node_a_mgr;
        ms_wait(10);
    ms_wait(100);
    var node_b_mgr = new NeighborhoodManager(node_b.id, 12, new FakeStubFactory(node_b), new FakeIPRouteManager(node_b));
    node_b.print_signals(node_b_mgr);
    node_b_mgr.start_monitor(new FakeNic(node_b.devices["eth0"]));
        node_b.devices["eth0"].mgr = node_b_mgr;
        ms_wait(10);

    ms_wait(2000);

    node_a_mgr.stop_monitor_all();
    ms_wait(100);
    node_b_mgr.stop_monitor_all();
    ms_wait(100);

    assert(Tasklet.kill());
    return 0;
}

public class MyNodeID : Object, ISerializable, INeighborhoodNodeID
{
    public int id {get; private set;}
    public int netid {get; private set;}
    public MyNodeID(int netid)
    {
        id = Random.int_range(0, int.MAX);
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

public class FakeNic : Object, INeighborhoodNetworkInterface
{
    public SimulatorNode.SimulatorDevice device;
    public FakeNic(SimulatorNode.SimulatorDevice device)
    {
        this.device = device;
        _mac = device.mac;
        foreach (SimulatorNode node in nodes)
            foreach (string k in node.devices.keys)
                if (node.devices[k] == device) _dev = k;
    }

    /* Public interface INeighborhoodNetworkInterface
     */

    private string _dev;
    public string i_neighborhood_dev
    {
        get {
            return _dev;
        }
    }

    private string _mac;
    public string i_neighborhood_mac
    {
        get {
            return _mac;
        }
    }

    public long i_neighborhood_get_usec_rtt(uint guid) throws NeighborhoodGetRttError
    {
        print(@"Device $(_mac) pinging with guid $(guid).\n");
        if (device.collision_domain == null) throw new NeighborhoodGetRttError.GENERIC("No carrier");
        SimulatorCollisionDomain dom = device.collision_domain;
        if (guid in dom.ping_guids)
        {
            dom.ping_guids.remove(guid);
            return Random.int_range((int32)dom.delay_min, (int32)dom.delay_max);
        }
        throw new NeighborhoodGetRttError.GENERIC("No recv");
    }

    public void i_neighborhood_prepare_ping(uint guid)
    {
        print(@"Device $(_mac) willing to answer pings with guid $(guid).\n");
        if (device.collision_domain == null) return;
        device.collision_domain.ping_guids.add(guid);
    }
}

public class FakeBroadcastClient : FakeAddressManager
{
    public BroadcastID bcid;
    public Gee.Collection<string> devs;
    public IAcknowledgementsCommunicator? ack_com;
    public SimulatorNode node;

    public FakeBroadcastClient(
                        SimulatorNode node,
                        BroadcastID bcid,
                        Gee.Collection<string> devs,
                        IAcknowledgementsCommunicator? ack_com)
    {
        this.node = node;
        this.bcid = bcid;
        this.devs = devs;
        this.ack_com = ack_com;
    }

    public override void expect_ping (int guid, zcd.CallerInfo? _rpc_caller = null)
    {
        // never called in broadcast
        assert_not_reached();
    }

    public override void remove_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
    {
        // never called in broadcast
        assert_not_reached();
    }

    public override void request_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
    {
        // never called in broadcast
        assert_not_reached();
    }

	private class BroadcastCallHereIAm : Object
	{
        public BroadcastID bcid;
        public Gee.List<string>? responding_macs;
        public SimulatorNode caller_node;
        public long delay;
        public INeighborhoodNodeID arg_my_id;
        public string arg_mac;
        public string arg_nic_addr;
        public string caller_ip;
        public string callee_dev;
        public SimulatorNode callee_node;
	}
	public override void here_i_am (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
	{
	    print(@"sending to broadcast 'here_i_am' from node $(node.id.id) through devs:\n");
	    foreach (string dev in devs) print(@"        $(dev)\n");
	    if (bcid.ignore_nodeid != null) print(@"        ignoring node $((bcid.ignore_nodeid as MyNodeID).id)\n");
	    print(@"        saying:\n");
	    assert(my_id is MyNodeID);
	    MyNodeID _my_id = my_id as MyNodeID;
	    print(@"           my id is $(_my_id.id)\n");
	    print(@"           my netid is $(_my_id.netid)\n");
	    print(@"           my mac is $(mac)\n");
	    print(@"           my nic_addr is $(nic_addr)\n");
	    Gee.List<string>? responding_macs = null;
	    if (ack_com != null)
	    {
	        Channel ack_comm_ch = ack_com.prepare();
	        responding_macs = new ArrayList<string>();
            Tasklet.tasklet_callback(
                (_ack_comm_ch, _responding_macs) => {
                    Channel t_ack_comm_ch = (Channel)_ack_comm_ch;
                    Gee.List<string> t_responding_macs = (Gee.List<string>)_responding_macs;
                    ms_wait(3000);
                    t_ack_comm_ch.send_async(t_responding_macs);
                },
                ack_comm_ch,
                responding_macs);
            // end tasklet body
	    }
	    foreach (string dev in devs) if (node.devices[dev].working)
	    {
	        SimulatorCollisionDomain? dom = node.devices[dev].collision_domain;
	        if (dom != null && dom.active)
    	    {
	            foreach (SimulatorNode other_node in nodes) if (other_node != node)
	            {
	                foreach (string callee_dev in other_node.devices.keys)
	                {
	                    SimulatorNode.SimulatorDevice devc = other_node.devices[callee_dev];
	                    if (devc.working)
	                    {
	                        if (devc.collision_domain == dom)
	                        {
	                            long delay = Random.int_range((int32)dom.delay_min, (int32)dom.delay_max);
	                            BroadcastCallHereIAm call = new BroadcastCallHereIAm();
	                            call.bcid = bcid;
	                            call.responding_macs = responding_macs;
	                            call.caller_node = node;
	                            call.delay = delay;
	                            call.arg_my_id = my_id;
	                            call.arg_mac = mac;
	                            call.arg_nic_addr = nic_addr;
	                            call.caller_ip = "";
	                            call.callee_dev = callee_dev;
	                            call.callee_node = other_node;
	                            Tasklet.tasklet_callback(
	                                (_call) => {
	                                    BroadcastCallHereIAm t_call = (BroadcastCallHereIAm)_call;
	                                    ms_wait(t_call.delay/1000);
	                                    SimulatorNode.SimulatorDevice t_devc =
                                            t_call.callee_node.devices[t_call.callee_dev];
	                                    if ((! t_devc.working) || t_devc.mgr == null) return;
	                                    if (! t_devc.mgr.is_broadcast_for_me(t_call.bcid, t_call.callee_dev)) return;
                                        if (t_call.responding_macs != null)
                                            t_call.responding_macs.add(t_devc.mac);
	                                    try {
	                                        MyNodeID t_my_id = (MyNodeID)ISerializable.deserialize(
	                                            ((MyNodeID)t_call.arg_my_id).serialize());
	                                        t_devc.mgr.here_i_am(t_my_id,
	                                                             t_call.arg_mac,
	                                                             t_call.arg_nic_addr,
	                                                             new CallerInfo(t_call.caller_ip, null, t_call.callee_dev));
	                                    } catch (SerializerError e) {}
	                                },
	                                call);
	                            // end tasklet body
	                        }
	                    }
	                }
	            }
	        }
	    }
	}
}

public class FakeUnicastClient : FakeAddressManager
{
    public UnicastID ucid;
    public string dev;
    public bool wait_reply;
    public SimulatorNode node;

    public FakeUnicastClient(
                        SimulatorNode node,
                        UnicastID ucid, string dev, bool wait_reply)
    {
        this.node = node;
        this.ucid = ucid;
        this.dev = dev;
        this.wait_reply = wait_reply;
    }

    public override void expect_ping (int guid, zcd.CallerInfo? _rpc_caller = null)
	{
        // never called in unicast
        assert_not_reached();
	}

	private class UnicastCallRemoveArc : Object
	{
        public UnicastID ucid;
        public Channel? reply_ch;
        public SimulatorNode caller_node;
        public long delay;
        public INeighborhoodNodeID arg_my_id;
        public string arg_mac;
        public string arg_nic_addr;
        public string caller_ip;
        public string callee_dev;
        public SimulatorNode callee_node;
	}
    public override void remove_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
	{
	    print(@"sending to unicast 'remove_arc' from node $(node.id.id) through dev $(dev),\n");
	    if (wait_reply) print(@"        waiting reply,\n");
	    print(@"        to node $((ucid.nodeid as MyNodeID).id).\n");
	    print(@"        Saying:\n");
	    assert(my_id is MyNodeID);
	    MyNodeID _my_id = my_id as MyNodeID;
	    print(@"           my id is $(_my_id.id)\n");
	    print(@"           my netid is $(_my_id.netid)\n");
	    print(@"           my mac is $(mac)\n");
	    print(@"           my nic_addr is $(nic_addr)\n");
	    if (wait_reply && ! node.devices[dev].working) throw new RPCError.GENERIC("my device not working.");
	    Channel? reply_ch = null;
	    if (wait_reply) reply_ch = new Channel();
	    if (node.devices[dev].working)
	    {
	        SimulatorCollisionDomain? dom = node.devices[dev].collision_domain;
	        if (dom != null && dom.active)
    	    {
	            foreach (SimulatorNode other_node in nodes) if (other_node != node)
	            {
	                foreach (string callee_dev in other_node.devices.keys)
	                {
	                    SimulatorNode.SimulatorDevice devc = other_node.devices[callee_dev];
	                    if (devc.working)
	                    {
	                        if (devc.collision_domain == dom)
	                        {
	                            long delay = Random.int_range((int32)dom.delay_min, (int32)dom.delay_max);
	                            UnicastCallRemoveArc call = new UnicastCallRemoveArc();
	                            call.ucid = ucid;
	                            call.reply_ch = reply_ch;
	                            call.caller_node = node;
	                            call.delay = delay;
	                            call.arg_my_id = my_id;
	                            call.arg_mac = mac;
	                            call.arg_nic_addr = nic_addr;
	                            call.caller_ip = "";
	                            call.callee_dev = callee_dev;
	                            call.callee_node = other_node;
	                            Tasklet.tasklet_callback(
	                                (_call) => {
	                                    UnicastCallRemoveArc t_call = (UnicastCallRemoveArc)_call;
	                                    ms_wait(t_call.delay/1000);
	                                    SimulatorNode.SimulatorDevice t_devc =
                                            t_call.callee_node.devices[t_call.callee_dev];
	                                    if ((! t_devc.working) || t_devc.mgr == null) return;
	                                    if (! t_devc.mgr.is_unicast_for_me(t_call.ucid, t_call.callee_dev)) return;
	                                    try {
	                                        MyNodeID t_my_id = (MyNodeID)ISerializable.deserialize(
	                                            ((MyNodeID)t_call.arg_my_id).serialize());
                                            t_devc.mgr.remove_arc(t_my_id,
                                                                   t_call.arg_mac,
                                                                   t_call.arg_nic_addr,
                                                                   new CallerInfo(t_call.caller_ip, null, t_call.callee_dev));
                                            if (t_call.reply_ch != null) t_call.reply_ch.send(new SerializableNone());
	                                    } catch (SerializerError e) {}
	                                },
	                                call);
	                            // end tasklet body
	                        }
	                    }
	                }
	            }
	        }
	    }
	    if (wait_reply)
	    {
	        try {
	            ISerializable resp = (ISerializable)reply_ch.recv_with_timeout(2000);
                return; // ok
	        } catch (ChannelError e) {throw new RPCError.GENERIC("no answer");}
	    }
	}

	private class UnicastCallRequestArc : Object
	{
        public UnicastID ucid;
        public Channel? reply_ch;
        public SimulatorNode caller_node;
        public long delay;
        public INeighborhoodNodeID arg_my_id;
        public string arg_mac;
        public string arg_nic_addr;
        public string caller_ip;
        public string callee_dev;
        public SimulatorNode callee_node;
	}
    public override void request_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
                throws NeighborhoodRequestArcError, RPCError
	{
	    print(@"sending to unicast 'request_arc' from node $(node.id.id) through dev $(dev),\n");
	    if (wait_reply) print(@"        waiting reply,\n");
	    print(@"        to node $((ucid.nodeid as MyNodeID).id).\n");
	    print(@"        Saying:\n");
	    assert(my_id is MyNodeID);
	    MyNodeID _my_id = my_id as MyNodeID;
	    print(@"           my id is $(_my_id.id)\n");
	    print(@"           my netid is $(_my_id.netid)\n");
	    print(@"           my mac is $(mac)\n");
	    print(@"           my nic_addr is $(nic_addr)\n");
	    if (wait_reply && ! node.devices[dev].working) throw new RPCError.GENERIC("my device not working.");
	    Channel? reply_ch = null;
	    if (wait_reply) reply_ch = new Channel();
	    if (node.devices[dev].working)
	    {
	        SimulatorCollisionDomain? dom = node.devices[dev].collision_domain;
	        if (dom != null && dom.active)
    	    {
	            foreach (SimulatorNode other_node in nodes) if (other_node != node)
	            {
	                foreach (string callee_dev in other_node.devices.keys)
	                {
	                    SimulatorNode.SimulatorDevice devc = other_node.devices[callee_dev];
	                    if (devc.working)
	                    {
	                        if (devc.collision_domain == dom)
	                        {
	                            long delay = Random.int_range((int32)dom.delay_min, (int32)dom.delay_max);
	                            UnicastCallRequestArc call = new UnicastCallRequestArc();
	                            call.ucid = ucid;
	                            call.reply_ch = reply_ch;
	                            call.caller_node = node;
	                            call.delay = delay;
	                            call.arg_my_id = my_id;
	                            call.arg_mac = mac;
	                            call.arg_nic_addr = nic_addr;
	                            call.caller_ip = "";
	                            call.callee_dev = callee_dev;
	                            call.callee_node = other_node;
	                            Tasklet.tasklet_callback(
	                                (_call) => {
	                                    UnicastCallRequestArc t_call = (UnicastCallRequestArc)_call;
	                                    ms_wait(t_call.delay/1000);
	                                    SimulatorNode.SimulatorDevice t_devc =
                                            t_call.callee_node.devices[t_call.callee_dev];
	                                    if ((! t_devc.working) || t_devc.mgr == null) return;
	                                    if (! t_devc.mgr.is_unicast_for_me(t_call.ucid, t_call.callee_dev)) return;
	                                    try {
	                                        MyNodeID t_my_id = (MyNodeID)ISerializable.deserialize(
	                                            ((MyNodeID)t_call.arg_my_id).serialize());
	                                        try {
	                                            t_devc.mgr.request_arc(t_my_id,
	                                                                   t_call.arg_mac,
	                                                                   t_call.arg_nic_addr,
	                                                                   new CallerInfo(t_call.caller_ip, null, t_call.callee_dev));
	                                            if (t_call.reply_ch != null) t_call.reply_ch.send(new SerializableNone());
	                                        } catch (NeighborhoodRequestArcError e) {
	                                            if (t_call.reply_ch != null)
	                                            {
                                                    RemotableException re = new RemotableException();
                                                    re.message = e.message;
                                                    re.domain = "NeighborhoodRequestArcError";
                                                    if (e is NeighborhoodRequestArcError.NOT_SAME_NETWORK)
                                                        re.code = "NOT_SAME_NETWORK";
                                                    if (e is NeighborhoodRequestArcError.TOO_MANY_ARCS)
                                                        re.code = "TOO_MANY_ARCS";
                                                    if (e is NeighborhoodRequestArcError.TWO_ARCS_ON_COLLISION_DOMAIN)
                                                        re.code = "TWO_ARCS_ON_COLLISION_DOMAIN";
                                                    if (e is NeighborhoodRequestArcError.GENERIC)
                                                        re.code = "GENERIC";
                                                    t_call.reply_ch.send(re);
	                                            }
	                                        }
	                                    } catch (SerializerError e) {}
	                                },
	                                call);
	                            // end tasklet body
	                        }
	                    }
	                }
	            }
	        }
	    }
	    if (wait_reply)
	    {
	        try {
	            ISerializable resp = (ISerializable)reply_ch.recv_with_timeout(2000);
                if (resp.get_type().is_a(typeof(RemotableException)))
                {
                    RemotableException e = (RemotableException)resp;
                    if (e.domain == "NeighborhoodRequestArcError")
                    {
                        if (e.code == "NOT_SAME_NETWORK")
                            throw new NeighborhoodRequestArcError.NOT_SAME_NETWORK(e.message);
                        if (e.code == "TOO_MANY_ARCS")
                            throw new NeighborhoodRequestArcError.TOO_MANY_ARCS(e.message);
                        if (e.code == "TWO_ARCS_ON_COLLISION_DOMAIN")
                            throw new NeighborhoodRequestArcError.TWO_ARCS_ON_COLLISION_DOMAIN(e.message);
                        if (e.code == "GENERIC")
                            throw new NeighborhoodRequestArcError.GENERIC(e.message);
                    }
                    assert_not_reached();
                }
                return; // ok
	        } catch (ChannelError e) {throw new RPCError.GENERIC("no answer");}
	    }
	}

	public override void here_i_am (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
	{
        // never called in unicast
        assert_not_reached();
	}
}

public class FakeTCPClient : FakeAddressManager
{
    public string dest;
    public bool wait_reply;
    public SimulatorNode node;

    public FakeTCPClient(
                        SimulatorNode node,
                        string dest, bool wait_reply)
    {
        this.node = node;
        this.dest = dest;
        this.wait_reply = wait_reply;
    }

    public override void expect_ping (int guid, zcd.CallerInfo? _rpc_caller = null)
                throws NeighborhoodUnmanagedDeviceError, RPCError
	{
	    print(@"sending to $(dest) 'expect_ping($(guid))' from node $(node.id.id).\n");
	    bool found = false;
	    SimulatorNode? found_node = null;
	    SimulatorCollisionDomain? found_dom = null;
	    SimulatorNode.SimulatorDevice? found_devc = null;
	    SimulatorNode.SimulatorDevice? found_my_devc = null;
	    foreach (SimulatorNode.SimulatorDevice devc in node.devices.values) if (dest in devc.neighbors)
	    {
	        if (devc.working)
	        {
	            SimulatorCollisionDomain? dom = devc.collision_domain;
	            if (dom != null && dom.active)
        	    {
	                foreach (SimulatorNode other_node in nodes) if (other_node != node)
	                {
	                    foreach (string callee_dev in other_node.devices.keys)
	                    {
	                        SimulatorNode.SimulatorDevice other_devc = other_node.devices[callee_dev];
	                        if (other_devc.working)
	                        {
	                            if (other_devc.collision_domain == dom)
	                            {
	                                if (dest in other_devc.addresses)
	                                {
	                                    if (found) throw new RPCError.GENERIC("conflicting IP");
	                                    found = true;
	                                    found_node = other_node;
	                                    found_dom = dom;
	                                    found_my_devc = devc;
	                                    found_devc = other_devc;
	                                }
	                            }
	                        }
	                    }
	                }
	            }
	        }
	    }
	    if (found)
	    {
            long delay = Random.int_range((int32)found_dom.delay_min, (int32)found_dom.delay_max);
            ms_wait(delay/1000);
            if (found_devc.mgr == null) throw new RPCError.GENERIC("no connect");
            if (found_my_devc.addresses.is_empty) throw new RPCError.GENERIC("no connect");
            found_devc.mgr.expect_ping(guid, new CallerInfo(found_my_devc.addresses[0], dest, null));
        }
        else throw new RPCError.GENERIC("no connect");
	}

    public override void remove_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
	{
        // never called in tcp
        assert_not_reached();
	}

    public override void request_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
                throws NeighborhoodRequestArcError, RPCError
	{
        // never called in tcp
        assert_not_reached();
	}

	public override void here_i_am (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
	{
        // never called in tcp
        assert_not_reached();
	}
}

public class FakeIPRouteManager : Object, INeighborhoodIPRouteManager
{
    public SimulatorNode node;
    public FakeIPRouteManager(SimulatorNode node)
    {
        this.node = node;
    }

    public void i_neighborhood_add_address(
                        string my_addr,
                        string my_dev
                    )
    {
        print(@"adding address $(my_addr) to device $(my_dev) of node $(node.id.id).\n");
        assert(my_dev in node.devices.keys);
        SimulatorNode.SimulatorDevice dev = node.devices[my_dev];
        assert(! (my_addr in dev.addresses));
        dev.addresses.add(my_addr);
    }

    public void i_neighborhood_add_neighbor(
                        string my_addr,
                        string my_dev,
                        string neighbor_addr
                    )
    {
        print(@"adding neighbor $(neighbor_addr) reachable through $(my_dev) which has $(my_addr) of node $(node.id.id).\n");
        assert(my_dev in node.devices.keys);
        SimulatorNode.SimulatorDevice dev = node.devices[my_dev];
        assert(my_addr in dev.addresses);
        assert(! (neighbor_addr in dev.neighbors));
        dev.neighbors.add(neighbor_addr);
    }

    public void i_neighborhood_remove_neighbor(
                        string my_addr,
                        string my_dev,
                        string neighbor_addr
                    )
    {
        print(@"removing neighbor $(neighbor_addr) reachable through $(my_dev) which has $(my_addr) of node $(node.id.id).\n");
        assert(my_dev in node.devices.keys);
        SimulatorNode.SimulatorDevice dev = node.devices[my_dev];
        assert(my_addr in dev.addresses);
        assert(neighbor_addr in dev.neighbors);
        dev.neighbors.remove(neighbor_addr);
    }

    public void i_neighborhood_remove_address(
                        string my_addr,
                        string my_dev
                    )
    {
        print(@"removing address $(my_addr) from device $(my_dev) of node $(node.id.id).\n");
        assert(my_dev in node.devices.keys);
        SimulatorNode.SimulatorDevice dev = node.devices[my_dev];
        assert(my_addr in dev.addresses);
        dev.addresses.remove(my_addr);
    }
}

public class FakeStubFactory: Object, INeighborhoodStubFactory
{
    public SimulatorNode node;
    public FakeStubFactory(SimulatorNode node)
    {
        this.node = node;
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_broadcast(
                        BroadcastID bcid,
                        Gee.Collection<string> devs,
                        IAcknowledgementsCommunicator? ack_com
                    )
    {
        return new FakeBroadcastClient(node, bcid, devs, ack_com);
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_unicast(
                        UnicastID ucid,
                        string dev,
                        bool wait_reply=true
                    )
    {
        return new FakeUnicastClient(node, ucid, dev, wait_reply);
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_tcp(
                        string dest,
                        bool wait_reply=true
                    )
    {
        return new FakeTCPClient(node, dest, wait_reply);
    }
}

