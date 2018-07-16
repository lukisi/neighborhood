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

namespace Netsukuku.Neighborhood
{
    internal ITasklet tasklet;
    public class NeighborhoodManager : Object, INeighborhoodManagerSkeleton
    {
        public static void init(ITasklet _tasklet)
        {
            // Register serializable types internal to the module.
            typeof(NeighborhoodNodeID).class_peek();
            typeof(NodeID).class_peek();
            typeof(WholeNodeSourceID).class_peek();
            typeof(WholeNodeUnicastID).class_peek();
            typeof(EveryWholeNodeBroadcastID).class_peek();
            typeof(IdentityAwareSourceID).class_peek();
            typeof(IdentityAwareUnicastID).class_peek();
            typeof(IdentityAwareBroadcastID).class_peek();
            tasklet = _tasklet;
        }

        public static void init_rngen(IRandomNumberGenerator? rngen=null, uint32? seed=null)
        {
            PRNGen.init_rngen(rngen, seed);
        }

        public NeighborhoodManager(
                                   GetIdentitySkeletonFunc get_identity_skeleton,
                                   GetIdentitySkeletonSetFunc get_identity_skeleton_set,
                                   IAddressManagerSkeleton node_skeleton,
                                   int max_arcs,
                                   INeighborhoodStubFactory stub_factory,
                                   INeighborhoodIPRouteManager ip_mgr,
                                   owned NewLinklocalAddress new_linklocal_address)
        {
            this.get_identity_skeleton = get_identity_skeleton;
            this.get_identity_skeleton_set = get_identity_skeleton_set;
            this.node_skeleton = node_skeleton;
            this.my_id = new NeighborhoodNodeID();
            this.max_arcs = max_arcs;
            this.stub_factory = stub_factory;
            this.ip_mgr = ip_mgr;
            nics = new HashMap<string, INeighborhoodNetworkInterface>();
            local_addresses = new HashMap<string, string>();
            monitoring_devs = new HashMap<string, ITaskletHandle>();
            arcs = new ArrayList<NeighborhoodRealArc>();
            arcs_by_itsmac = new HashMap<string, ArrayList<NeighborhoodRealArc>>();
            arcs_by_itsll = new HashMap<string, ArrayList<NeighborhoodRealArc>>();
            arcs_by_itsnodeid = new HashMap<string, ArrayList<NeighborhoodRealArc>>();
            arcs_by_mydev_itsmac = new HashMap<string, HashMap<string, ArrayList<NeighborhoodRealArc>>>();
            arcs_by_mydev_itsll = new HashMap<string, HashMap<string, ArrayList<NeighborhoodRealArc>>>();
            arcs_by_mydev_itsnodeid = new HashMap<string, HashMap<string, ArrayList<NeighborhoodRealArc>>>();
            exported_arcs = new ArrayList<NeighborhoodRealArc>();
            monitoring_arcs = new HashMap<NeighborhoodRealArc, ITaskletHandle>();
            this.new_linklocal_address = (owned)new_linklocal_address;
        }

        private unowned GetIdentitySkeletonFunc get_identity_skeleton;
        private unowned GetIdentitySkeletonSetFunc get_identity_skeleton_set;
        private IAddressManagerSkeleton node_skeleton;
        private NeighborhoodNodeID my_id;
        private int max_arcs;
        private INeighborhoodStubFactory stub_factory;
        private INeighborhoodIPRouteManager ip_mgr;
        private HashMap<string, INeighborhoodNetworkInterface> nics;
        private HashMap<string, string> local_addresses;
        private HashMap<string, ITaskletHandle> monitoring_devs;
        private ArrayList<NeighborhoodRealArc> arcs;
        private HashMap<string, ArrayList<NeighborhoodRealArc>> arcs_by_itsmac;
        private HashMap<string, ArrayList<NeighborhoodRealArc>> arcs_by_itsll;
        private HashMap<string, ArrayList<NeighborhoodRealArc>> arcs_by_itsnodeid;
        private HashMap<string, HashMap<string, ArrayList<NeighborhoodRealArc>>> arcs_by_mydev_itsmac;
        private HashMap<string, HashMap<string, ArrayList<NeighborhoodRealArc>>> arcs_by_mydev_itsll;
        private HashMap<string, HashMap<string, ArrayList<NeighborhoodRealArc>>> arcs_by_mydev_itsnodeid;
        private ArrayList<NeighborhoodRealArc> exported_arcs;
        private HashMap<NeighborhoodRealArc, ITaskletHandle> monitoring_arcs;
        private NewLinklocalAddress new_linklocal_address;

        // Signals:
        // New address assigned to a NIC.
        public signal void nic_address_set(string dev, string address);
        // New arc formed.
        public signal void arc_added(INeighborhoodArc arc);
        // An arc is going to be removed.
        public signal void arc_removing(INeighborhoodArc arc, bool is_still_usable);
        // An arc removed.
        public signal void arc_removed(INeighborhoodArc arc);
        // An arc changed its cost.
        public signal void arc_changed(INeighborhoodArc arc);
        // Address removed from a NIC, no more handling.
        public signal void nic_address_unset(string dev, string address);

        public void start_monitor(INeighborhoodNetworkInterface nic)
        {
            string dev = nic.dev;
            string mac = nic.mac;
            // is dev or mac already present?
            foreach (INeighborhoodNetworkInterface present in nics.values)
            {
                if (present.dev == dev && present.mac == mac) return;
                assert(present.dev != dev);
                assert(present.mac != mac);
            }
            // get a new linklocal IP for this nic
            string local_address = new_linklocal_address();
            ip_mgr.add_address(local_address, dev);
            nic_address_set(dev, local_address);
            // start monitor
            MonitorRunTasklet ts = new MonitorRunTasklet();
            ts.mgr = this;
            ts.nic = nic;
            ts.local_address = local_address;
            ITaskletHandle t = tasklet.spawn(ts);
            // private members
            monitoring_devs[dev] = t;
            nics[dev] = nic;
            local_addresses[dev] = local_address;
            arcs_by_mydev_itsmac[dev] = new HashMap<string, ArrayList<NeighborhoodRealArc>>();
            arcs_by_mydev_itsll[dev] = new HashMap<string, ArrayList<NeighborhoodRealArc>>();
            arcs_by_mydev_itsnodeid[dev] = new HashMap<string, ArrayList<NeighborhoodRealArc>>();
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
            ip_mgr.remove_address(local_address, dev);
            nic_address_unset(dev, local_address);
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

        /* Runs in a tasklet foreach device
         */
        private class MonitorRunTasklet : Object, ITaskletSpawnable
        {
            public weak NeighborhoodManager mgr;
            public INeighborhoodNetworkInterface nic;
            public string local_address;
            public void * func()
            {
                while (true)
                {
                    try
                    {
                        IAddressManagerStub bc =
                            mgr.get_stub_for_broadcast_to_dev(nic.dev, local_address);
                            // nothing to do for missing ACK from known neighbours
                            // because this message would be not important for them anyway.
                        bc.neighborhood_manager.here_i_am(mgr.my_id, nic.mac, local_address);
                    } catch (StubError e) {
                        warning("Neighborhood.monitor_run: " +
                        @"StubError '$(e.message)' while sending in broadcast to $(nic.mac).");
                    } catch (DeserializeError e) {
                        warning("Neighborhood.monitor_run: " +
                        @"DeserializeError '$(e.message)' while sending in broadcast to $(nic.mac).");
                    }
                    tasklet.ms_wait(60000);
                }
            }
        }

        private void start_arc_monitor(NeighborhoodRealArc arc)
        {
            ArcMonitorRunTasklet ts = new ArcMonitorRunTasklet();
            ts.mgr = this;
            ts.arc = arc;
            ITaskletHandle t = tasklet.spawn(ts);
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
        private class ArcMonitorRunTasklet : Object, ITaskletSpawnable
        {
            public weak NeighborhoodManager mgr;
            public NeighborhoodRealArc arc;
            public void * func()
            {
                long last_rtt = -1;
                // arc should be exported, so the peer has the arc too.
                while (true)
                {
                    // Measure rtt
                    long rtt = -1;
                    string err_msg = "";
                    try
                    {
                        rtt = arc.my_nic.measure_rtt(
                            arc.neighbour_nic_addr,
                            arc.neighbour_mac,
                            arc.my_nic.dev,
                            mgr.local_addresses[arc.my_nic.dev]);
                    } catch (NeighborhoodGetRttError e) {
                        // Failed measure_rtt.
                        err_msg = e.message;
                    }

                    // Use a tcp_client to check the neighbor.
                    bool nop_check = false;
                    try
                    {
                        IAddressManagerStub tc = mgr.get_stub_whole_node_unicast(arc);
                        tc.neighborhood_manager.nop();
                        nop_check = true;
                    } catch (StubError e) {
                    } catch (DeserializeError e) {
                    }

                    if (! nop_check)
                    {
                        // This arc is not working.
                        mgr.remove_my_arc(arc, false);
                        return null;
                    }

                    if (rtt == -1)
                    {
                        // If the arc is still valid but we cant measure RTT, then
                        // inform the user.
                        warning(@"Neighborhood: A problem with measure_rtt($(arc.neighbour_nic_addr)): $(err_msg).");
                        // Finally, though, maintain the arc.
                    }
                    else
                    {
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
                            if (last_rtt < arc.cost * 0.5 ||
                                last_rtt > arc.cost * 2)
                            {
                                arc.set_cost(last_rtt);
                                // signal changed arc
                                mgr.arc_changed(arc);
                            }
                        }
                    }

                    // wait a random from 28 to 30 secs
                    tasklet.ms_wait(Random.int_range(28000, 30000));
                }
            }
        }

        /* Get name of NIC which has been assigned a certain address by this module.
         * It is used by the module's user to identify the interface where a TCP
         *  request has been received.
         */
        public string? get_dev_from_my_address(string my_address)
        {
            string? dev = null;
            foreach (string d in local_addresses.keys)
                if (local_addresses[d] == my_address) dev = d;
            return dev;
        }

        /* Expose current valid arcs
         */
        public Gee.List<INeighborhoodArc> current_arcs()
        {
            var ret = new ArrayList<INeighborhoodArc>();
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available) ret.add(arc);
            return ret;
        }

        /* Get root-dispatcher if the message is to be processed.
         */
        public IAddressManagerSkeleton?
        get_dispatcher(
            ISourceID _source_id,
            IUnicastID _unicast_id,
            string peer_address,
            string? dev)
        {
            if (_unicast_id is IdentityAwareUnicastID)
            {
                IdentityAwareUnicastID unicast_id = (IdentityAwareUnicastID)_unicast_id;
                if (dev != null) return null;
                if (! (_source_id is IdentityAwareSourceID)) return null;
                IdentityAwareSourceID source_id = (IdentityAwareSourceID)_source_id;
                NodeID identity_aware_unicast_id = unicast_id.id;
                NodeID identity_aware_source_id = source_id.id;
                return get_identity_skeleton(identity_aware_source_id, identity_aware_unicast_id, peer_address);
            }
            if (_unicast_id is WholeNodeUnicastID)
            {
                if (dev != null) return null;
                if (! (_source_id is WholeNodeSourceID)) return null;
                WholeNodeSourceID source_id = (WholeNodeSourceID)_source_id;
                NeighborhoodNodeID whole_node_source_id = source_id.id;
                foreach (NeighborhoodRealArc arc in arcs)
                {
                    if (arc.neighbour_nic_addr == peer_address &&
                            arc.neighbour_id.equals(whole_node_source_id)) return node_skeleton;
                }
                return null;
            }
            warning(@"Unknown IUnicastID class $(_unicast_id.get_type().name())");
            return null;
        }

        /* Get root-dispatchers if the message is to be processed.
         */
        public Gee.List<IAddressManagerSkeleton>
        get_dispatcher_set(
            ISourceID _source_id,
            IBroadcastID _broadcast_id,
            string peer_address,
            string dev)
        {
            if (_broadcast_id is EveryWholeNodeBroadcastID)
            {
                Gee.List<IAddressManagerSkeleton> ret = new ArrayList<IAddressManagerSkeleton>();
                ret.add(node_skeleton);
                return ret;
            }
            NeighborhoodRealArc? i = null;
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available)
            {
                if (arc.neighbour_nic_addr == peer_address && arc.my_nic.dev == dev)
                {
                    i = arc;
                    break;
                }
            }
            if (i == null) return new ArrayList<IAddressManagerSkeleton>();
            if (_broadcast_id is IdentityAwareBroadcastID)
            {
                IdentityAwareBroadcastID broadcast_id = (IdentityAwareBroadcastID)_broadcast_id;
                if (! (_source_id is IdentityAwareSourceID)) return new ArrayList<IAddressManagerSkeleton>();
                IdentityAwareSourceID source_id = (IdentityAwareSourceID)_source_id;
                Gee.List<NodeID> identity_aware_broadcast_set = broadcast_id.id_set;
                NodeID identity_aware_source_id = source_id.id;
                return get_identity_skeleton_set
                    (identity_aware_source_id,
                    identity_aware_broadcast_set,
                    peer_address,
                    dev);
            }
            return new ArrayList<IAddressManagerSkeleton>();
        }

        /* Get NodeID for the source of a received message. For identity-aware requests.
         */
        public NodeID?
        get_identity(
            ISourceID _source_id)
        {
            if (! (_source_id is IdentityAwareSourceID)) return null;
            IdentityAwareSourceID source_id = (IdentityAwareSourceID)_source_id;
            return source_id.id;
        }

        /* Get the arc for the source of a received message. For whole-node requests.
         */
        public INeighborhoodArc?
        get_node_arc(
            ISourceID _source_id,
            string dev)
        {
            if (! (_source_id is WholeNodeSourceID)) return null;
            WholeNodeSourceID source_id = (WholeNodeSourceID)_source_id;
            NeighborhoodNodeID whole_node_source_id = source_id.id;
            NeighborhoodRealArc? i = null;
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available)
            {
                if (arc.neighbour_id.equals(whole_node_source_id) && arc.my_nic.dev == dev)
                {
                    i = arc;
                    break;
                }
            }
            return i;
        }

        /* Get a stub for a identity-aware unicast request.
         */
        public IAddressManagerStub
        get_stub_identity_aware_unicast(
            INeighborhoodArc arc,
            NodeID source_node_id,
            NodeID unicast_node_id,
            bool wait_reply=true)
        {
            IdentityAwareSourceID source_id = new IdentityAwareSourceID(source_node_id);
            IdentityAwareUnicastID unicast_id = new IdentityAwareUnicastID(unicast_node_id);
            return stub_factory.get_tcp(arc.neighbour_nic_addr, source_id, unicast_id, wait_reply);
        }

        /* Get a stub for a whole-node unicast request.
         */
        public IAddressManagerStub
        get_stub_whole_node_unicast(
            INeighborhoodArc _arc,
            bool wait_reply=true)
        {
            assert(_arc is NeighborhoodRealArc);
            NeighborhoodRealArc arc = (NeighborhoodRealArc)_arc;
            WholeNodeSourceID source_id = new WholeNodeSourceID(my_id);
            WholeNodeUnicastID unicast_id = new WholeNodeUnicastID();
            return stub_factory.get_tcp(arc.neighbour_nic_addr, source_id, unicast_id, wait_reply);
        }

        /* Get a stub for a identity-aware broadcast request.
         */
        public IAddressManagerStub
        get_stub_identity_aware_broadcast(
            NodeID source_node_id,
            Gee.List<NodeID> broadcast_node_id_set,
            INeighborhoodMissingArcHandler? missing_handler=null)
        {
            IdentityAwareSourceID source_id = new IdentityAwareSourceID(source_node_id);
            IdentityAwareBroadcastID broadcast_id = new IdentityAwareBroadcastID(broadcast_node_id_set);
            ArrayList<string> devs = new ArrayList<string>();
            ArrayList<string> src_ips = new ArrayList<string>();
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available) if (! (arc.my_nic.dev in devs))
            {
                devs.add(arc.my_nic.dev);
                src_ips.add(local_addresses[arc.my_nic.dev]);
            }
            IAckCommunicator? ack_com = null;
            if (missing_handler != null)
            {
                Gee.List<INeighborhoodArc> lst_expected = current_arcs_for_broadcast(devs);
                ack_com = new NeighborhoodAcknowledgementsCommunicator(devs, this, missing_handler, lst_expected);
            }
            return stub_factory.get_broadcast(devs, src_ips, source_id, broadcast_id, ack_com);
        }

        /* Internal method: current arcs for a given broadcast message
         */
        private Gee.List<INeighborhoodArc> current_arcs_for_broadcast(
                            Gee.Collection<string> devs)
        {
            var ret = new ArrayList<INeighborhoodArc>();
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available)
            {
                // test arc against devs.
                if (! (arc.nic.dev in devs)) continue;
                // This should receive
                ret.add(arc);
            }
            return ret;
        }

        /* The instance of this class is created when the stub factory is invoked to
         * obtain a stub for broadcast.
         */
        private class NeighborhoodAcknowledgementsCommunicator : Object, IAckCommunicator
        {
            public Gee.List<string> devs;
            public NeighborhoodManager mgr;
            public INeighborhoodMissingArcHandler missing_handler;
            public Gee.List<INeighborhoodArc> lst_expected;

            public NeighborhoodAcknowledgementsCommunicator(
                                Gee.Collection<string> devs,
                                NeighborhoodManager mgr,
                                INeighborhoodMissingArcHandler missing_handler,
                                Gee.List<INeighborhoodArc> lst_expected)
            {
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
                Gee.List<INeighborhoodArc> lst_expected_now = mgr.current_arcs_for_broadcast(devs);
                Gee.List<INeighborhoodArc> lst_expected_intersect = new ArrayList<INeighborhoodArc>();
                foreach (var el in lst_expected)
                    if (el in lst_expected_now)
                        lst_expected_intersect.add(el);
                lst_expected = lst_expected_intersect;
                // prepare a list of missed arcs.
                var lst_missed = new ArrayList<INeighborhoodArc>();
                foreach (INeighborhoodArc expected in lst_expected)
                    if (! (expected.neighbour_mac in responding_macs))
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

            private class ActOnMissingTasklet : Object, ITaskletSpawnable
            {
                public INeighborhoodMissingArcHandler missing_handler;
                public INeighborhoodArc missed;
                public void * func()
                {
                    missing_handler.missing(missed);
                    return null;
                }
            }
        }

        /* Get a stub for a peculiar whole-node broadcast request. It is only used
         * by the module itself (hence private) to reach all nodes in a NIC.
         */
        private IAddressManagerStub
        get_stub_for_broadcast_to_dev(
            string dev, string local_address)
        {
            ArrayList<string> devs = new ArrayList<string>.wrap({dev});
            ArrayList<string> src_ips = new ArrayList<string>.wrap({local_address});
            WholeNodeSourceID source_id = new WholeNodeSourceID(my_id);
            EveryWholeNodeBroadcastID broadcast_id = new EveryWholeNodeBroadcastID();
            return stub_factory.get_broadcast(devs, src_ips, source_id, broadcast_id);
        }

        /* Remove an arc.
         */
        public void remove_my_arc(INeighborhoodArc _arc, bool do_tell=true)
        {
            if (!(_arc is NeighborhoodRealArc)) return;
            NeighborhoodRealArc arc = (NeighborhoodRealArc)_arc;
            // do just once
            if (! arcs_by_itsmac[arc.neighbour_mac].contains(arc)) return;
            // signal removing arc
            if (arc.exported)
            {
                if (arc.available) arc_removing(arc, do_tell);
            }
            string my_dev = arc.my_nic.dev;
            string my_addr = local_addresses[my_dev];
            // remove the fixed address of the neighbor
            ip_mgr.remove_neighbor(my_addr, my_dev, arc.neighbour_nic_addr);
            // remove the arc
            arcs_by_itsmac[arc.neighbour_mac].remove(arc);
            arcs_by_itsll[arc.neighbour_nic_addr].remove(arc);
            arcs_by_itsnodeid[@"arc.neighbour_id.id"].remove(arc);
            arcs_by_mydev_itsmac[my_dev][arc.neighbour_mac].remove(arc);
            arcs_by_mydev_itsll[my_dev][arc.neighbour_nic_addr].remove(arc);
            arcs_by_mydev_itsnodeid[my_dev][@"arc.neighbour_id.id"].remove(arc);
            // try and tell the neighbour to do the same
            if (do_tell)
            {
                // use broadcast, we just removed the local_address of the neighbor
                IAddressManagerStub bc = get_stub_for_broadcast_to_dev(my_dev, my_addr);
                try {
                    bc.neighborhood_manager.remove_arc(arc.neighbour_id, arc.neighbour_mac, arc.neighbour_nic_addr,
                                my_id, arc.my_nic.mac, local_addresses[arc.my_nic.dev]);
                } catch (StubError e) {
                } catch (DeserializeError e) {
                    warning(@"Call to remove_arc: got DeserializeError: $(e.message)");
                }
            }
            if (arc.exported)
            {
                // signal removed arc
                if (arc.available) arc_removed(arc);
                exported_arcs.remove(arc);
                // stop monitoring the cost of the arc
                stop_arc_monitor(arc);
            }
        }

        /* Remotable methods
         */

        internal delegate bool TestArc(NeighborhoodRealArc arc);
        internal int find_arc_in_list(ArrayList<NeighborhoodRealArc> lst, TestArc proposition) {
            for (int i = 0; i < lst.size; i++) {
                NeighborhoodRealArc arc = lst[i];
                if (proposition(arc)) return i;
            }
            return -1;
        }
        public void here_i_am(INeighborhoodNodeIDMessage _its_id, string its_mac, string its_nic_addr, CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            // This call has to be made in UDP broadcast, else ignore it.
            if (! (_rpc_caller is BroadcastCallerInfo)) return;
            BroadcastCallerInfo rpc_caller = (BroadcastCallerInfo)_rpc_caller;
            // This call should have a NeighborhoodNodeID, else ignore it.
            if (! (_its_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID its_id = (NeighborhoodNodeID)_its_id;
            // This is called in broadcast. Maybe it's me. It should not be the case.
            if (its_id.id == my_id.id) return;
            // It's a neighbour. The message came through my_nic. The MAC of the peer is its_mac.
            string my_dev = rpc_caller.dev;
            string my_addr = local_addresses[my_dev];
            INeighborhoodNetworkInterface? my_nic
                    = get_monitoring_interface_from_dev(my_dev);
            if (my_nic == null)
            {
                warning(@"Neighborhood.here_i_am: $(my_dev) is not being monitored");
                return;
            }

            string its_id_id = @"$(its_id.id)";
            if (! arcs_by_itsmac.has_key(its_mac))
                arcs_by_itsmac[its_mac] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_itsll.has_key(its_nic_addr))
                arcs_by_itsll[its_nic_addr] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_itsnodeid.has_key(its_id_id))
                arcs_by_itsnodeid[its_id_id] = new ArrayList<NeighborhoodRealArc>();
            assert(arcs_by_mydev_itsmac.has_key(my_dev));
            assert(arcs_by_mydev_itsll.has_key(my_dev));
            assert(arcs_by_mydev_itsnodeid.has_key(my_dev));
            if (! arcs_by_mydev_itsmac[my_dev].has_key(its_mac))
                arcs_by_mydev_itsmac[my_dev][its_mac] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_mydev_itsll[my_dev].has_key(its_nic_addr))
                arcs_by_mydev_itsll[my_dev][its_nic_addr] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_mydev_itsnodeid[my_dev].has_key(its_id_id))
                arcs_by_mydev_itsnodeid[my_dev][its_id_id] = new ArrayList<NeighborhoodRealArc>();

            if (find_arc_in_list(arcs_by_itsmac[its_mac], (a) => @"a.neighbour_id.id" != its_id_id) != -1)
                return; // ignore call. no different neighbors have same MAC.

            if (find_arc_in_list(arcs_by_itsmac[its_mac], (a) => a.neighbour_nic_addr != its_nic_addr) != -1)
                return; // ignore call. each MAC has a fixed linklocal.

            if (find_arc_in_list(arcs_by_itsmac[its_mac], (a) => a.nic.dev != my_dev && a.exported) != -1)
                return; // ignore call. I already have an arc with another NIC of mines towards its_mac.

            if (find_arc_in_list(arcs_by_itsnodeid[its_id_id], (a) => a.nic.dev == my_dev && a.neighbour_mac != its_mac && a.exported) != -1)
                return; // ignore call. I already have an arc with my_dev towards another NIC of same neighbor.

            NeighborhoodRealArc? cur_arc = null;
            int i = find_arc_in_list(arcs_by_itsmac[its_mac], (a) => a.nic.dev == my_dev);
            if (i != -1)
            {
                cur_arc = arcs_by_itsmac[its_mac][i];
                assert(@"cur_arc.neighbour_id.id" == its_id_id);
                assert(cur_arc.neighbour_nic_addr != its_nic_addr);
            }
            else
            {
                cur_arc = new NeighborhoodRealArc(its_id, its_mac, its_nic_addr, my_nic);
                arcs_by_itsmac[its_mac].add(cur_arc);
                arcs_by_itsll[its_nic_addr].add(cur_arc);
                arcs_by_itsnodeid[its_id_id].add(cur_arc);
                arcs_by_mydev_itsmac[my_dev][its_mac].add(cur_arc);
                arcs_by_mydev_itsll[my_dev][its_nic_addr].add(cur_arc);
                arcs_by_mydev_itsnodeid[my_dev][its_id_id].add(cur_arc);
                IAddressManagerStub bc = get_stub_for_broadcast_to_dev(my_dev, my_addr);
                try {
                    bc.neighborhood_manager.request_arc(its_id, its_mac, its_nic_addr, my_id, my_nic.mac, my_addr);
                } catch (StubError e) {
                    warning(@"Call to request_arc: got StubError: $(e.message)");
                    // failed
                    return;
                } catch (DeserializeError e) {
                    warning(@"Call to request_arc: got DeserializeError: $(e.message)");
                    // failed
                    return;
                }
                ip_mgr.add_neighbor(my_addr, my_dev, its_nic_addr);
                // wait a bit for neighbor to do the same
                tasklet.ms_wait(1000);
                // during that wait, some tasklet may have worked on cur_arc.
            }

            if (cur_arc.exported)
                return; // ignore call.

            // can I export?
            bool can_i = exported_arcs.size < max_arcs;
            // can_you_export?
            IAddressManagerStub tc = get_stub_whole_node_unicast(cur_arc);
            bool can_you = false;
            try {
                can_you = tc.neighborhood_manager.can_you_export(can_i);
            } catch (StubError e) {
                warning(@"Call to can_you_export: got StubError: $(e.message)");
                // failed
                return;
            } catch (DeserializeError e) {
                warning(@"Call to can_you_export: got DeserializeError: $(e.message)");
                // failed
                return;
            }
            if (can_i && can_you)
            {
                cur_arc.exported = true;
                exported_arcs.add(cur_arc);
                // start periodical ping
                start_arc_monitor(cur_arc);
            }
        }

        public void request_arc(INeighborhoodNodeIDMessage _dest_id, string dest_mac, string dest_nic_addr,
                                INeighborhoodNodeIDMessage _its_id, string its_mac, string its_nic_addr,
                                CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            // This call has to be made in UDP broadcast, else ignore it.
            if (! (_rpc_caller is BroadcastCallerInfo)) return;
            BroadcastCallerInfo rpc_caller = (BroadcastCallerInfo)_rpc_caller;
            // This call should have a couple of NeighborhoodNodeID, else ignore it.
            if (! (_its_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID its_id = (NeighborhoodNodeID)_its_id;
            if (! (_dest_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID dest_id = (NeighborhoodNodeID)_dest_id;
            // This is called in broadcast. Maybe it's me. It should not be the case.
            if (its_id.id == my_id.id) return;
            // It's a neighbour. The message came through my_nic. The MAC of the peer is its_mac.
            string my_dev = rpc_caller.dev;
            string my_addr = local_addresses[my_dev];
            INeighborhoodNetworkInterface? my_nic
                    = get_monitoring_interface_from_dev(my_dev);
            if (my_nic == null)
            {
                warning(@"Neighborhood.request_arc: $(my_dev) is not being monitored");
                return;
            }

            // is message for me?
            if (dest_id.id != my_id.id) return;
            if (dest_mac != my_nic.mac) return;
            if (dest_nic_addr != my_addr) return;
            // yes it is.

            string its_id_id = @"$(its_id.id)";
            if (! arcs_by_itsmac.has_key(its_mac))
                arcs_by_itsmac[its_mac] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_itsll.has_key(its_nic_addr))
                arcs_by_itsll[its_nic_addr] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_itsnodeid.has_key(its_id_id))
                arcs_by_itsnodeid[its_id_id] = new ArrayList<NeighborhoodRealArc>();
            assert(arcs_by_mydev_itsmac.has_key(my_dev));
            assert(arcs_by_mydev_itsll.has_key(my_dev));
            assert(arcs_by_mydev_itsnodeid.has_key(my_dev));
            if (! arcs_by_mydev_itsmac[my_dev].has_key(its_mac))
                arcs_by_mydev_itsmac[my_dev][its_mac] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_mydev_itsll[my_dev].has_key(its_nic_addr))
                arcs_by_mydev_itsll[my_dev][its_nic_addr] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_mydev_itsnodeid[my_dev].has_key(its_id_id))
                arcs_by_mydev_itsnodeid[my_dev][its_id_id] = new ArrayList<NeighborhoodRealArc>();

            if (find_arc_in_list(arcs_by_itsmac[its_mac], (a) => @"a.neighbour_id.id" != its_id_id) != -1)
                return; // ignore call. no different neighbors have same MAC.

            if (find_arc_in_list(arcs_by_itsmac[its_mac], (a) => a.neighbour_nic_addr != its_nic_addr) != -1)
                return; // ignore call. each MAC has a fixed linklocal.

            if (find_arc_in_list(arcs_by_itsmac[its_mac], (a) => a.nic.dev != my_dev && a.exported) != -1)
                return; // ignore call. I already have an arc with another NIC of mines towards its_mac.

            if (find_arc_in_list(arcs_by_itsnodeid[its_id_id], (a) => a.nic.dev == my_dev && a.neighbour_mac != its_mac && a.exported) != -1)
                return; // ignore call. I already have an arc with my_dev towards another NIC of same neighbor.

            if (find_arc_in_list(arcs_by_itsmac[its_mac], (a) => a.nic.dev == my_dev) != -1)
                return; // ignore call. I already have the arc that this message would add.

            // Let's make an arc
            NeighborhoodRealArc new_arc = new NeighborhoodRealArc(its_id, its_mac, its_nic_addr, my_nic);
            arcs_by_itsmac[its_mac].add(new_arc);
            arcs_by_itsll[its_nic_addr].add(new_arc);
            arcs_by_itsnodeid[its_id_id].add(new_arc);
            arcs_by_mydev_itsmac[my_dev][its_mac].add(new_arc);
            arcs_by_mydev_itsll[my_dev][its_nic_addr].add(new_arc);
            arcs_by_mydev_itsnodeid[my_dev][its_id_id].add(new_arc);
            ip_mgr.add_neighbor(my_addr, my_dev, its_nic_addr);
        }

        public bool can_you_export(bool peer_can_export, CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            // This call has to be made in TCP from a direct neighbor, else ignore it.
            if (! (_rpc_caller is TcpclientCallerInfo)) tasklet.exit_tasklet(null);
            TcpclientCallerInfo rpc_caller = (TcpclientCallerInfo)_rpc_caller;
            string its_nic_addr = rpc_caller.peer_address;
            string my_nic_addr = rpc_caller.my_address;

            string my_dev = null;
            foreach (string dev in local_addresses.keys) if (local_addresses[dev] == my_nic_addr) my_dev = dev;
            if (my_dev == null)
            {
                warning(@"Neighborhood.can_you_export: $(my_nic_addr) is not of a monitored dev");
                tasklet.exit_tasklet(null);
            }

            if (! arcs_by_mydev_itsll[my_dev].has_key(its_nic_addr)) tasklet.exit_tasklet(null);
            if (! arcs_by_mydev_itsll[my_dev][its_nic_addr].is_empty) tasklet.exit_tasklet(null);
            assert(arcs_by_mydev_itsll[my_dev][its_nic_addr].size == 1);
            NeighborhoodRealArc arc = arcs_by_mydev_itsll[my_dev][its_nic_addr][0];

            if (arc.exported) return true;

            bool can_i = exported_arcs.size < max_arcs;
            if (can_i && peer_can_export)
            {
                arc.exported = true;
                exported_arcs.add(arc);
                // start periodical ping
                start_arc_monitor(arc);
            }
            return can_i;
        }

        public void remove_arc(INeighborhoodNodeIDMessage _dest_id, string dest_mac, string dest_nic_addr,
                               INeighborhoodNodeIDMessage _its_id, string its_mac, string its_nic_addr,
                               CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            // This call has to be made in UDP broadcast, else ignore it.
            if (! (_rpc_caller is BroadcastCallerInfo)) return;
            BroadcastCallerInfo rpc_caller = (BroadcastCallerInfo)_rpc_caller;
            // This call should have a couple of NeighborhoodNodeID, else ignore it.
            if (! (_its_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID its_id = (NeighborhoodNodeID)_its_id;
            if (! (_dest_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID dest_id = (NeighborhoodNodeID)_dest_id;
            // This is called in broadcast. Maybe it's me. It should not be the case.
            if (its_id.id == my_id.id) return;
            // It's a neighbour. The message came through my_nic. The MAC of the peer is its_mac.
            string my_dev = rpc_caller.dev;
            string my_addr = local_addresses[my_dev];
            INeighborhoodNetworkInterface? my_nic
                    = get_monitoring_interface_from_dev(my_dev);
            if (my_nic == null)
            {
                warning(@"Neighborhood.remove_arc: $(my_dev) is not being monitored");
                return;
            }

            // is message for me?
            if (dest_id.id != my_id.id) return;
            if (dest_mac != my_nic.mac) return;
            if (dest_nic_addr != my_addr) return;
            // yes it is.

            string its_id_id = @"$(its_id.id)";
            if (! arcs_by_itsmac.has_key(its_mac))
                arcs_by_itsmac[its_mac] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_itsll.has_key(its_nic_addr))
                arcs_by_itsll[its_nic_addr] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_itsnodeid.has_key(its_id_id))
                arcs_by_itsnodeid[its_id_id] = new ArrayList<NeighborhoodRealArc>();
            assert(arcs_by_mydev_itsmac.has_key(my_dev));
            assert(arcs_by_mydev_itsll.has_key(my_dev));
            assert(arcs_by_mydev_itsnodeid.has_key(my_dev));
            if (! arcs_by_mydev_itsmac[my_dev].has_key(its_mac))
                arcs_by_mydev_itsmac[my_dev][its_mac] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_mydev_itsll[my_dev].has_key(its_nic_addr))
                arcs_by_mydev_itsll[my_dev][its_nic_addr] = new ArrayList<NeighborhoodRealArc>();
            if (! arcs_by_mydev_itsnodeid[my_dev].has_key(its_id_id))
                arcs_by_mydev_itsnodeid[my_dev][its_id_id] = new ArrayList<NeighborhoodRealArc>();

            if (find_arc_in_list(arcs_by_itsmac[its_mac], (a) => @"a.neighbour_id.id" != its_id_id) != -1)
                return; // ignore call. no different neighbors have same MAC.

            if (find_arc_in_list(arcs_by_itsmac[its_mac], (a) => a.neighbour_nic_addr != its_nic_addr) != -1)
                return; // ignore call. each MAC has a fixed linklocal.

            NeighborhoodRealArc? arc = null;
            int i = find_arc_in_list(arcs_by_itsmac[its_mac], (a) => a.nic.dev == my_dev);
            if (i != -1)
            {
                arc = arcs_by_itsmac[its_mac][i];
                assert(@"arc.neighbour_id.id" == its_id_id);
                assert(arc.neighbour_nic_addr != its_nic_addr);
                remove_my_arc(arc, false);
            }
        }

        public void nop(CallerInfo? caller = null)
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
    }
}

