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

public class FakeNeighbour : Object
{
    // list of neighbours in this testbed.
    private static ArrayList<FakeNeighbour> _list = null;
    public static ArrayList<FakeNeighbour> list {
        get {
            if (_list == null) _list = new ArrayList<FakeNeighbour>();
            return _list;
        }
    }
    // constructor
    public FakeNeighbour()
    {
        list.add(this);
    }
    // this fake neighbour is reached by my node's nic.
    public string my_node_nic;
    // this fake neighbour has this ID.
    public INeighborhoodNodeID neighbour_id;
    // this fake neighbour has this mac.
    public string neighbour_mac;
    // this fake neighbour has this RTT.
    public long usec_rtt;
    // this fake neighbour has already an arc with me.
    public bool has_arc = false;
    // guid registered for ping.
    private HashMap<long, Tasklets.Timer> guids_timeout = null;
    public void register_guid(long guid)
    {
        if (guids_timeout == null) guids_timeout = new HashMap<long, Tasklets.Timer>();
        guids_timeout[guid] = new Tasklets.Timer(3000);
    }
    public bool check_guid(long guid)
    {
        if (guids_timeout == null) guids_timeout = new HashMap<long, Tasklets.Timer>();
        foreach (long k in guids_timeout.keys.to_array())
        {
            if (guids_timeout[k].is_expired()) guids_timeout.unset(k);
            else if (k == guid) return true;
        }
        return false;
    }
}

public class FakeNic : Object, INeighborhoodNetworkInterface
{
    public FakeNic(string dev, string mac)
    {
        _dev = dev;
        _mac = mac;
    }

    private string _dev;
    private string _mac;

    /* Public interface INeighborhoodNetworkInterface
     */

    public bool i_neighborhood_equals(INeighborhoodNetworkInterface other)
    {
        // This kind of equality test is ok because this vala file
        // is the only able to create an instance
        // of INeighborhoodNetworkInterface and it won't create more than one
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
        // check if this guid has been previously registered into some fakenode
        foreach (FakeNeighbour f in FakeNeighbour.list)
        {
            if (f.check_guid(guid)) return f.usec_rtt;
        }
        throw new GetRttError.GENERIC("Not reached");
    }

    public void i_neighborhood_prepare_ping(uint guid)
    {
        // This would register this guid, but nothing to do in this testbed.
    }
}

public class FakeBroadcastClient : FakeAddressManager
{
    public BroadcastID bcid;
    public Gee.Collection<INeighborhoodNetworkInterface> nics;
    public IAcknowledgementsCommunicator ack_com;

    public FakeBroadcastClient(BroadcastID bcid,
                        Gee.Collection<INeighborhoodNetworkInterface> nics,
                        IAcknowledgementsCommunicator ack_com)
    {
        this.bcid = bcid;
        this.nics = nics;
        this.ack_com = ack_com;
    }

    public override unowned INeighborhoodManager _neighborhood_manager_getter()
    {
        return this;
    }
    public override void expect_ping (int guid, zcd.CallerInfo? _rpc_caller = null)
    {assert(false);}  // never called in broadcast
    public override void remove_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
    {assert(false);}  // never called in broadcast
    public override void request_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
    {assert(false);}  // never called in broadcast
	public override void here_i_am (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
	{
	    print("sending broadcast \"here_i_am\" to:");
	    foreach (INeighborhoodNetworkInterface nic in nics) print(@" $(nic.i_neighborhood_dev)");
	    print(".\n");
        foreach (FakeNeighbour f in FakeNeighbour.list)
        {
            bool f_has_received = false;
            foreach (INeighborhoodNetworkInterface nic in nics)
                if (f.my_node_nic == nic.i_neighborhood_dev)
                    f_has_received = true;
            if (f_has_received)
            {
                if (! f.has_arc)
                {
                    my_node_neighborhood_mgr.request_arc(f.neighbour_id,
                                                     f.neighbour_mac,
                                                     ""/*TODO*/,
                                                     new CallerInfo("f_ip",
                                                                    "f_port",
                                                                    f.my_node_nic));
                    f.has_arc = true;
                }
                // a periodical ping is not really needed in this testbed
            }
        }
	}
}

public class FakeUnicastClient : FakeAddressManager
{
    public UnicastID ucid;
    public INeighborhoodNetworkInterface nic;
    public bool wait_reply;

    public FakeUnicastClient(UnicastID ucid, INeighborhoodNetworkInterface nic, bool wait_reply)
    {
            this.ucid = ucid;
            this.nic = nic;
            this.wait_reply = wait_reply;
    }

    public override void expect_ping (int guid, zcd.CallerInfo? _rpc_caller = null)
    {
        string dest_mac = ucid.mac;
        INeighborhoodNodeID dest_id = ucid.nodeid as INeighborhoodNodeID;
        // find the fakeneighbour
        foreach (FakeNeighbour f in FakeNeighbour.list)
        {
            if (dest_mac == f.neighbour_mac &&
                dest_id.i_neighborhood_equals(f.neighbour_id as INeighborhoodNodeID))
            {
                f.register_guid(guid);
                break;
            }
        }
    }
    public override void remove_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
    {
        // TODO
    }
    public override void request_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
                throws RequestArcError, RPCError
    {
        // just accept
        print(@"requested arc to $(ucid.mac)\n");
        // start a periodical ping, not needed for this testbed
    }
	public override void here_i_am (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
    {assert(false);}  // never called in unicast
}

public class FakeTCPClient : FakeAddressManager
{
    public string dest;
    public bool wait_reply;

    public FakeTCPClient(string dest, bool wait_reply)
    {
            this.dest = dest;
            this.wait_reply = wait_reply;
    }

    public override void expect_ping (int guid, zcd.CallerInfo? _rpc_caller = null)
    {
        // TODO
    }
    public override void remove_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
    {
        // TODO
    }
    public override void request_arc (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
                throws RequestArcError, RPCError
    {
        // TODO
    }
	public override void here_i_am (INeighborhoodNodeID my_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller = null)
    {assert(false);}  // never called in unicast
}

public class FakeIPRouteManager : Object, INeighborhoodIPRouteManager
{
    public void i_neighborhood_add_address(
                        string my_addr,
                        string my_dev
                    )
    {
        // TODO
    }

    public void i_neighborhood_add_neighbor(
                        string my_addr,
                        string my_dev,
                        string neighbor_addr
                    )
    {
        // TODO
    }

    public void i_neighborhood_remove_neighbor(
                        string my_addr,
                        string my_dev,
                        string neighbor_addr
                    )
    {
        // TODO
    }

    public void i_neighborhood_remove_address(
                        string my_addr,
                        string my_dev
                    )
    {
        // TODO
    }
}

public class FakeStubFactory: Object, INeighborhoodStubFactory
{
    public IAddressManagerRootDispatcher
                    i_neighborhood_get_broadcast(
                        BroadcastID bcid,
                        Gee.Collection<INeighborhoodNetworkInterface> nics,
                        IAcknowledgementsCommunicator ack_com
                    )
    {
        return new FakeBroadcastClient(bcid, nics, ack_com);
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_unicast(
                        UnicastID ucid,
                        INeighborhoodNetworkInterface nic,
                        bool wait_reply=true
                    )
    {
        return new FakeUnicastClient(ucid, nic, wait_reply);
    }

    public IAddressManagerRootDispatcher
                    i_neighborhood_get_tcp(
                        string dest,
                        bool wait_reply=true
                    )
    {
        return new FakeTCPClient(dest, wait_reply);
    }
}

NeighborhoodManager my_node_neighborhood_mgr;

void main()
{
    if (false)
    {
        // prepare some neighbour
        FakeNeighbour n1 = new FakeNeighbour();
        n1.my_node_nic = "fakeeth1";
        n1.neighbour_id = new MyNodeID(1);
        n1.neighbour_mac = "22:22:22:22:22:22";
        n1.usec_rtt = 1300;
        n1 = new FakeNeighbour();
        n1.my_node_nic = "fakeeth1";
        n1.neighbour_id = new MyNodeID(1);
        n1.neighbour_mac = "33:33:33:33:33:33";
        n1.usec_rtt = 20000;
    }

    string iface = "fakeeth1";
    string mac = "4E:86:C7:5A:A8:CE";
    // generate my nodeID on network 1
    INeighborhoodNodeID id = new MyNodeID(1);
    // init tasklet
    assert(Tasklet.init());
    {
        // create module neighborhood
        my_node_neighborhood_mgr = new NeighborhoodManager(id, 12, new FakeStubFactory(), new FakeIPRouteManager());
        // connect signals
        my_node_neighborhood_mgr.network_collision.connect(
            (o) => {
                MyNodeID other = o as MyNodeID;
                if (other == null) return;
                print(@"Collision with netid $(other.netid)\n");
            }
        );
        my_node_neighborhood_mgr.arc_added.connect(
            (arc) => {
                print(@"Added arc with $(arc.i_neighborhood_mac)\n");
            }
        );
        my_node_neighborhood_mgr.arc_removed.connect(
            (arc) => {
                print(@"Removed arc with $(arc.i_neighborhood_mac)\n");
            }
        );
        my_node_neighborhood_mgr.arc_changed.connect(
            (arc) => {
                print(@"Changed arc with $(arc.i_neighborhood_mac)\n");
            }
        );
        // run monitor
        my_node_neighborhood_mgr.start_monitor(new FakeNic(iface, mac));
        // wait a little, then receive a here_i_am from john
        Tasklet.nap(2, 0);
        FakeNeighbour john = new FakeNeighbour();
        john.my_node_nic = "fakeeth1";
        john.neighbour_id = new MyNodeID(1);
        john.neighbour_mac = "44:44:44:44:44:44";
        john.usec_rtt = 2000;
        my_node_neighborhood_mgr.here_i_am(john.neighbour_id,
                                       john.neighbour_mac,
                                       ""/*TODO*/,
                                       new CallerInfo("john_ip",
                                                      "john_port",
                                                      john.my_node_nic));
        // Stay a while
        Tasklet.nap(3, 0);
    }
    assert(Tasklet.kill());
}

