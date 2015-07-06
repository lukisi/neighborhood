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
using Netsukuku.ModRpc;
using Tasklets;
using zcd;

const uint16 ntkd_port = 60269;

namespace Netsukuku
{
    class MyIPRouteManager : Object, INeighborhoodIPRouteManager
    {
        public void i_neighborhood_add_address(
                            string my_addr,
                            string my_dev
                        )
        {
            try {
                CommandResult com_ret = Tasklet.exec_command(@"ip address add $(my_addr) dev $(my_dev)");
                if (com_ret.exit_status != 0)
                    error(@"$(com_ret.cmderr)\n");
            } catch (SpawnError e) {error("Unable to spawn a command");}
        }

        public void i_neighborhood_add_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        )
        {
            try {
                CommandResult com_ret = Tasklet.exec_command(@"ip route add $(neighbor_addr) dev $(my_dev) src $(my_addr)");
                if (com_ret.exit_status != 0)
                    error(@"$(com_ret.cmderr)\n");
            } catch (SpawnError e) {error("Unable to spawn a command");}
        }

        public void i_neighborhood_remove_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        )
        {
            try {
                CommandResult com_ret = Tasklet.exec_command(@"ip route del $(neighbor_addr) dev $(my_dev) src $(my_addr)");
                if (com_ret.exit_status != 0)
                    error(@"$(com_ret.cmderr)\n");
            } catch (SpawnError e) {error("Unable to spawn a command");}
        }

        public void i_neighborhood_remove_address(
                            string my_addr,
                            string my_dev
                        )
        {
            try {
                CommandResult com_ret = Tasklet.exec_command(@"ip address del $(my_addr)/32 dev $(my_dev)");
                if (com_ret.exit_status != 0)
                    error(@"$(com_ret.cmderr)\n");
            } catch (SpawnError e) {error("Unable to spawn a command");}
        }
    }

    class MyStubFactory: Object, INeighborhoodStubFactory
    {
        public IAddressManagerStub
                        i_neighborhood_get_broadcast(
                            BroadcastID bcid,
                            Gee.Collection<string> devs,
                            zcd.ModRpc.IAckCommunicator? ack_com
                        )
        {
            assert(! devs.is_empty);
            var bc = ModRpc.get_addr_broadcast(devs, ntkd_port, bcid, ack_com);
            return bc;
        }

        public IAddressManagerStub
                        i_neighborhood_get_unicast(
                            UnicastID ucid,
                            string dev,
                            bool wait_reply
                        )
        {
            var uc = ModRpc.get_addr_unicast(dev, ntkd_port, ucid, wait_reply);
            return uc;
        }

        public IAddressManagerStub
                        i_neighborhood_get_tcp(
                            string dest,
                            bool wait_reply
                        )
        {
            var tc = ModRpc.get_addr_tcp_client(dest, ntkd_port);
            assert(tc is ITcpClientRootStub);
            ((ITcpClientRootStub)tc).wait_reply = wait_reply;
            return tc;
        }
    }

    public class MyNodeID : Object, zcd.ModRpc.ISerializable, INeighborhoodNodeID
    {
        public int id {get; set;}
        public int netid {get; set;}
        public MyNodeID(int netid)
        {
            id = Random.int_range(1, 10000);
            this.netid = netid;
        }

        public bool check_deserialization()
        {
            return id != 0 && netid != 0;
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

        public uint16 expect_pong(string guid, INtkdChannel ch)
        {
            uint16 ret;
            ServerDatagramSocket s;
            try {
                s = new ServerDatagramSocket.ephemeral(out ret, null, _dev);
            } catch (Error e) {error(e.message);}
            WaitPongTasklet ts = new WaitPongTasklet();
            ts.ch = ch;
            ts.s = s;
            ts.guid = guid;
            ts.dev = _dev;
            INtkdTaskletHandle t = ntkd_tasklet.spawn(ts);
            AbortWaitPongTasklet ts2 = new AbortWaitPongTasklet();
            ts2.t = t;
            ntkd_tasklet.spawn(ts2);
            return ret;
        }
        private class WaitPongTasklet : Object, INtkdTaskletSpawnable
        {
            public string guid;
            public ServerDatagramSocket s;
            public INtkdChannel ch;
            public string dev;
            public void* func()
            {
                while (true)
                {
                    const int max_pkt_size = 10;
                    uint8 buf[11];
                    uint8* b = (uint8*)buf;
                    string rmt_ip;
                    uint16 rmt_port;
                    size_t msglen;
                    try {
                        msglen = s.recvfrom_new(b, max_pkt_size, out rmt_ip, out rmt_port);
                    } catch (Error e) {
                        warning(@"wait_pong: error reading from $(dev)");
                        return null;
                    }
                    b[msglen++] = 0; // NULL terminate

                    // There must be no '\0' in the message
                    bool err_zero = false;
                    for (int i = 0; i < msglen-1; i++)
                    {
                        if (b[i] == 0)
                        {
                            warning("wait_pong: malformed message has a NULL byte");
                            err_zero = true;
                            break;
                        }
                    }
                    if (err_zero) continue;

                    unowned uint8[] msg_buf;
                    msg_buf = (uint8[])b;
                    msg_buf.length = (int)msglen;
                    string msg = (string)msg_buf;

                    if (msg == guid)
                    {
                        // must reform tasklet, channel, nap...
                        ch.send_async(true);
                        ntkd_tasklet.schedule();
                        return null;
                    }
                    warning(@"wait_pong: expecting '$(guid)', not '$(msg)'");
                }
            }
        }
        private class AbortWaitPongTasklet : Object, INtkdTaskletSpawnable
        {
            public INtkdTaskletHandle t;
            public void* func()
            {
                ntkd_tasklet.ms_wait(10000);
                if (t.is_running()) t.kill();
                return null;
            }
        }

        public uint16 expect_ping(string guid, uint16 peer_port)
        {
            uint16 ret;
            ServerDatagramSocket s;
            try {
                s = new ServerDatagramSocket.ephemeral(out ret, null, _dev);
            } catch (Error e) {error(e.message);}
            WaitPingTasklet ts = new WaitPingTasklet();
            ts.peer_port = peer_port;
            ts.s = s;
            ts.guid = guid;
            ts.dev = _dev;
            INtkdTaskletHandle t = ntkd_tasklet.spawn(ts);
            AbortWaitPingTasklet ts2 = new AbortWaitPingTasklet();
            ts2.t = t;
            ntkd_tasklet.spawn(ts2);
            return ret;
        }
        private class WaitPingTasklet : Object, INtkdTaskletSpawnable
        {
            public string guid;
            public ServerDatagramSocket s;
            public uint16 peer_port;
            public string dev;
            public void* func()
            {
                while (true)
                {
                    const int max_pkt_size = 10;
                    uint8 buf[11];
                    uint8* b = (uint8*)buf;
                    string rmt_ip;
                    uint16 rmt_port;
                    size_t msglen;
                    try {
                        msglen = s.recvfrom_new(b, max_pkt_size, out rmt_ip, out rmt_port);
                    } catch (Error e) {
                        warning(@"wait_ping: error reading from $(dev)");
                        return null;
                    }
                    b[msglen++] = 0; // NULL terminate

                    // There must be no '\0' in the message
                    bool err_zero = false;
                    for (int i = 0; i < msglen-1; i++)
                    {
                        if (b[i] == 0)
                        {
                            warning("wait_ping: malformed message has a NULL byte");
                            err_zero = true;
                            break;
                        }
                    }
                    if (err_zero) continue;

                    unowned uint8[] msg_buf;
                    msg_buf = (uint8[])b;
                    msg_buf.length = (int)msglen;
                    string msg = (string)msg_buf;

                    if (msg == guid)
                    {
                        INtkdClientDatagramSocket s;
                        try {
                            s = ntkd_tasklet.get_client_datagram_socket(peer_port, dev);
                            s.sendto(b, msglen-1);
                        } catch (Error e) {return null;}
                        return null;
                    }
                    warning(@"wait_ping: expecting '$(guid)', not '$(msg)'");
                }
            }
        }
        private class AbortWaitPingTasklet : Object, INtkdTaskletSpawnable
        {
            public INtkdTaskletHandle t;
            public void* func()
            {
                ntkd_tasklet.ms_wait(10000);
                if (t.is_running()) t.kill();
                return null;
            }
        }

        public long send_ping(string guid, uint16 peer_port, INtkdChannel ch) throws NeighborhoodGetRttError
        {
            INtkdClientDatagramSocket s;
            try {
                s = ntkd_tasklet.get_client_datagram_socket(peer_port, _dev);
                s.sendto((uint8*)guid.data, guid.length);
            } catch (Error e) {throw new NeighborhoodGetRttError.GENERIC(e.message);}
            MyNetworkInterface.Timer t = new MyNetworkInterface.Timer();
            bool ret;
            try {
                ret = (bool)ch.recv_with_timeout(11000);
            } catch (NtkdChannelError e) {throw new NeighborhoodGetRttError.GENERIC(e.message);}
            if (ret) return t.get_lap();
            throw new NeighborhoodGetRttError.GENERIC("no response");
        }
        internal class Timer : Object
        {
            private TimeVal start;
            public Timer()
            {
                start = TimeVal();
                start.get_current_time();
            }

            public long get_lap()
            {
                TimeVal lap = TimeVal();
                lap.get_current_time();
                long sec = lap.tv_sec - start.tv_sec;
                long usec = lap.tv_usec - start.tv_usec;
                if (usec < 0)
                {
                    usec += 1000000;
                    sec--;
                }
                return sec*1000000 + usec;
            }
        }

        public long measure_rtt(string peer_addr, string peer_mac, string my_addr) throws NeighborhoodGetRttError
        {
            try {
                CommandResult com_ret = Tasklet.exec_command(@"ping -n -q -c 1 $(peer_addr)");
                if (com_ret.exit_status != 0)
                    throw new NeighborhoodGetRttError.GENERIC(@"ping: error $(com_ret.cmderr)");
                foreach (string line in com_ret.cmdout.split("\n"))
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
                throw new NeighborhoodGetRttError.GENERIC(@"could not parse $(com_ret.cmdout)");
            } catch (SpawnError e) {
                throw new NeighborhoodGetRttError.GENERIC("Unable to spawn a command");
            }
        }
    }

    public class AddressManager : FakeAddressManagerSkeleton
    {
        public NeighborhoodManager neighborhood_manager;
        public override unowned INeighborhoodManagerSkeleton neighborhood_manager_getter()
        {
            return neighborhood_manager;
        }
    }
    AddressManager? address_manager;

    class MyServerDelegate : Object, ModRpc.IRpcDelegate
    {
        public MyServerDelegate(INeighborhoodNodeID id)
        {
            this.id = id;
        }
        private INeighborhoodNodeID id;

        public ModRpc.IAddressManagerSkeleton? get_addr(zcd.ModRpc.CallerInfo caller)
        {
            if (caller is zcd.ModRpc.TcpCallerInfo)
            {
                return address_manager;
            }
            else if (caller is ModRpc.UnicastCallerInfo)
            {
                ModRpc.UnicastCallerInfo c = (ModRpc.UnicastCallerInfo)caller;
                if (c.unicastid.nodeid.i_neighborhood_equals(id))
                {
                    // got from nic ... which has MAC ...
                    string my_mac = macgetter.get_mac(c.dev).up();
                    if (c.unicastid.mac == my_mac)
                    {
                        return address_manager;
                    }
                }
                return null;
            }
            else if (caller is ModRpc.BroadcastCallerInfo)
            {
                ModRpc.BroadcastCallerInfo c = (ModRpc.BroadcastCallerInfo)caller;
                if (c.broadcastid.ignore_nodeid != null)
                    if (c.broadcastid.ignore_nodeid.i_neighborhood_equals(id))
                        return null;
                return address_manager;
            }
            else
            {
                error(@"Unexpected class $(caller.get_type().name())");
            }
        }
    }

    class MyServerErrorHandler : Object, zcd.ModRpc.IRpcErrorHandler
    {
        public void error_handler(Error e)
        {
            error(@"error_handler: $(e.message)");
        }
    }

    zcd.IZcdTasklet zcd_tasklet;
    Netsukuku.INtkdTasklet ntkd_tasklet;
    int main(string[] args)
    {
        if (args.length < 2) error(@"usage: $(args[0]) nic [nics...]");

        // Initialize tasklet system
        MyTaskletSystem.init();
        zcd_tasklet = MyTaskletSystem.get_zcd();
        ntkd_tasklet = MyTaskletSystem.get_ntkd();

        Time n = Time.local(time_t());
        print(@"$(n)\n");
        try {
            CommandResult com_ret = Tasklet.exec_command(@"sysctl net.ipv4.conf.all.rp_filter=0");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.cmderr)\n");
            com_ret = Tasklet.exec_command(@"sysctl -n net.ipv4.conf.all.rp_filter");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.cmderr)\n");
            if (com_ret.cmdout != "0\n")
                error(@"Failed to unset net.ipv4.conf.all.rp_filter '$(com_ret.cmdout)'\n");
        } catch (SpawnError e) {error("Unable to spawn a command");}
        try {
            CommandResult com_ret = Tasklet.exec_command(@"sysctl net.ipv4.ip_forward=1");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.cmderr)\n");
            com_ret = Tasklet.exec_command(@"sysctl -n net.ipv4.ip_forward");
            if (com_ret.exit_status != 0)
                error(@"$(com_ret.cmderr)\n");
            if (com_ret.cmdout != "1\n")
                error(@"Failed to set net.ipv4.ip_forward '$(com_ret.cmdout)'\n");
        } catch (SpawnError e) {error("Unable to spawn a command");}
        // generate my nodeID on network 1
        INeighborhoodNodeID id = new MyNodeID(1);

        // Initialize known serializable classes
        typeof(MyNodeID).class_peek();
        typeof(UnicastID).class_peek();
        typeof(BroadcastID).class_peek();
        // Pass tasklet system to ModRpc (and ZCD)
        zcd.ModRpc.init_tasklet_system(zcd_tasklet);
        // Pass tasklet system to module neighborhood
        NeighborhoodManager.init(ntkd_tasklet);

        {
            MyServerDelegate dlg = new MyServerDelegate(id);
            MyServerErrorHandler err = new MyServerErrorHandler();

            // Handle for TCP
            zcd.IZcdTaskletHandle t_tcp;
            // Handles for UDP
            ArrayList<zcd.IZcdTaskletHandle> t_udp_list = new ArrayList<zcd.IZcdTaskletHandle>();

            // start listen TCP
            t_tcp = Netsukuku.ModRpc.tcp_listen(dlg, err, ntkd_port);

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
                    print(@"Added arc with $(arc.i_neighborhood_mac), RTT $(arc.i_neighborhood_cost)\n");
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
                    print(@"Changed arc with $(arc.i_neighborhood_mac), RTT $(arc.i_neighborhood_cost)\n");
                }
            );

            foreach (string dev in args[1:args.length])
            {
                try {
                    CommandResult com_ret = Tasklet.exec_command(@"sysctl net.ipv4.conf.$(dev).rp_filter=0");
                    if (com_ret.exit_status != 0)
                        error(@"$(com_ret.cmderr)\n");
                    com_ret = Tasklet.exec_command(@"sysctl -n net.ipv4.conf.$(dev).rp_filter");
                    if (com_ret.exit_status != 0)
                        error(@"$(com_ret.cmderr)\n");
                    if (com_ret.cmdout != "0\n")
                        error(@"Failed to unset net.ipv4.conf.$(dev).rp_filter '$(com_ret.cmdout)'\n");
                } catch (SpawnError e) {error("Unable to spawn a command");}
                // start listen UDP on dev
                t_udp_list.add(Netsukuku.ModRpc.udp_listen(dlg, err, ntkd_port, dev));
                // prepare a NIC and run monitor
                string my_mac = macgetter.get_mac(dev).up();
                MyNetworkInterface nic = new MyNetworkInterface(dev, my_mac);
                // run monitor
                address_manager.neighborhood_manager.start_monitor(nic);
                print(@"Monitoring dev $(nic.i_neighborhood_dev), MAC $(nic.i_neighborhood_mac)\n");
            }

            // register handlers for SIGINT and SIGTERM to exit
            Posix.signal(Posix.SIGINT, safe_exit);
            Posix.signal(Posix.SIGTERM, safe_exit);
            // Main loop
            while (true)
            {
                zcd_tasklet.ms_wait(100);
                if (do_me_exit) break;
            }
            address_manager.neighborhood_manager.stop_monitor_all();
            // here address_manager.neighborhood_manager should be destroyed but it doesnt.
            address_manager.neighborhood_manager = null;
            address_manager = null;

            foreach (zcd.IZcdTaskletHandle t_udp in t_udp_list) t_udp.kill();
            t_tcp.kill();
        }
        zcd_tasklet.ms_wait(100);
        MyTaskletSystem.kill();
        return 0;
    }

    bool do_me_exit = false;
    void safe_exit(int sig)
    {
        // We got here because of a signal. Quick processing.
        do_me_exit = true;
    }
}
