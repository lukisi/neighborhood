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

namespace Netsukuku
{
    // in ntkdrpc  INeighborhoodNodeID

    public errordomain NeighborhoodGetRttError {
        GENERIC
    }

    public interface INeighborhoodNetworkInterface : Object
    {
        public abstract string i_neighborhood_dev {get;}
        public abstract string i_neighborhood_mac {get;}
        public abstract uint16 expect_pong(string s, INtkdChannel ch);
        public abstract uint16 expect_ping(string s, uint16 peer_port);
        public abstract long send_ping(string s, uint16 peer_port, INtkdChannel ch) throws NeighborhoodGetRttError;
        public abstract long measure_rtt(string peer_addr, string peer_mac, string my_addr) throws NeighborhoodGetRttError;
    }

    public interface INeighborhoodArc : Object
    {
        public abstract INeighborhoodNodeID i_neighborhood_neighbour_id {get;}
        public abstract string i_neighborhood_mac {get;}
        public abstract long i_neighborhood_cost {get;}
        public abstract INeighborhoodNetworkInterface i_neighborhood_nic {get;}
        public abstract bool i_neighborhood_comes_from(zcd.ModRpc.CallerInfo rpc_caller);
    }

    internal class NeighborhoodRealArc : Object, INeighborhoodArc
    {
        private INeighborhoodNodeID _neighbour_id;
        private string _mac;
        private string _nic_addr;
        private long _cost;
        private INeighborhoodNetworkInterface _my_nic;
        public bool available;

        public NeighborhoodRealArc(INeighborhoodNodeID neighbour_id,
                       string mac,
                       string nic_addr,
                       INeighborhoodNetworkInterface my_nic)
        {
            _neighbour_id = neighbour_id;
            _mac = mac;
            _nic_addr = nic_addr;
            _my_nic = my_nic;
            available = false;
        }

        public INeighborhoodNetworkInterface my_nic {
            get {
                return _my_nic;
            }
        }

        public string nic_addr {
            get {
                return _nic_addr;
            }
        }

        public void set_cost(long cost)
        {
            _cost = cost;
            available = true;
        }

        /* Public interface INeighborhoodArc
         */

        public bool i_neighborhood_comes_from(zcd.ModRpc.CallerInfo rpc_caller)
        {
            if (rpc_caller is ModRpc.UnicastCallerInfo)
            {
                return _nic_addr == (rpc_caller as ModRpc.UnicastCallerInfo).peer_address;
            }
            else if (rpc_caller is ModRpc.BroadcastCallerInfo)
            {
                return _nic_addr == (rpc_caller as ModRpc.BroadcastCallerInfo).peer_address;
            }
            else if (rpc_caller is zcd.ModRpc.TcpCallerInfo)
            {
                return _nic_addr == (rpc_caller as zcd.ModRpc.TcpCallerInfo).peer_address;
            }
            else return false;
        }

        public INeighborhoodNodeID i_neighborhood_neighbour_id {
            get {
                return _neighbour_id;
            }
        }

        public string i_neighborhood_mac {
            get {
                return _mac;
            }
        }

        public long i_neighborhood_cost {
            get {
                return _cost;
            }
        }

        public INeighborhoodNetworkInterface i_neighborhood_nic {
            get {
                return _my_nic;
            }
        }
    }

    public interface INeighborhoodMissingArcHandler : Object
    {
        public abstract void i_neighborhood_missing(INeighborhoodArc arc);
    }

    /* This interface is implemented by an object passed to the Neighbor manager
     * which uses it to actually obtain a stub to send messages to other nodes.
     */
    public interface INeighborhoodStubFactory : Object
    {
        public abstract IAddressManagerStub
                        i_neighborhood_get_broadcast(
                            BroadcastID bcid,
                            Gee.Collection<string> devs,
                            zcd.ModRpc.IAckCommunicator? ack_com=null
                        );

        public  IAddressManagerStub
                i_neighborhood_get_broadcast_to_dev(
                    BroadcastID bcid,
                    string dev,
                    zcd.ModRpc.IAckCommunicator? ack_com=null
                )
        {
            var _devs = new ArrayList<string>();
            _devs.add(dev);
            return i_neighborhood_get_broadcast(bcid, _devs, ack_com);
        }

        public abstract IAddressManagerStub
                        i_neighborhood_get_unicast(
                            UnicastID ucid,
                            string dev,
                            bool wait_reply=true
                        );

        public abstract IAddressManagerStub
                        i_neighborhood_get_tcp(
                            string dest,
                            bool wait_reply=true
                        );
    }

    /* This interface is implemented by an object passed to the Neighbor manager
     * which uses it to manage addresses and routes of the O.S. (specifically in
     * order to have a fixed address for each NIC and be able to contact via TCP
     * its neighbors with their fixed addresses)
     */
    public interface INeighborhoodIPRouteManager : Object
    {
        public abstract void i_neighborhood_add_address(
                            string my_addr,
                            string my_dev
                        );

        public abstract void i_neighborhood_add_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        );

        public abstract void i_neighborhood_remove_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        );

        public abstract void i_neighborhood_remove_address(
                            string my_addr,
                            string my_dev
                        );
    }

    internal INtkdTasklet tasklet;
    public class NeighborhoodManager : Object, INeighborhoodManagerSkeleton
    {
        public static void init(INtkdTasklet _tasklet)
        {
            // Register serializable types internal to the module.
            // typeof(Xxx).class_peek();
            tasklet = _tasklet;
        }

        public NeighborhoodManager(INeighborhoodNodeID my_id,
                                   int max_arcs,
                                   INeighborhoodStubFactory stub_factory,
                                   INeighborhoodIPRouteManager ip_mgr)
        {
            this.my_id = my_id;
            this.max_arcs = max_arcs;
            this.stub_factory = stub_factory;
            this.ip_mgr = ip_mgr;
            nics = new HashMap<string, INeighborhoodNetworkInterface>();
            local_addresses = new HashMap<string, string>();
            monitoring_devs = new HashMap<string, INtkdTaskletHandle>();
            arcs = new ArrayList<NeighborhoodRealArc>();
            monitoring_arcs = new HashMap<NeighborhoodRealArc, INtkdTaskletHandle>();
        }

        private INeighborhoodNodeID my_id;
        private int max_arcs;
        private INeighborhoodStubFactory stub_factory;
        private INeighborhoodIPRouteManager ip_mgr;
        private HashMap<string, INeighborhoodNetworkInterface> nics;
        private HashMap<string, string> local_addresses;
        private HashMap<string, INtkdTaskletHandle> monitoring_devs;
        private ArrayList<NeighborhoodRealArc> arcs;
        private HashMap<NeighborhoodRealArc, INtkdTaskletHandle> monitoring_arcs;

        // Signals:
        // New arc formed.
        public signal void arc_added(INeighborhoodArc arc);
        // An arc removed.
        public signal void arc_removed(INeighborhoodArc arc);
        // An arc changed its cost.
        public signal void arc_changed(INeighborhoodArc arc);

        public void start_monitor(INeighborhoodNetworkInterface nic)
        {
            string dev = nic.i_neighborhood_dev;
            string mac = nic.i_neighborhood_mac;
            // is dev or mac already present?
            foreach (INeighborhoodNetworkInterface present in nics.values)
            {
                if (present.i_neighborhood_dev == dev && present.i_neighborhood_mac == mac) return;
                assert(present.i_neighborhood_dev != dev);
                assert(present.i_neighborhood_mac != mac);
            }
            // generate a random IP for this nic
            int i2 = Random.int_range(0, 255);
            int i3 = Random.int_range(0, 255);
            string local_address = @"169.254.$(i2).$(i3)";
            ip_mgr.i_neighborhood_add_address(local_address, dev);
            // start monitor
            MonitorRunTasklet ts = new MonitorRunTasklet();
            ts.mgr = this;
            ts.nic = nic;
            ts.local_address = local_address;
            INtkdTaskletHandle t = tasklet.spawn(ts);
            // private members
            monitoring_devs[dev] = t;
            nics[dev] = nic;
            local_addresses[dev] = local_address;
        }

        public void stop_monitor(string dev)
        {
            // search nic
            if (! nics.has_key(dev)) return;
            // nic found
            INeighborhoodNetworkInterface nic = nics[dev];
            // remove arcs on this nic
            ArrayList<NeighborhoodRealArc> todel = new ArrayList<NeighborhoodRealArc>();
            foreach (NeighborhoodRealArc arc in arcs) if (arc.my_nic == nic) todel.add(arc);
            foreach (NeighborhoodRealArc arc in todel)
            {
                remove_my_arc(arc);
            }
            // stop monitor
            monitoring_devs[dev].kill();
            // remove local address
            string local_address = local_addresses[dev];
            ip_mgr.i_neighborhood_remove_address(local_address, dev);
            // cleanup private members
            monitoring_devs.unset(dev);
            nics.unset(dev);
            local_addresses.unset(dev);
        }

        private bool is_monitoring(string dev)
        {
            return monitoring_devs.has_key(dev);
        }

        private INeighborhoodNetworkInterface? get_monitoring_interface_from_dev(string dev)
        {
            if (is_monitoring(dev)) return nics[dev];
            return null;
        }

        private INeighborhoodNetworkInterface? get_monitoring_interface_from_localaddr(string addr)
        {
            string dev = "";
            foreach (string d in local_addresses.keys)
                if (local_addresses[d] == addr) dev = d;
            if (dev != "")
            {
                if (is_monitoring(dev)) return nics[dev];
            }
            return null;
        }

        /* Runs in a tasklet foreach device
         */
        private class MonitorRunTasklet : Object, INtkdTaskletSpawnable
        {
            public NeighborhoodManager mgr;
            public INeighborhoodNetworkInterface nic;
            public string local_address;
            public void * func()
            {
                while (true)
                {
                    try
                    {
                        IAddressManagerStub bc =
                            mgr.get_stub_broadcast_to_dev(nic.i_neighborhood_dev);
                            // nothing to do for missing ACK from known neighbours
                            // because this message would be not important for them anyway.
                        bc.neighborhood_manager.here_i_am(mgr.my_id, nic.i_neighborhood_mac, local_address);
                    } catch (zcd.ModRpc.StubError e) {
                        warning("Neighborhood.monitor_run: " +
                        @"StubError '$(e.message)' while sending in broadcast to $(nic.i_neighborhood_mac).");
                    } catch (zcd.ModRpc.DeserializeError e) {
                        warning("Neighborhood.monitor_run: " +
                        @"DeserializeError '$(e.message)' while sending in broadcast to $(nic.i_neighborhood_mac).");
                    }
                    tasklet.ms_wait(60000);
                }
            }
        }

        public bool is_unicast_for_me(UnicastID ucid, string dev)
        {
            // Do I manage this dev?
            if (! is_monitoring(dev)) return false;
            // Is it me?
            if (nics[dev].i_neighborhood_mac != ucid.mac) return false;
            if (ucid.nodeid == null) return false;
            return my_id.i_neighborhood_equals(ucid.nodeid);
        }

        public bool is_broadcast_for_me(BroadcastID bcid, string dev)
        {
            // Do I manage this dev?
            if (! is_monitoring(dev)) return false;
            // Am I to ignore?
            if (bcid.ignore_nodeid == null) return true;
            return ! my_id.i_neighborhood_equals(bcid.ignore_nodeid);
        }

        private void start_arc_monitor(NeighborhoodRealArc arc)
        {
            ArcMonitorRunTasklet ts = new ArcMonitorRunTasklet();
            ts.mgr = this;
            ts.arc = arc;
            INtkdTaskletHandle t = tasklet.spawn(ts);
            monitoring_arcs[arc] = t;
        }

        private void stop_arc_monitor(NeighborhoodRealArc arc)
        {
            if (! monitoring_arcs.has_key(arc)) return;
            monitoring_arcs[arc].kill();
            monitoring_arcs.unset(arc);
        }

        /* Runs in a tasklet foreach arc
         */
        private class ArcMonitorRunTasklet : Object, INtkdTaskletSpawnable
        {
            public NeighborhoodManager mgr;
            public NeighborhoodRealArc arc;
            public void * func()
            {
                try
                {
                    long last_rtt = -1;
                    while (true)
                    {
                        long rtt;
                        try
                        {
                            rtt = arc.my_nic.measure_rtt(
                                arc.nic_addr,
                                arc.i_neighborhood_mac,
                                mgr.local_addresses[arc.my_nic.i_neighborhood_dev]);
                            // Use a tcp_client to check the neighbor.
                            // It can throw StubError.
                            IAddressManagerStub tc = mgr.get_stub_tcp(arc);
                            tc.neighborhood_manager.nop();
                        }
                        catch (NeighborhoodGetRttError e)
                        {
                            // failed getting the RTT.
                            // Will try with the other method.
                            try
                            {
                                int guid = Random.int_range(1000000, 9999999);
                                string s_guid = @"$(guid)";
                                INtkdChannel ch = tasklet.get_channel();
                                // Use the INeighborhoodNetworkInterface to prepare to
                                // receive the pong.
                                uint16 my_port = arc.my_nic.expect_pong(s_guid, ch);
                                // Use a tcp_client to prepare the neighbor.
                                // It can throw StubError or NeighborhoodUnmanagedDeviceError.
                                IAddressManagerStub tc = mgr.get_stub_tcp(arc);
                                uint16 peer_port = tc.neighborhood_manager.expect_ping(s_guid, my_port);
                                // Use the INeighborhoodNetworkInterface to send the ping and get the
                                // RTT. It can throw NeighborhoodGetRttError.
                                rtt = arc.my_nic.send_ping(s_guid, peer_port, ch);
                            }
                            catch (NeighborhoodGetRttError e)
                            {
                                // failed getting the RTT
                                // Since UDP is not reliable, this is ignorable. Try again soon.
                                tasklet.ms_wait(1000);
                                continue;
                            }
                        }

                        // If all goes right, the arc is still valid and we have the
                        // cost up-to-date.
                        if (last_rtt == -1)
                        {
                            // First cost measure
                            last_rtt = rtt;
                            arc.set_cost(last_rtt);
                            // signal new arc
                            mgr.arc_added(arc);
                        }
                        else
                        {
                            // Following cost measures
                            long delta_rtt = rtt - last_rtt;
                            if (delta_rtt > 0) delta_rtt = delta_rtt / 10;
                            if (delta_rtt < 0) delta_rtt = delta_rtt / 3;
                            last_rtt = last_rtt + delta_rtt;
                            if (last_rtt < arc.i_neighborhood_cost * 0.5 ||
                                last_rtt > arc.i_neighborhood_cost * 2)
                            {
                                arc.set_cost(last_rtt);
                                // signal changed arc
                                mgr.arc_changed(arc);
                            }
                        }

                        // wait a random from 28 to 30 secs
                        tasklet.ms_wait(Random.int_range(28000, 30000));
                    }
                } catch (zcd.ModRpc.StubError e) {
                    // failed sending the GUID (or checking with nop)
                    // Since it was sent via TCP this arc is not working.
                    mgr.remove_my_arc(arc);
                } catch (zcd.ModRpc.DeserializeError e) {
                    // failed deserialization
                    warning(@"Call to expect_ping: got DeserializeError: $(e.message)");
                    // Failed prepare_ping. This arc is not working.
                    mgr.remove_my_arc(arc);
                } catch (NeighborhoodUnmanagedDeviceError e) {
                    debug(@"Call to expect_ping: got NeighborhoodUnmanagedDeviceError: $(e.message)");
                    // Failed prepare_ping. This arc is not working.
                    mgr.remove_my_arc(arc);
                }
                return null;
            }
        }

        public void remove_my_arc(INeighborhoodArc arc, bool do_tell=true)
        {
            if (!(arc is NeighborhoodRealArc)) return;
            NeighborhoodRealArc _arc = (NeighborhoodRealArc)arc;
            // do just once
            if (! arcs.contains(_arc)) return;
            // remove the fixed address of the neighbor
            ip_mgr.i_neighborhood_remove_neighbor(
                        /*my_addr*/ local_addresses[_arc.my_nic.i_neighborhood_dev],
                        /*my_dev*/ _arc.my_nic.i_neighborhood_dev,
                        /*neighbor_addr*/ _arc.nic_addr);
            // remove the arc
            arcs.remove(_arc);
            // try and tell the neighbour to do the same
            if (do_tell)
            {
                // use UDP, we just removed the local_address of the neighbor
                var uc = get_stub_unicast(arc, false);
                try {
                    uc.neighborhood_manager
                        .remove_arc(my_id,
                                   _arc.my_nic.i_neighborhood_mac,
                                   local_addresses[_arc.my_nic.i_neighborhood_dev]);
                } catch (zcd.ModRpc.StubError e) {
                } catch (zcd.ModRpc.DeserializeError e) {
                    warning(@"Call to remove_arc: got DeserializeError: $(e.message)");
                }
            }
            // signal removed arc
            if (_arc.available) arc_removed(arc);
            // stop monitoring the cost of the arc
            stop_arc_monitor(_arc);
        }

        /* Expose current valid arcs
         */
        public Gee.List<INeighborhoodArc> current_arcs()
        {
            var ret = new ArrayList<INeighborhoodArc>();
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available) ret.add(arc);
            return ret;
        }

        /* Get a client to call a unicast remote method via TCP
         */
        public
        IAddressManagerStub
        get_stub_tcp(INeighborhoodArc arc, bool wait_reply=true)
        {
            NeighborhoodRealArc _arc = (NeighborhoodRealArc)arc;
            var uc = stub_factory.i_neighborhood_get_tcp(_arc.nic_addr, wait_reply);
            return uc;
        }

        /* Get a client to call a unicast remote method via UDP
         */
        private
        IAddressManagerStub
        get_stub_unicast(INeighborhoodArc arc, bool wait_reply=true)
        {
            NeighborhoodRealArc _arc = (NeighborhoodRealArc)arc;
            UnicastID ucid = new UnicastID(_arc.i_neighborhood_mac, _arc.i_neighborhood_neighbour_id);
            var uc = stub_factory.i_neighborhood_get_unicast(ucid, _arc.my_nic.i_neighborhood_dev, wait_reply);
            return uc;
        }

        /* Internal method: current arcs for a given broadcast message
         */
        private Gee.List<INeighborhoodArc> current_arcs_for_broadcast(
                            BroadcastID bcid,
                            Gee.Collection<string> devs)
        {
            var ret = new ArrayList<INeighborhoodArc>();
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available)
            {
                // test arc against bcid (e.g. ignore_neighbour)
                if (bcid.ignore_nodeid != null)
                    if (arc.i_neighborhood_neighbour_id.i_neighborhood_equals(bcid.ignore_nodeid)) continue;
                // test arc against devs.
                if (! (arc.i_neighborhood_nic.i_neighborhood_dev in devs)) continue;
                // This should receive
                ret.add(arc);
            }
            return ret;
        }

        /* The instance of this class is created when the stub factory is invoked to
         * obtain a stub for broadcast.
         */
        private class NeighborhoodAcknowledgementsCommunicator : Object, zcd.ModRpc.IAckCommunicator
        {
            public BroadcastID bcid;
            public Gee.List<string> devs;
            public NeighborhoodManager mgr;
            public INeighborhoodMissingArcHandler missing_handler;
            public Gee.List<INeighborhoodArc> lst_expected;

            public NeighborhoodAcknowledgementsCommunicator(BroadcastID bcid,
                                Gee.Collection<string> devs,
                                NeighborhoodManager mgr,
                                INeighborhoodMissingArcHandler missing_handler,
                                Gee.List<INeighborhoodArc> lst_expected)
            {
                this.bcid = bcid;
                this.devs = new ArrayList<string>();
                this.devs.add_all(devs);
                this.mgr = mgr;
                this.missing_handler = missing_handler;
                this.lst_expected = new ArrayList<INeighborhoodArc>();
                this.lst_expected.add_all(lst_expected);
            }

            public void process_macs_list(Gee.List<string> responding_macs)
            {
                // intersect with current ones now
                Gee.List<INeighborhoodArc> lst_expected_now = mgr.current_arcs_for_broadcast(bcid, devs);
                Gee.List<INeighborhoodArc> lst_expected_intersect = new ArrayList<INeighborhoodArc>();
                foreach (var el in lst_expected)
                    if (el in lst_expected_now)
                        lst_expected_intersect.add(el);
                lst_expected = lst_expected_intersect;
                // prepare a list of missed arcs.
                var lst_missed = new ArrayList<INeighborhoodArc>();
                foreach (INeighborhoodArc expected in lst_expected)
                    if (! (expected.i_neighborhood_mac in responding_macs))
                        lst_missed.add(expected);
                // foreach missed arc launch in a tasklet
                // the 'missing' callback.
                foreach (INeighborhoodArc missed in lst_missed)
                {
                    ActOnMissingTasklet ts = new ActOnMissingTasklet();
                    ts.missing_handler = missing_handler;
                    ts.missed = missed;
                    tasklet.spawn(ts);
                }
            }

            private class ActOnMissingTasklet : Object, INtkdTaskletSpawnable
            {
                public INeighborhoodMissingArcHandler missing_handler;
                public INeighborhoodArc missed;
                public void * func()
                {
                    missing_handler.i_neighborhood_missing(missed);
                    return null;
                }
            }
        }

        /* Get a client to call a broadcast remote method
         */
        public
        IAddressManagerStub
        get_stub_broadcast(INeighborhoodMissingArcHandler? missing_handler=null,
                      INeighborhoodNodeID? ignore_neighbour=null)
        {
            var bcid = new BroadcastID(ignore_neighbour);
            IAddressManagerStub ret;
            if (missing_handler == null)
                ret = stub_factory.i_neighborhood_get_broadcast(bcid, nics.keys);
            else
            {
                Gee.List<INeighborhoodArc> lst_expected = current_arcs_for_broadcast(bcid, nics.keys);
                ret = stub_factory.i_neighborhood_get_broadcast(bcid, nics.keys,
                         new NeighborhoodAcknowledgementsCommunicator(bcid, nics.keys, this, missing_handler, lst_expected));
            }
            return ret;
        }

        /* Get a client to call a broadcast remote method to one nic
         */
        public
        IAddressManagerStub
        get_stub_broadcast_to_dev(string dev,
                             INeighborhoodMissingArcHandler? missing_handler=null,
                             INeighborhoodNodeID? ignore_neighbour=null)
        {
            var bcid = new BroadcastID(ignore_neighbour);
            IAddressManagerStub ret;
            if (missing_handler == null)
                ret = stub_factory.i_neighborhood_get_broadcast_to_dev(bcid, dev);
            else
            {
                Gee.List<string> devs = new ArrayList<string>();
                devs.add(dev);
                Gee.List<INeighborhoodArc> lst_expected = current_arcs_for_broadcast(bcid, devs);
                ret = stub_factory.i_neighborhood_get_broadcast_to_dev(bcid, dev,
                         new NeighborhoodAcknowledgementsCommunicator(bcid, devs, this, missing_handler, lst_expected));
            }
            return ret;
        }

        /* Remotable methods
         */

        public void here_i_am(INeighborhoodNodeID its_id, string mac, string nic_addr, zcd.ModRpc.CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            // This call has to be made in UDP broadcast, else ignore it.
            if (! (_rpc_caller is BroadcastCallerInfo)) return;
            BroadcastCallerInfo rpc_caller = (BroadcastCallerInfo)_rpc_caller;
            // This is called in broadcast. Maybe it's me. It should not be the case.
            if (its_id.i_neighborhood_equals(my_id)) return;
            // It's a neighbour. The message comes from my_nic and its mac is mac.
            string my_dev = rpc_caller.dev;
            INeighborhoodNetworkInterface? my_nic
                    = get_monitoring_interface_from_dev(my_dev);
            if (my_nic == null)
            {
                warning(@"Neighborhood.here_i_am: $(my_dev) is not being monitored");
                return;
            }
            // Did I already meet it? Did I already make an arc?
            foreach (NeighborhoodRealArc arc in arcs)
            {
                if (arc.i_neighborhood_neighbour_id.i_neighborhood_equals(its_id))
                {
                    // I already met him. Same MAC and same NIC?
                    if (arc.i_neighborhood_mac == mac && arc.my_nic == my_nic)
                    {
                        // I already made this arc. Ignore this message.
                        return;
                    }
                    if (arc.i_neighborhood_mac == mac || arc.my_nic == my_nic)
                    {
                        // Not willing to make a new arc on same collision
                        // domain. Ignore this message.
                        return;
                    }
                    // Not this same arc. Continue searching for a previous arc.
                    continue;
                }
            }
            // Do I have too many arcs?
            if (arcs.size >= max_arcs)
            {
                // Ignore message.
                return;
            }
            // We can try and make a new arc.
            // Since we haven't yet an arc with this node, we cannot use TCP.
            // We use unicast UDP, if it fails not a big problem, we'll retry soon.
            // UnicastID is such that if I send a message to it, the message will
            // be elaborated by the neighbor only once, when received through
            // the interface of this arc; hence, UnicastID will contain
            // as an identification:
            //  * INeighborhoodNodeID
            //  * mac
            UnicastID ucid = new UnicastID(mac, its_id);
            var uc = stub_factory.i_neighborhood_get_unicast(ucid, my_dev);
            bool refused = false;
            bool failed = false;
            try
            {
                uc.neighborhood_manager.request_arc(my_id, my_nic.i_neighborhood_mac, local_addresses[my_dev]);
            }
            catch (NeighborhoodRequestArcError e)
            {
                // arc refused
                refused = true;
            }
            catch (zcd.ModRpc.StubError e)
            {
                // failed
                failed = true;
            }
            catch (zcd.ModRpc.DeserializeError e)
            {
                warning(@"Call to request_arc: got DeserializeError: $(e.message)");
                // failed
                failed = true;
            }
            if (! (refused || failed))
            {
                // Let's make an arc
                NeighborhoodRealArc new_arc = new NeighborhoodRealArc(its_id, mac, nic_addr, my_nic);
                arcs.add(new_arc);
                // add the fixed address of the neighbor
                ip_mgr.i_neighborhood_add_neighbor(
                            /*my_addr*/ local_addresses[my_dev],
                            /*my_dev*/ my_dev,
                            /*neighbor_addr*/ nic_addr);
                // start periodical ping
                start_arc_monitor(new_arc);
            }
        }

        public void request_arc(INeighborhoodNodeID its_id, string mac, string nic_addr,
                                zcd.ModRpc.CallerInfo? _rpc_caller=null) throws NeighborhoodRequestArcError
        {
            debug("request_arc: start");
            assert(_rpc_caller != null);
            // This call has to be made in UDP unicast, else ignore it.
            if (! (_rpc_caller is UnicastCallerInfo)) return;
            UnicastCallerInfo rpc_caller = (UnicastCallerInfo)_rpc_caller;
            // The message comes from my_nic and its mac is mac.
            // TODO check that nic_addr is in 169.254.0.0/10 class.
            // TODO check that nic_addr is not conflicting with mine or my neighbors' ones.
            string my_dev = rpc_caller.dev;
            debug(@"request_arc: through $(my_dev)");
            INeighborhoodNetworkInterface? my_nic
                    = get_monitoring_interface_from_dev(my_dev);
            if (my_nic == null)
            {
                warning(@"Neighborhood.request_arc: $(my_dev) is not being monitored");
                return;
            }
            // Did I already make an arc?
            foreach (NeighborhoodRealArc arc in arcs)
            {
                if (arc.i_neighborhood_neighbour_id.i_neighborhood_equals(its_id))
                {
                    // I already met him. Same MAC and same NIC?
                    if (arc.i_neighborhood_mac == mac && arc.my_nic == my_nic)
                    {
                        // I already made this arc. Confirm arc.
                        warning("Neighborhood.request_arc: " +
                        @"Already got $(mac) on $(my_nic.i_neighborhood_mac)");
                        return;
                    }
                    if (arc.i_neighborhood_mac == mac || arc.my_nic == my_nic)
                    {
                        // Not willing to make a new arc on same collision
                        // domain.
                        throw new NeighborhoodRequestArcError.TWO_ARCS_ON_COLLISION_DOMAIN(
                        @"Refusing $(mac) on $(my_nic.i_neighborhood_mac).");
                    }
                    // Not this same arc. Continue searching for a previous arc.
                    continue;
                }
            }
            // Do I have too many arcs?
            if (arcs.size >= max_arcs)
            {
                // Refuse.
                throw new NeighborhoodRequestArcError.TOO_MANY_ARCS(
                @"Refusing $(mac) because too many arcs.");
            }
            // Let's make an arc
            NeighborhoodRealArc new_arc = new NeighborhoodRealArc(its_id, mac, nic_addr, my_nic);
            arcs.add(new_arc);
            // add the fixed address of the neighbor
            ip_mgr.i_neighborhood_add_neighbor(
                        /*my_addr*/ local_addresses[my_dev],
                        /*my_dev*/ my_dev,
                        /*neighbor_addr*/ nic_addr);
            // start periodical ping
            start_arc_monitor(new_arc);
        }

        public uint16 expect_ping(string guid, uint16 peer_port,
                                  zcd.ModRpc.CallerInfo? _rpc_caller=null) throws NeighborhoodUnmanagedDeviceError
        {
            assert(_rpc_caller != null);
            // This call accepts UDP unicast and TCP, else ignore it.
            INeighborhoodNetworkInterface my_nic = null;
            string search_term;
            if (_rpc_caller is ModRpc.BroadcastCallerInfo)
            {
                string msg = "not answering to broadcast";
                warning(@"Neighborhood.expect_ping: $(msg)");
                throw new NeighborhoodUnmanagedDeviceError.GENERIC(msg);
            }
            if (_rpc_caller is ModRpc.UnicastCallerInfo)
            {
                ModRpc.UnicastCallerInfo rpc_caller = (ModRpc.UnicastCallerInfo)_rpc_caller;
                search_term = @"dev $(rpc_caller.dev)";
                my_nic = get_monitoring_interface_from_dev(rpc_caller.dev);
            }
            else if (_rpc_caller is zcd.ModRpc.TcpCallerInfo)
            {
                zcd.ModRpc.TcpCallerInfo rpc_caller = (zcd.ModRpc.TcpCallerInfo)_rpc_caller;
                search_term = @"addr $(rpc_caller.my_address)";
                my_nic = get_monitoring_interface_from_localaddr(rpc_caller.my_address);
            }
            else
            {
                string msg = @"not answering to $(_rpc_caller.get_type().name())";
                warning(@"Neighborhood.expect_ping: $(msg)");
                throw new NeighborhoodUnmanagedDeviceError.GENERIC(msg);
            }
            // The message comes from my_nic.
            if (my_nic == null)
            {
                string msg = @"not found handled interface for $(search_term)";
                warning(@"Neighborhood.expect_ping: $(msg)");
                throw new NeighborhoodUnmanagedDeviceError.GENERIC(msg);
            }
            // Use the INeighborhoodNetworkInterface to prepare to
            // receive the ping.
            return my_nic.expect_ping(guid, peer_port);
        }

        public void remove_arc(INeighborhoodNodeID its_id, string mac, string nic_addr,
                                zcd.ModRpc.CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            // This call has to be made in UDP unicast, else ignore it.
            if (! (_rpc_caller is UnicastCallerInfo)) return;
            UnicastCallerInfo rpc_caller = (UnicastCallerInfo)_rpc_caller;
            // The message comes from my_nic.
            string my_dev = rpc_caller.dev;
            INeighborhoodNetworkInterface? my_nic
                    = get_monitoring_interface_from_dev(my_dev);
            if (my_nic == null)
            {
                string msg = @"not found handled interface for dev $(my_dev)";
                warning(@"Neighborhood.remove_arc: $(msg)");
                return;
            }
            // Have I that arc?
            foreach (NeighborhoodRealArc arc in arcs)
            {
                if (arc.i_neighborhood_neighbour_id.i_neighborhood_equals(its_id) &&
                    arc.i_neighborhood_mac == mac &&
                    arc.my_nic == my_nic)
                {
                    remove_my_arc(arc, false);
                    // the foreach would abort if I don't break
                    break;
                }
            }
        }

        public void nop(zcd.ModRpc.CallerInfo? caller = null)
        {
        }

        public void stop_monitor_all()
        {
            var copy_devs = new ArrayList<string>();
            copy_devs.add_all(monitoring_devs.keys);
            foreach (string dev in copy_devs)
            {
                stop_monitor(dev);
            }
        }

        ~NeighborhoodManager()
        {
            stop_monitor_all();
        }
    }
}
