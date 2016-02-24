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

using Gee;
using Netsukuku;
using TaskletSystem;

const uint16 ntkd_port = 60269;

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
    public ArrayList<string> ping_guids;
    public SimulatorCollisionDomain()
    {
        collision_domains.add(this);
        active = true;
        delay_min = 9700;
        delay_max = 10200;
        ping_guids = new ArrayList<string>();
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
        muted = false;
        verbose = false;
    }

    public void print_signals(NeighborhoodManager mgr)
    {
        mgr.arc_added.connect(
            (arc) => {
                print_msg(@"Manager for node $(id.id) signals: ");
                print_msg(@"Added arc with $(arc.i_neighborhood_mac), RTT $(arc.i_neighborhood_cost)\n");
            }
        );
        mgr.arc_removed.connect(
            (arc) => {
                print_msg(@"Manager for node $(id.id) signals: ");
                print_msg(@"Removed arc with $(arc.i_neighborhood_mac)\n");
            }
        );
        mgr.arc_changed.connect(
            (arc) => {
                print_msg(@"Manager for node $(id.id) signals: ");
                print_msg(@"Changed arc with $(arc.i_neighborhood_mac), RTT $(arc.i_neighborhood_cost)\n");
            }
        );
    }

    public bool muted;
    public void print_msg(string msg)
    {
        if (!muted) print(msg);
    }

    public bool verbose;
    public void print_verbose(string msg)
    {
        if (!muted && verbose) print(msg);
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

    // Initialize tasklet system
    PthTaskletImplementer.init();
    ITasklet tasklet = PthTaskletImplementer.get_tasklet_system();

    // Pass tasklet system to module neighborhood
    NeighborhoodManager.init(tasklet);

    var col_a = new SimulatorCollisionDomain();
    var col_b = new SimulatorCollisionDomain();
    var node_a = new SimulatorNode(1);
    //node_a.verbose = true;
    node_a.devices["eth0"] = new SimulatorNode.SimulatorDevice(col_a);
    node_a.devices["eth1"] = new SimulatorNode.SimulatorDevice(col_b);
    node_a.devices["eth2"] = new SimulatorNode.SimulatorDevice(null);
    var node_b = new SimulatorNode(1);
    //node_b.verbose = true;
    node_b.devices["eth0"] = new SimulatorNode.SimulatorDevice(col_a);
    var node_c = new SimulatorNode(1);
    //node_c.verbose = true;
    node_c.devices["eth0"] = new SimulatorNode.SimulatorDevice(col_a);

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
    ms_wait(100);
    var node_c_mgr = new NeighborhoodManager(node_c.id, 12, new FakeStubFactory(node_c), new FakeIPRouteManager(node_c));
    node_c.print_signals(node_c_mgr);
    node_c_mgr.start_monitor(new FakeNic(node_c.devices["eth0"]));
        node_c.devices["eth0"].mgr = node_c_mgr;
        ms_wait(10);

    ms_wait(2000);

    node_a_mgr.stop_monitor_all();
    ms_wait(100);
    node_b_mgr.stop_monitor_all();
    ms_wait(100);

    PthTaskletImplementer.kill();
    return 0;
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

    public uint16 expect_pong(string s, INtkdChannel ch)
    {
        return 12345;
    }

    public uint16 expect_ping(string s, uint16 peer_port)
    {
        //print(@"Device $(_mac) willing to answer pings with guid $(guid).\n");
        if (device.collision_domain == null) return 12345;
        device.collision_domain.ping_guids.add(s);
        return 12345;

    }

    public long send_ping(string s, uint16 peer_port, INtkdChannel ch) throws NeighborhoodGetRttError
    {
        //print(@"Device $(_mac) pinging with guid $(guid).\n");
        if (device.collision_domain == null) throw new NeighborhoodGetRttError.GENERIC("No carrier");
        SimulatorCollisionDomain dom = device.collision_domain;
        if (s in dom.ping_guids)
        {
            dom.ping_guids.remove(s);
            return Random.int_range((int32)dom.delay_min, (int32)dom.delay_max);
        }
        throw new NeighborhoodGetRttError.GENERIC("No recv");
    }

    public long measure_rtt(string peer_addr, string peer_mac, string my_addr) throws NeighborhoodGetRttError
    {
        throw new NeighborhoodGetRttError.GENERIC("Alternative method not implemented");
    }
}

public class FakeBroadcastClient : FakeAddressManagerStub
{
    public BroadcastID bcid;
    public Gee.Collection<string> devs;
    public zcd.ModRpc.IAckCommunicator? ack_com;
    public SimulatorNode node;

    public FakeBroadcastClient(
                        SimulatorNode node,
                        BroadcastID bcid,
                        Gee.Collection<string> devs,
                        zcd.ModRpc.IAckCommunicator? ack_com)
    {
        this.node = node;
        this.bcid = bcid;
        this.devs = devs;
        this.ack_com = ack_com;
    }

    public override uint16 expect_ping
	(string guid, uint16 peer_port)
    {
        // never called in broadcast
        assert_not_reached();
    }

    public override void remove_arc (INeighborhoodNodeID my_id, string mac, string nic_addr)
    {
        // never called in broadcast
        assert_not_reached();
    }

    public override void request_arc (INeighborhoodNodeID my_id, string mac, string nic_addr)
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
	public override void here_i_am (INeighborhoodNodeID my_id, string mac, string nic_addr)
	{
	    node.print_verbose(@"sending to broadcast 'here_i_am' from node $(node.id.id) through devs:\n");
	    foreach (string dev in devs) node.print_verbose(@"        $(dev)\n");
	    if (bcid.ignore_nodeid != null) node.print_verbose(@"        ignoring node $((bcid.ignore_nodeid as MyNodeID).id)\n");
	    node.print_verbose(@"        saying:\n");
	    assert(my_id is MyNodeID);
	    MyNodeID _my_id = my_id as MyNodeID;
	    node.print_verbose(@"           my id is $(_my_id.id)\n");
	    node.print_verbose(@"           my netid is $(_my_id.netid)\n");
	    node.print_verbose(@"           my mac is $(mac)\n");
	    node.print_verbose(@"           my nic_addr is $(nic_addr)\n");
	    Gee.List<string>? responding_macs = null;
	    if (ack_com != null)
	    {
    	    node.print_verbose(@"           requesting ACK\n");
	        responding_macs = new ArrayList<string>();
            Tasklet.tasklet_callback(
                (_ack_com, _responding_macs) => {
                    zcd.ModRpc.IAckCommunicator t_ack_com = (zcd.ModRpc.IAckCommunicator)_ack_com;
                    Gee.List<string> t_responding_macs = (Gee.List<string>)_responding_macs;
                    ms_wait(3000);
                    t_ack_com.process_macs_list(t_responding_macs);
                },
                ack_com,
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
                                        // do a deep copy of t_call.arg_my_id, which is a MyNodeID
                                        Json.Node n = Json.gobject_serialize(t_call.arg_my_id).copy();
                                        MyNodeID t_my_id = (MyNodeID)Json.gobject_deserialize(typeof(MyNodeID), n);
                                        var bcinfo = new Netsukuku.ModRpc.BroadcastCallerInfo
                                                     (t_call.callee_dev, t_call.caller_ip, t_call.bcid);
	                                    t_call.callee_node.print_verbose(@"node $(t_call.callee_node.id.id): got 'here_i_am' through dev $(t_call.callee_dev)\n");
                                        t_devc.mgr.here_i_am(t_my_id,
                                                             t_call.arg_mac,
                                                             t_call.arg_nic_addr,
                                                             bcinfo);
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

public class FakeUnicastClient : FakeAddressManagerStub
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

    private void send_reply_error(Channel ch, string domain, string code, string message)
    {
        ch.send_async(ReturningValue.ERROR);
        ch.send_async(domain);
        ch.send_async(code);
        ch.send_async(message);
    }

    private void send_reply_void(Channel ch)
    {
        ch.send_async(ReturningValue.VOID);
    }

    private void send_reply_return(Channel ch, Value ret)
    {
        ch.send_async(ReturningValue.RETURN);
        ch.send_async(ret);
    }

    private ReturningValue get_reply(Channel ch) throws zcd.ModRpc.StubError
    {
        ReturningValue ret = new ReturningValue();
        try {
            ret.resp = (string)ch.recv_with_timeout(2000);
        } catch (ChannelError e) {throw new zcd.ModRpc.StubError.GENERIC("no answer");}
        if (ret.resp == ReturningValue.ERROR)
        {
            ret.domain = (string)ch.recv();
            ret.code = (string)ch.recv();
            ret.message = (string)ch.recv();
        }
        else if (ret.resp == ReturningValue.RETURN)
        {
            ret.ret = ch.recv();
        }
        return ret;
    }
    private class ReturningValue : Object
    {
        public string resp;
        public string domain;
        public string code;
        public string message;
        public Value ret;
        public const string RETURN = "return";
        public const string VOID = "void";
        public const string ERROR = "error";
    }

    public override uint16 expect_ping
	(string guid, uint16 peer_port)
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
    public override void remove_arc (INeighborhoodNodeID my_id, string mac, string nic_addr)
                throws zcd.ModRpc.StubError
	{
	    node.print_verbose(@"sending to unicast 'remove_arc' from node $(node.id.id) through dev $(dev),\n");
	    if (wait_reply) node.print_verbose(@"        waiting reply,\n");
	    node.print_verbose(@"        to node $((ucid.nodeid as MyNodeID).id).\n");
	    node.print_verbose(@"        Saying:\n");
	    assert(my_id is MyNodeID);
	    MyNodeID _my_id = my_id as MyNodeID;
	    node.print_verbose(@"           my id is $(_my_id.id)\n");
	    node.print_verbose(@"           my netid is $(_my_id.netid)\n");
	    node.print_verbose(@"           my mac is $(mac)\n");
	    node.print_verbose(@"           my nic_addr is $(nic_addr)\n");
	    if (wait_reply && ! node.devices[dev].working) throw new zcd.ModRpc.StubError.GENERIC("my device not working.");
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
                                        // do a deep copy of t_call.arg_my_id, which is a MyNodeID
                                        Json.Node n = Json.gobject_serialize(t_call.arg_my_id).copy();
                                        MyNodeID t_my_id = (MyNodeID)Json.gobject_deserialize(typeof(MyNodeID), n);
                                        var ucinfo = new Netsukuku.ModRpc.UnicastCallerInfo
                                                     (t_call.callee_dev, t_call.caller_ip, t_call.ucid);
                                        t_devc.mgr.remove_arc(t_my_id,
                                                               t_call.arg_mac,
                                                               t_call.arg_nic_addr,
                                                               ucinfo);
                                        if (t_call.reply_ch != null) send_reply_void(t_call.reply_ch);
	                                },
	                                call);
	                            // end tasklet body
	                        }
	                    }
	                }
	            }
	        }
	    }
	    if (wait_reply) get_reply(reply_ch);
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
    public override void request_arc (INeighborhoodNodeID my_id, string mac, string nic_addr)
                throws NeighborhoodRequestArcError, zcd.ModRpc.StubError
	{
	    node.print_verbose(@"sending to unicast 'request_arc' from node $(node.id.id) through dev $(dev),\n");
	    if (wait_reply) node.print_verbose(@"        waiting reply,\n");
	    node.print_verbose(@"        to node $((ucid.nodeid as MyNodeID).id).\n");
	    node.print_verbose(@"        Saying:\n");
	    assert(my_id is MyNodeID);
	    MyNodeID _my_id = my_id as MyNodeID;
	    node.print_verbose(@"           my id is $(_my_id.id)\n");
	    node.print_verbose(@"           my netid is $(_my_id.netid)\n");
	    node.print_verbose(@"           my mac is $(mac)\n");
	    node.print_verbose(@"           my nic_addr is $(nic_addr)\n");
	    if (wait_reply && ! node.devices[dev].working) throw new zcd.ModRpc.StubError.GENERIC("my device not working.");
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
                                        // do a deep copy of t_call.arg_my_id, which is a MyNodeID
                                        Json.Node n = Json.gobject_serialize(t_call.arg_my_id).copy();
                                        MyNodeID t_my_id = (MyNodeID)Json.gobject_deserialize(typeof(MyNodeID), n);
                                        var ucinfo = new Netsukuku.ModRpc.UnicastCallerInfo
                                                     (t_call.callee_dev, t_call.caller_ip, t_call.ucid);
                                        try {
                                            t_devc.mgr.request_arc(t_my_id,
                                                                   t_call.arg_mac,
                                                                   t_call.arg_nic_addr,
                                                                   ucinfo);
                                            if (t_call.reply_ch != null) send_reply_void(t_call.reply_ch);
                                        } catch (NeighborhoodRequestArcError e) {
                                            if (t_call.reply_ch != null)
                                            {
                                                string message = e.message;
                                                string domain = "NeighborhoodRequestArcError";
                                                if (e is NeighborhoodRequestArcError.NOT_SAME_NETWORK)
                                                    send_reply_error(t_call.reply_ch, domain, "NOT_SAME_NETWORK", message);
                                                if (e is NeighborhoodRequestArcError.TOO_MANY_ARCS)
                                                    send_reply_error(t_call.reply_ch, domain, "TOO_MANY_ARCS", message);
                                                if (e is NeighborhoodRequestArcError.TWO_ARCS_ON_COLLISION_DOMAIN)
                                                    send_reply_error(t_call.reply_ch, domain, "TWO_ARCS_ON_COLLISION_DOMAIN", message);
                                                if (e is NeighborhoodRequestArcError.GENERIC)
                                                    send_reply_error(t_call.reply_ch, domain, "GENERIC", message);

                                            }
                                        }
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
            ReturningValue ret = get_reply(reply_ch);
            if (ret.resp == ReturningValue.ERROR)
            {
                if (ret.domain == "NeighborhoodRequestArcError")
                {
                    if (ret.code == "NOT_SAME_NETWORK")
                        throw new NeighborhoodRequestArcError.NOT_SAME_NETWORK(ret.message);
                    if (ret.code == "TOO_MANY_ARCS")
                        throw new NeighborhoodRequestArcError.TOO_MANY_ARCS(ret.message);
                    if (ret.code == "TWO_ARCS_ON_COLLISION_DOMAIN")
                        throw new NeighborhoodRequestArcError.TWO_ARCS_ON_COLLISION_DOMAIN(ret.message);
                    if (ret.code == "GENERIC")
                        throw new NeighborhoodRequestArcError.GENERIC(ret.message);
                }
                assert_not_reached();
            }
            return; // ok
	    }
	}

	public override void here_i_am (INeighborhoodNodeID my_id, string mac, string nic_addr)
	{
        // never called in unicast
        assert_not_reached();
	}
}

public class FakeTCPClient : FakeAddressManagerStub
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

    public override uint16 expect_ping
	(string guid, uint16 peer_port)
                throws NeighborhoodUnmanagedDeviceError, zcd.ModRpc.StubError
	{
	    node.print_verbose(@"sending to $(dest) 'expect_ping($(guid))' from node $(node.id.id).\n");
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
	                                    if (found) throw new zcd.ModRpc.StubError.GENERIC("conflicting IP");
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
            if (found_devc.mgr == null) throw new zcd.ModRpc.StubError.GENERIC("no connect");
            if (found_my_devc.addresses.is_empty) throw new zcd.ModRpc.StubError.GENERIC("no connect");
            var tcinfo = new zcd.ModRpc.TcpCallerInfo
                         (dest, found_my_devc.addresses[0]);
            return found_devc.mgr.expect_ping(guid, peer_port, tcinfo);
        }
        else throw new zcd.ModRpc.StubError.GENERIC("no connect");
	}

    public override void remove_arc (INeighborhoodNodeID my_id, string mac, string nic_addr)
	{
        // never called in tcp
        assert_not_reached();
	}

    public override void request_arc (INeighborhoodNodeID my_id, string mac, string nic_addr)
                throws NeighborhoodRequestArcError, zcd.ModRpc.StubError
	{
        // never called in tcp
        assert_not_reached();
	}

	public override void here_i_am (INeighborhoodNodeID my_id, string mac, string nic_addr)
	{
        // never called in tcp
        assert_not_reached();
	}
}

public abstract class FakeAddressManagerStub : Object,
                                  IAddressManagerStub,
                                  INeighborhoodManagerStub
{
	public virtual unowned INeighborhoodManagerStub
	neighborhood_manager_getter()
	{
	    return this;
	}

	public virtual unowned IQspnManagerStub
	qspn_manager_getter()
	{
	    error("FakeAddressManagerSkeleton: this test should not use method qspn_manager_getter.");
	}

	public virtual unowned IPeersManagerStub
	peers_manager_getter()
	{
	    error("FakeAddressManagerSkeleton: this test should not use method peers_manager_getter.");
	}

	public virtual unowned ICoordinatorManagerStub
	coordinator_manager_getter()
	{
	    error("FakeAddressManagerSkeleton: this test should not use method coordinator_manager_getter.");
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
        node.print_verbose(@"adding address $(my_addr) to device $(my_dev) of node $(node.id.id).\n");
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
        node.print_verbose(@"adding neighbor $(neighbor_addr) reachable through $(my_dev) which has $(my_addr) of node $(node.id.id).\n");
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
        node.print_verbose(@"removing neighbor $(neighbor_addr) reachable through $(my_dev) which has $(my_addr) of node $(node.id.id).\n");
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
        node.print_verbose(@"removing address $(my_addr) from device $(my_dev) of node $(node.id.id).\n");
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

    public IAddressManagerStub
                    i_neighborhood_get_broadcast(
                        BroadcastID bcid,
                        Gee.Collection<string> devs,
                        zcd.ModRpc.IAckCommunicator? ack_com
                    )
    {
        return new FakeBroadcastClient(node, bcid, devs, ack_com);
    }

    public IAddressManagerStub
                    i_neighborhood_get_unicast(
                        UnicastID ucid,
                        string dev,
                        bool wait_reply=true
                    )
    {
        return new FakeUnicastClient(node, ucid, dev, wait_reply);
    }

    public IAddressManagerStub
                    i_neighborhood_get_tcp(
                        string dest,
                        bool wait_reply=true
                    )
    {
        return new FakeTCPClient(node, dest, wait_reply);
    }
}

