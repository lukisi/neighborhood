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
using LibNeighborhoodInternals;

namespace Netsukuku.Neighborhood
{
    /* Serializable internal classes
     */

    internal class NeighborhoodNodeID : Object, INeighborhoodNodeIDMessage
    {
        public NeighborhoodNodeID()
        {
            id = Random.int_range(1, int.MAX);
        }
        public int id {get; set;}

        public bool equals(NeighborhoodNodeID other)
        {
            return id == other.id;
        }
    }

    internal class WholeNodeSourceID : Object, ISourceID
    {
        public WholeNodeSourceID(NeighborhoodNodeID id)
        {
            this.id = id;
        }
        public NeighborhoodNodeID id {get; set;}
    }

    internal class WholeNodeUnicastID : Object, IUnicastID
    {
    }

    internal class WholeNodeBroadcastID : Object, Json.Serializable, IBroadcastID
    {
        public WholeNodeBroadcastID(Gee.List<NeighborhoodNodeID> id_set)
        {
            this.id_set = new ArrayList<NeighborhoodNodeID>((a, b) => a.equals(b));
            this.id_set.add_all(id_set);
        }
        public Gee.List<NeighborhoodNodeID> id_set {get; set;}

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "id_set":
            case "id-set":
                try {
                    @value = deserialize_list_neighborhood_node_id(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "id_set":
            case "id-set":
                return serialize_list_neighborhood_node_id((Gee.List<NeighborhoodNodeID>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }
    }

    internal class NoArcWholeNodeUnicastID : Object, IUnicastID
    {
        public NoArcWholeNodeUnicastID(NeighborhoodNodeID id, string mac)
        {
            this.id = id;
            this.mac = mac;
        }
        public NeighborhoodNodeID id {get; set;}
        public string mac {get; set;}
    }

    internal class EveryWholeNodeBroadcastID : Object, IBroadcastID
    {
    }

    internal class IdentityAwareSourceID : Object, ISourceID
    {
        public IdentityAwareSourceID(NodeID id)
        {
            this.id = id;
        }
        public NodeID id {get; set;}
    }

    internal class IdentityAwareUnicastID : Object, IUnicastID
    {
        public IdentityAwareUnicastID(NodeID id)
        {
            this.id = id;
        }
        public NodeID id {get; set;}
    }

    internal class IdentityAwareBroadcastID : Object, Json.Serializable, IBroadcastID
    {
        public IdentityAwareBroadcastID(Gee.List<NodeID> id_set)
        {
            this.id_set = new ArrayList<NodeID>((a, b) => a.equals(b));
            this.id_set.add_all(id_set);
        }
        public Gee.List<NodeID> id_set {get; set;}

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "id_set":
            case "id-set":
                try {
                    @value = deserialize_list_node_id(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "id_set":
            case "id-set":
                return serialize_list_node_id((Gee.List<NodeID>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }
    }

    /* Interfaces for requirements
     */

    public delegate string NewLinklocalAddress();

    public errordomain NeighborhoodGetRttError {
        GENERIC
    }

    public interface INeighborhoodNetworkInterface : Object
    {
        public abstract string dev {get;}
        public abstract string mac {get;}
        public abstract long measure_rtt(string peer_addr, string peer_mac, string my_dev, string my_addr) throws NeighborhoodGetRttError;
    }

    public interface INeighborhoodArc : Object
    {
        public abstract string neighbour_mac {get;}
        public abstract string neighbour_nic_addr {get;}
        public abstract long cost {get;}
        public abstract INeighborhoodNetworkInterface nic {get;}
    }

    internal class NeighborhoodRealArc : Object, INeighborhoodArc
    {
        private NeighborhoodNodeID _neighbour_id;
        private string _mac;
        private string _nic_addr;
        private long _cost;
        private INeighborhoodNetworkInterface _my_nic;
        public bool available;

        public NeighborhoodRealArc(NeighborhoodNodeID neighbour_id,
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

        public NeighborhoodNodeID neighbour_id {
            get {
                return _neighbour_id;
            }
        }

        public void set_cost(long cost)
        {
            _cost = cost;
            available = true;
        }

        /* Public interface INeighborhoodArc
         */

        public string neighbour_mac {
            get {
                return _mac;
            }
        }

        public string neighbour_nic_addr {
            get {
                return _nic_addr;
            }
        }

        public long cost {
            get {
                return _cost;
            }
        }

        public INeighborhoodNetworkInterface nic {
            get {
                return _my_nic;
            }
        }
    }

    public interface INeighborhoodMissingArcHandler : Object
    {
        public abstract void missing(INeighborhoodArc arc);
    }

    /* This interface is implemented by an object passed to the Neighbor manager
     * which uses it to actually obtain a stub to send messages to other nodes.
     */
    public interface INeighborhoodStubFactory : Object
    {
        public abstract IAddressManagerStub
                        get_broadcast(
                            Gee.List<string> devs,
                            Gee.List<string> src_ips,
                            ISourceID source_id,
                            IBroadcastID broadcast_id,
                            IAckCommunicator? ack_com=null
                        );

        public  IAddressManagerStub
                get_broadcast_to_dev(
                    string dev,
                    string src_ip,
                    ISourceID source_id,
                    IBroadcastID broadcast_id,
                    IAckCommunicator? ack_com=null
                )
        {
            var _devs = new ArrayList<string>.wrap({dev});
            var _src_ips = new ArrayList<string>.wrap({src_ip});
            return get_broadcast(_devs, _src_ips, source_id, broadcast_id, ack_com);
        }

        public abstract IAddressManagerStub
                        get_unicast(
                            string dev,
                            string src_ip,
                            ISourceID source_id,
                            IUnicastID unicast_id,
                            bool wait_reply=true
                        );

        public abstract IAddressManagerStub
                        get_tcp(
                            string dest,
                            ISourceID source_id,
                            IUnicastID unicast_id,
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
        public abstract void add_address(
                            string my_addr,
                            string my_dev
                        );

        public abstract void add_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        );

        public abstract void remove_neighbor(
                            string my_addr,
                            string my_dev,
                            string neighbor_addr
                        );

        public abstract void remove_address(
                            string my_addr,
                            string my_dev
                        );
    }

    public delegate
        IAddressManagerSkeleton? GetIdentitySkeletonFunc
        (NodeID source_id, NodeID unicast_id, string peer_address);
    public delegate
        Gee.List<IAddressManagerSkeleton> GetIdentitySkeletonSetFunc
        (NodeID source_id, Gee.List<NodeID> broadcast_set, string peer_address, string dev);

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
            typeof(WholeNodeBroadcastID).class_peek();
            typeof(NoArcWholeNodeUnicastID).class_peek();
            typeof(EveryWholeNodeBroadcastID).class_peek();
            typeof(IdentityAwareSourceID).class_peek();
            typeof(IdentityAwareUnicastID).class_peek();
            typeof(IdentityAwareBroadcastID).class_peek();
            tasklet = _tasklet;
        }

        public NeighborhoodManager(
                                   GetIdentitySkeletonFunc get_identity_skeleton,
                                   GetIdentitySkeletonSetFunc get_identity_skeleton_set,
                                   IAddressManagerSkeleton node_skeleton,
                                   int max_arcs,
                                   INeighborhoodStubFactory stub_factory,
                                   INeighborhoodIPRouteManager ip_mgr,
                                   NewLinklocalAddress new_linklocal_address)
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
            monitoring_arcs = new HashMap<NeighborhoodRealArc, ITaskletHandle>();
            this.new_linklocal_address = new_linklocal_address;
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
                            mgr.get_stub_for_here_i_am(nic.dev, local_address);
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
                // wait that the pair of nodes both create the NeighborhoodRealArc.
                tasklet.ms_wait(400);
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
            if (_unicast_id is NoArcWholeNodeUnicastID)
            {
                NoArcWholeNodeUnicastID unicast_id = (NoArcWholeNodeUnicastID)_unicast_id;
                if (dev == null) return null;
                if (! is_monitoring(dev)) return null;
                INeighborhoodNetworkInterface my_nic = get_monitoring_interface_from_dev(dev);
                if (! unicast_id.id.equals(my_id)) return null;
                if (my_nic.mac != unicast_id.mac) return null;
                return node_skeleton;
            }
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
            if (_broadcast_id is WholeNodeBroadcastID)
            {
                WholeNodeBroadcastID broadcast_id = (WholeNodeBroadcastID)_broadcast_id;
                if (! (_source_id is WholeNodeSourceID)) return new ArrayList<IAddressManagerSkeleton>();
                WholeNodeSourceID source_id = (WholeNodeSourceID)_source_id;
                Gee.List<NeighborhoodNodeID> whole_node_broadcast_set = broadcast_id.id_set;
                NeighborhoodNodeID whole_node_source_id = source_id.id;
                if (my_id in whole_node_broadcast_set && i.neighbour_id.equals(whole_node_source_id))
                {
                    Gee.List<IAddressManagerSkeleton> ret = new ArrayList<IAddressManagerSkeleton>();
                    ret.add(node_skeleton);
                    return ret;
                }
                return new ArrayList<IAddressManagerSkeleton>();
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

        /* Get a stub for a whole-node broadcast request.
         */
        public IAddressManagerStub
        get_stub_whole_node_broadcast(
            Gee.List<INeighborhoodArc> arc_set,
            INeighborhoodMissingArcHandler? missing_handler=null)
        {
            WholeNodeSourceID source_id = new WholeNodeSourceID(my_id);
            ArrayList<NeighborhoodNodeID> id_set = new ArrayList<NeighborhoodNodeID>();
            foreach (INeighborhoodArc _arc in arc_set)
            {
                assert(_arc is NeighborhoodRealArc);
                NeighborhoodRealArc arc = (NeighborhoodRealArc)_arc;
                id_set.add(arc.neighbour_id);
            }
            WholeNodeBroadcastID broadcast_id = new WholeNodeBroadcastID(id_set);
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
        get_stub_for_here_i_am(
            string dev, string local_address)
        {
            ArrayList<string> devs = new ArrayList<string>.wrap({dev});
            ArrayList<string> src_ips = new ArrayList<string>.wrap({local_address});
            WholeNodeSourceID source_id = new WholeNodeSourceID(my_id);
            EveryWholeNodeBroadcastID broadcast_id = new EveryWholeNodeBroadcastID();
            return stub_factory.get_broadcast(devs, src_ips, source_id, broadcast_id);
        }

        /* Get a stub for a peculiar whole-node unicast request. It is only used
         * by the module itself (hence private) to reach a node before an arc
         * is ready or after it has been removed.
         */
        private IAddressManagerStub
        get_stub_for_no_arc(
            NeighborhoodNodeID its_id,
            string its_mac,
            string my_dev,
            bool wait_reply=true)
        {
            IUnicastID unicast_id = new NoArcWholeNodeUnicastID(its_id, its_mac);
            ISourceID source_id = new WholeNodeSourceID(my_id);
            return stub_factory.get_unicast(my_dev, local_addresses[my_dev], source_id, unicast_id, wait_reply);
        }

        /* Remove an arc.
         */
        public void remove_my_arc(INeighborhoodArc arc, bool do_tell=true)
        {
            if (!(arc is NeighborhoodRealArc)) return;
            NeighborhoodRealArc _arc = (NeighborhoodRealArc)arc;
            // do just once
            if (! arcs.contains(_arc)) return;
            // signal removing arc
            if (_arc.available) arc_removing(arc, do_tell);
            // remove the fixed address of the neighbor
            ip_mgr.remove_neighbor(
                        /*my_addr*/ local_addresses[_arc.my_nic.dev],
                        /*my_dev*/ _arc.my_nic.dev,
                        /*neighbor_addr*/ _arc.neighbour_nic_addr);
            // remove the arc
            arcs.remove(_arc);
            // try and tell the neighbour to do the same
            if (do_tell)
            {
                // use UDP, we just removed the local_address of the neighbor
                var uc = get_stub_for_no_arc(_arc.neighbour_id, _arc.neighbour_mac, _arc.my_nic.dev, false);
                try {
                    uc.neighborhood_manager
                        .remove_arc(my_id,
                                   _arc.my_nic.mac,
                                   local_addresses[_arc.my_nic.dev]);
                } catch (StubError e) {
                } catch (DeserializeError e) {
                    warning(@"Call to remove_arc: got DeserializeError: $(e.message)");
                }
            }
            // signal removed arc
            if (_arc.available) arc_removed(arc);
            // stop monitoring the cost of the arc
            stop_arc_monitor(_arc);
        }

        /* Remotable methods
         */

        public void here_i_am(INeighborhoodNodeIDMessage _its_id, string mac, string nic_addr, CallerInfo? _rpc_caller=null)
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
            // It's a neighbour. The message came through my_nic. The MAC of the peer is mac.
            string my_dev = rpc_caller.dev;
            INeighborhoodNetworkInterface? my_nic
                    = get_monitoring_interface_from_dev(my_dev);
            if (my_nic == null)
            {
                warning(@"Neighborhood.here_i_am: $(my_dev) is not being monitored");
                return;
            }
            // Did I already meet this node? Did I already make an arc?
            foreach (NeighborhoodRealArc arc in arcs)
            {
                if (arc.neighbour_id.id == its_id.id)
                {
                    // I already met him. Same MAC and same NIC?
                    if (arc.neighbour_mac == mac && arc.my_nic == my_nic)
                    {
                        // I already made this arc. Ignore this message.
                        return;
                    }
                    if (arc.neighbour_mac == mac || arc.my_nic == my_nic)
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
            var uc = get_stub_for_no_arc(its_id, mac, my_dev);

            bool refused = false;
            bool failed = false;
            try
            {
                uc.neighborhood_manager.request_arc(my_id, my_nic.mac, local_addresses[my_dev]);
            }
            catch (NeighborhoodRequestArcError e)
            {
                // arc refused
                refused = true;
            }
            catch (StubError e)
            {
                // failed
                failed = true;
            }
            catch (DeserializeError e)
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
                ip_mgr.add_neighbor(
                            /*my_addr*/ local_addresses[my_dev],
                            /*my_dev*/ my_dev,
                            /*neighbor_addr*/ nic_addr);
                // start periodical ping
                start_arc_monitor(new_arc);
            }
        }

        public void request_arc(INeighborhoodNodeIDMessage _its_id, string mac, string nic_addr,
                                CallerInfo? _rpc_caller=null) throws NeighborhoodRequestArcError
        {
            debug("request_arc: start");
            assert(_rpc_caller != null);
            // This call has to be made in UDP unicast, else ignore it.
            if (! (_rpc_caller is UnicastCallerInfo)) return;
            UnicastCallerInfo rpc_caller = (UnicastCallerInfo)_rpc_caller;
            // This call should have a NeighborhoodNodeID, else ignore it.
            if (! (_its_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID its_id = (NeighborhoodNodeID)_its_id;
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
                if (arc.neighbour_id.equals(its_id))
                {
                    // I already met him. Same MAC and same NIC?
                    if (arc.neighbour_mac == mac && arc.my_nic == my_nic)
                    {
                        // I already made this arc. Confirm arc.
                        warning("Neighborhood.request_arc: " +
                        @"Already got $(mac) on $(my_nic.mac)");
                        return;
                    }
                    if (arc.neighbour_mac == mac || arc.my_nic == my_nic)
                    {
                        // Not willing to make a new arc on same collision
                        // domain.
                        throw new NeighborhoodRequestArcError.TWO_ARCS_ON_COLLISION_DOMAIN(
                        @"Refusing $(mac) on $(my_nic.mac).");
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
            ip_mgr.add_neighbor(
                        /*my_addr*/ local_addresses[my_dev],
                        /*my_dev*/ my_dev,
                        /*neighbor_addr*/ nic_addr);
            // start periodical ping
            start_arc_monitor(new_arc);
        }

        public void remove_arc(INeighborhoodNodeIDMessage _its_id, string mac, string nic_addr,
                                CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            // This call has to be made in UDP unicast, else ignore it.
            if (! (_rpc_caller is UnicastCallerInfo)) return;
            UnicastCallerInfo rpc_caller = (UnicastCallerInfo)_rpc_caller;
            // This call should have a NeighborhoodNodeID, else ignore it.
            if (! (_its_id is NeighborhoodNodeID)) return;
            NeighborhoodNodeID its_id = (NeighborhoodNodeID)_its_id;
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
                if (arc.neighbour_id.equals(its_id) &&
                    arc.neighbour_mac == mac &&
                    arc.my_nic == my_nic)
                {
                    remove_my_arc(arc, false);
                    // the foreach would abort if I don't break
                    break;
                }
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

