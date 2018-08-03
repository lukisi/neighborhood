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
            tasklet = _tasklet;
        }

        public static void init_rngen(IRandomNumberGenerator? rngen=null, uint32? seed=null)
        {
            PRNGen.init_rngen(rngen, seed);
        }

        public NeighborhoodManager(
                                   int max_arcs,
                                   INeighborhoodStubFactory stub_factory,
                                   INeighborhoodQueryCallerInfo query_caller_info,
                                   INeighborhoodIPRouteManager ip_mgr,
                                   owned NewLinklocalAddress new_linklocal_address)
        {
            this.my_id = new NeighborhoodNodeID();
            this.max_arcs = max_arcs;
            this.stub_factory = stub_factory;
            this.query_caller_info = query_caller_info;
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

        private NeighborhoodNodeID my_id;
        private int max_arcs;
        private INeighborhoodStubFactory stub_factory;
        private INeighborhoodQueryCallerInfo query_caller_info;
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
        public signal void nic_address_set(INeighborhoodNetworkInterface nic, string address);
        // New arc formed.
        public signal void arc_added(INeighborhoodArc arc);
        // An arc is going to be removed.
        public signal void arc_removing(INeighborhoodArc arc, bool is_still_usable);
        // An arc removed.
        public signal void arc_removed(INeighborhoodArc arc);
        // An arc changed its cost.
        public signal void arc_changed(INeighborhoodArc arc);
        // Address removed from a NIC, no more handling.
        public signal void nic_address_unset(INeighborhoodNetworkInterface nic, string address);

        public NeighborhoodNodeID get_my_neighborhood_id()
        {
            return my_id;
        }

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
            nic_address_set(nic, local_address);
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
            foreach (NeighborhoodRealArc arc in arcs) if (arc.nic == nic) todel.add(arc);
            foreach (NeighborhoodRealArc arc in todel)
            {
                remove_my_arc(arc);
            }
            // stop monitor
            monitoring_devs[dev].kill();
            // remove local address
            string local_address = local_addresses[dev];
            ip_mgr.remove_address(local_address, dev);
            nic_address_unset(nic, local_address);
            // cleanup private members
            monitoring_devs.unset(dev);
            nics.unset(dev);
            local_addresses.unset(dev);
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
                        INeighborhoodManagerStub bc =
                            mgr.stub_factory.get_broadcast_for_radar(nic);
                        bc.here_i_am(mgr.my_id, nic.mac, local_address);
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
                        rtt = arc.nic.measure_rtt(
                            arc.neighbour_nic_addr,
                            arc.neighbour_mac,
                            arc.nic.dev,
                            mgr.local_addresses[arc.nic.dev]);
                    } catch (NeighborhoodGetRttError e) {
                        // Failed measure_rtt.
                        err_msg = e.message;
                    }

                    // Use a tcp_client to check the neighbor.
                    bool nop_check = false;
                    try
                    {
                        INeighborhoodManagerStub tc = mgr.stub_factory.get_tcp(arc);
                        tc.nop();
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

        /* Expose current valid arcs
         */
        public Gee.List<INeighborhoodArc> current_arcs()
        {
            var ret = new ArrayList<INeighborhoodArc>();
            foreach (NeighborhoodRealArc arc in arcs) if (arc.available) ret.add(arc);
            return ret;
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
            string my_dev = arc.nic.dev;
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
                INeighborhoodManagerStub bc = stub_factory.get_broadcast_for_radar(arc.nic);
                try {
                    bc.remove_arc(arc.neighbour_id, arc.neighbour_mac, arc.neighbour_nic_addr,
                                my_id, arc.nic.mac, local_addresses[arc.nic.dev]);
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
            INeighborhoodNetworkInterface? my_nic = query_caller_info.is_from_broadcast(_rpc_caller);
            if (my_nic == null) tasklet.exit_tasklet(null);
            // This call should have a NeighborhoodNodeID, else ignore it.
            if (! (_its_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID its_id = (NeighborhoodNodeID)_its_id;
            // This is called in broadcast. Maybe it's me. It should not be the case.
            if (its_id.id == my_id.id) return;
            // It's a neighbour. The message came through my_nic. The MAC of the peer is its_mac.
            string my_dev = my_nic.dev;
            string my_addr = local_addresses[my_dev];

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
                INeighborhoodManagerStub bc = stub_factory.get_broadcast_for_radar(my_nic);
                try {
                    bc.request_arc(its_id, its_mac, its_nic_addr, my_id, my_nic.mac, my_addr);
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
            INeighborhoodManagerStub tc = stub_factory.get_tcp(cur_arc);
            bool can_you = false;
            try {
                can_you = tc.can_you_export(can_i);
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
            INeighborhoodNetworkInterface? my_nic = query_caller_info.is_from_broadcast(_rpc_caller);
            if (my_nic == null) tasklet.exit_tasklet(null);
            // This call should have a couple of NeighborhoodNodeID, else ignore it.
            if (! (_its_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID its_id = (NeighborhoodNodeID)_its_id;
            if (! (_dest_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID dest_id = (NeighborhoodNodeID)_dest_id;
            // This is called in broadcast. Maybe it's me. It should not be the case.
            if (its_id.id == my_id.id) return;
            // It's a neighbour. The message came through my_nic. The MAC of the peer is its_mac.
            string my_dev = my_nic.dev;
            string my_addr = local_addresses[my_dev];

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
            INeighborhoodArc? _arc = query_caller_info.is_from_unicast(_rpc_caller);
            if (_arc == null) tasklet.exit_tasklet(null);
            if (! (_arc is NeighborhoodRealArc)) tasklet.exit_tasklet(null);
            NeighborhoodRealArc arc = (NeighborhoodRealArc)_arc;
            string its_nic_addr = arc.neighbour_nic_addr;
            string my_dev = arc.nic.dev;

            if (! arcs_by_mydev_itsll[my_dev].has_key(its_nic_addr)) tasklet.exit_tasklet(null);
            if (! arcs_by_mydev_itsll[my_dev][its_nic_addr].is_empty) tasklet.exit_tasklet(null);

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
            INeighborhoodNetworkInterface? my_nic = query_caller_info.is_from_broadcast(_rpc_caller);
            if (my_nic == null) tasklet.exit_tasklet(null);
            // This call should have a couple of NeighborhoodNodeID, else ignore it.
            if (! (_its_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID its_id = (NeighborhoodNodeID)_its_id;
            if (! (_dest_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID dest_id = (NeighborhoodNodeID)_dest_id;
            // This is called in broadcast. Maybe it's me. It should not be the case.
            if (its_id.id == my_id.id) return;
            // It's a neighbour. The message came through my_nic. The MAC of the peer is its_mac.
            string my_dev = my_nic.dev;
            string my_addr = local_addresses[my_dev];

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
    }
}

