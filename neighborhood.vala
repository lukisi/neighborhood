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
using zcd;
using Tasklets;

namespace Netsukuku
{
    // in ntkd-rpc  INeighborhoodNodeID

    public errordomain NeighborhoodGetRttError {
        GENERIC
    }

    public interface INeighborhoodNetworkInterface : Object
    {
        public abstract string i_neighborhood_dev {get;}
        public abstract string i_neighborhood_mac {get;}
        public abstract long i_neighborhood_get_usec_rtt(uint guid) throws NeighborhoodGetRttError;
        public abstract void i_neighborhood_prepare_ping(uint guid);
    }

    public interface INeighborhoodArc : Object
    {
        public abstract INeighborhoodNodeID i_neighborhood_neighbour_id {get;}
        public abstract string i_neighborhood_mac {get;}
        public abstract REM i_neighborhood_cost {get;}
        public abstract INeighborhoodNetworkInterface i_neighborhood_nic {get;}
        public abstract bool i_neighborhood_comes_from(zcd.CallerInfo rpc_caller);
    }

    internal class NeighborhoodRealArc : Object, INeighborhoodArc
    {
        private INeighborhoodNodeID _neighbour_id;
        private string _mac;
        private string _nic_addr;
        private REM _cost;
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

        public void set_cost(REM cost)
        {
            _cost = cost;
            available = true;
        }

        /* Public interface INeighborhoodArc
         */

        public bool i_neighborhood_comes_from(zcd.CallerInfo rpc_caller)
        {
            return _nic_addr == rpc_caller.caller_ip;
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

        public REM i_neighborhood_cost {
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
        public abstract IAddressManagerRootDispatcher
                        i_neighborhood_get_broadcast(
                            BroadcastID bcid,
                            Gee.Collection<string> devs,
                            IAcknowledgementsCommunicator? ack_com=null
                        );

        public  IAddressManagerRootDispatcher
                i_neighborhood_get_broadcast_to_dev(
                    BroadcastID bcid,
                    string dev,
                    IAcknowledgementsCommunicator? ack_com=null
                )
        {
            var _devs = new ArrayList<string>();
            _devs.add(dev);
            return i_neighborhood_get_broadcast(bcid, _devs, ack_com);
        }

        public abstract IAddressManagerRootDispatcher
                        i_neighborhood_get_unicast(
                            UnicastID ucid,
                            string dev,
                            bool wait_reply=true
                        );

        public abstract IAddressManagerRootDispatcher
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

    public class NeighborhoodManager : Object, INeighborhoodManager
    {
        public static void init()
        {
            // Register serializable types
            // typeof(Xxx).class_peek();
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
            monitoring_devs = new HashMap<string, Tasklet>();
            arcs = new ArrayList<NeighborhoodRealArc>();
            monitoring_arcs = new HashMap<NeighborhoodRealArc, Tasklet>();
        }

        private INeighborhoodNodeID my_id;
        private int max_arcs;
        private INeighborhoodStubFactory stub_factory;
        private INeighborhoodIPRouteManager ip_mgr;
        private HashMap<string, INeighborhoodNetworkInterface> nics;
        private HashMap<string, string> local_addresses;
        private HashMap<string, Tasklet> monitoring_devs;
        private ArrayList<NeighborhoodRealArc> arcs;
        private HashMap<NeighborhoodRealArc, Tasklet> monitoring_arcs;

        // Signals:
        // Network collision detected.
        public signal void network_collision(INeighborhoodNodeID other);
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
            int i1 = Random.int_range(64, 127);
            int i2 = Random.int_range(0, 255);
            int i3 = Random.int_range(0, 255);
            string local_address = @"100.$(i1).$(i2).$(i3)";
            ip_mgr.i_neighborhood_add_address(local_address, dev);
            // start monitor
            Tasklet t = Tasklet.tasklet_callback(
                (t_nic, t_local_address) => {
                    monitor_run(t_nic as INeighborhoodNetworkInterface,
                                (t_local_address as SerializableString).s);
                },
                nic,
                new SerializableString(local_address));
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
            monitoring_devs[dev].abort();
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
        private void monitor_run(INeighborhoodNetworkInterface nic, string local_address)
        {
            while (true)
            {
                try
                {
                    IAddressManagerRootDispatcher bc =
                        get_stub_broadcast_to_dev(nic.i_neighborhood_dev);
                        // nothing to do for missing ACK from known neighbours
                        // because this message would be not important for them anyway.
                    bc.neighborhood_manager.here_i_am(my_id, nic.i_neighborhood_mac, local_address);
                }
                catch (RPCError e)
                {
                    log_warn("Neighborhood.monitor_run: " +
                    @"Error '$(e.message)' while sending in broadcast to $(nic.i_neighborhood_mac).");
                }
                Tasklet.nap(60, 0);
            }
        }

        public bool is_unicast_for_me(UnicastID ucid, string dev)
        {
            // Do I manage this dev?
            if (! is_monitoring(dev)) return false;
            // Is it me?
            if (nics[dev].i_neighborhood_mac != ucid.mac) return false;
            return my_id.i_neighborhood_equals(ucid.nodeid);
        }

        public bool is_broadcast_for_me(BroadcastID bcid, string dev)
        {
            // Do I manage this dev?
            if (! is_monitoring(dev)) return false;
            // Am I to ignore?
            return ! my_id.i_neighborhood_equals(bcid.ignore_nodeid);
        }

        private void start_arc_monitor(NeighborhoodRealArc arc)
        {
            Tasklet t = Tasklet.tasklet_callback(
                (t_arc) => {
                    arc_monitor_run(t_arc as NeighborhoodRealArc);
                },
                arc);
            monitoring_arcs[arc] = t;
        }

        private void stop_arc_monitor(NeighborhoodRealArc arc)
        {
            if (! monitoring_arcs.has_key(arc)) return;
            monitoring_arcs[arc].abort();
            monitoring_arcs.unset(arc);
        }

        /* Runs in a tasklet foreach arc
         */
        private void arc_monitor_run(NeighborhoodRealArc arc)
        {
            try
            {
                long last_rtt = -1;
                while (true)
                {
                    try
                    {
                        // Use a tcp_client to prepare the neighbor.
                        // It can throw RPCError.
                        var uc = get_stub_tcp(arc);
                        int guid = Random.int_range(0, 1000000);
                        uc.neighborhood_manager.expect_ping(guid);
                        Tasklet.nap(1, 0);
                        // Use the callback saved in the INetworkInterface to get the
                        // RTT. It can throw NeighborhoodGetRttError.
                        long rtt = arc.my_nic.i_neighborhood_get_usec_rtt((uint)guid);
                        // If all goes right, the arc is still valid and we have the
                        // cost up-to-date.
                        if (last_rtt == -1)
                        {
                            // First cost measure
                            last_rtt = rtt;
                            REM cost = new RTT(last_rtt);
                            arc.set_cost(cost);
                            // signal new arc
                            arc_added(arc);
                        }
                        else
                        {
                            // Following cost measures
                            long delta_rtt = rtt - last_rtt;
                            if (delta_rtt > 0) delta_rtt = delta_rtt / 10;
                            if (delta_rtt < 0) delta_rtt = delta_rtt / 3;
                            last_rtt = last_rtt + delta_rtt;
                            if (last_rtt < (arc.i_neighborhood_cost as RTT).delay * 0.5 ||
                                last_rtt > (arc.i_neighborhood_cost as RTT).delay * 2)
                            {
                                REM cost = new RTT(last_rtt);
                                arc.set_cost(cost);
                                // signal changed arc
                                arc_changed(arc);
                            }
                        }

                        Tasklet.nap(30, 0);
                    }
                    catch (NeighborhoodGetRttError e)
                    {
                        // failed getting the RTT
                        // Since UDP is not reliable, this is ignorable. Try again soon.
                        Tasklet.nap(1, 0);
                    }
                }
            }
            catch (RPCError e)
            {
                // failed sending the GUID
                // Since it was sent via TCP this is worrying.
                log_warn(@"Neighborhood.arc_monitor_run: $(e.message)");
                remove_my_arc(arc);
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
                } catch (RPCError e) {}
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
        IAddressManagerRootDispatcher
        get_stub_tcp(INeighborhoodArc arc, bool wait_reply=true)
        {
            NeighborhoodRealArc _arc = (NeighborhoodRealArc)arc;
            var uc = stub_factory.i_neighborhood_get_tcp(_arc.nic_addr, wait_reply);
            return uc;
        }

        /* Get a client to call a unicast remote method via UDP
         */
        private
        IAddressManagerRootDispatcher
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
                    if (arc.i_neighborhood_neighbour_id.i_neighborhood_equals(bcid.ignore_nodeid as INeighborhoodNodeID)) continue;
                // test arc against devs.
                if (! (arc.i_neighborhood_nic.i_neighborhood_dev in devs)) continue;
                // This should receive
                ret.add(arc);
            }
            return ret;
        }

        /* The instance of this class is created when the stub factory is invoked to
         * obtain a stub for broadcast. This stub should not be used for more than
         * one call.
         * When a remote call is made, immediately the tasklet spawned by the method
         * 'prepare' will use current_arcs_for_broadcast. Then it will block and
         * wait for the channel to be ready to send the list of responding MACs.
         * Finally the tasklet will spawn new tasklets for the missing arc to be
         * handled by the missing_handler.
         */
        class NeighborhoodAcknowledgementsCommunicator : Object, IAcknowledgementsCommunicator
        {
            public BroadcastID bcid;
            public Gee.Collection<string> devs;
            public NeighborhoodManager mgr;
            public INeighborhoodMissingArcHandler missing_handler;

            public NeighborhoodAcknowledgementsCommunicator(BroadcastID bcid,
                                Gee.Collection<string> devs,
                                NeighborhoodManager mgr,
                                INeighborhoodMissingArcHandler missing_handler)
            {
                this.bcid = bcid;
                this.devs = devs;
                this.mgr = mgr;
                this.missing_handler = missing_handler;
            }

            public Channel prepare()
            {
                Channel ch = new Channel();
                Tasklet.tasklet_callback(
                    (t_ack_comm, t_ch) => {
                        NeighborhoodAcknowledgementsCommunicator ack_comm = (NeighborhoodAcknowledgementsCommunicator)t_ack_comm;
                        ack_comm.gather_acks((Channel)t_ch);
                    },
                    this,
                    ch
                );
                return ch;
            }

            /* Gather ACKs from expected receivers of a broadcast message
             */
            void
            gather_acks(Channel ch)
            {
                // prepare a list of expected receivers.
                var lst_expected1 = mgr.current_arcs_for_broadcast(bcid, devs);
                // Wait for the timeout and receive from the channel the list of ACKs.
                Value v = ch.recv();
                Gee.List<string> responding_macs = (Gee.List<string>)v;
                // intersect with current ones now
                var lst_expected2 = mgr.current_arcs_for_broadcast(bcid, devs);
                Gee.List<INeighborhoodArc> lst_expected = new ArrayList<INeighborhoodArc>();
                foreach (var el in lst_expected1)
                    if (el in lst_expected2)
                        lst_expected.add(el);
                // prepare a list of missed arcs.
                var lst_missed = new ArrayList<INeighborhoodArc>();
                foreach (INeighborhoodArc expected in lst_expected)
                {
                    bool has_responded = false;
                    foreach (string responding_mac in responding_macs)
                    {
                        if (expected.i_neighborhood_mac == responding_mac)
                        {
                            has_responded = true;
                            break;
                        }
                    }
                    if (! has_responded) lst_missed.add(expected);
                }
                // foreach missed arc launch in a tasklet
                // the 'missing' callback.
                foreach (INeighborhoodArc missed in lst_missed)
                {
                    Tasklet.tasklet_callback(
                        (t_ack_comm, t_missed) => {
                            NeighborhoodAcknowledgementsCommunicator ack_comm = (NeighborhoodAcknowledgementsCommunicator)t_ack_comm;
                            ack_comm.missing_handler.i_neighborhood_missing((INeighborhoodArc)t_missed);
                        },
                        this,
                        missed
                    );
                }
            }
        }

        /* Get a client to call a broadcast remote method
         */
        public
        IAddressManagerRootDispatcher
        get_stub_broadcast(INeighborhoodMissingArcHandler? missing_handler=null,
                      INeighborhoodNodeID? ignore_neighbour=null)
        {
            var bcid = new BroadcastID(ignore_neighbour);
            IAddressManagerRootDispatcher ret;
            if (missing_handler == null)
                ret = stub_factory.i_neighborhood_get_broadcast(bcid, nics.keys);
            else
                ret = stub_factory.i_neighborhood_get_broadcast(bcid, nics.keys,
                         new NeighborhoodAcknowledgementsCommunicator(bcid, nics.keys, this, missing_handler));
            return ret;
        }

        /* Get a client to call a broadcast remote method to one nic
         */
        public
        IAddressManagerRootDispatcher
        get_stub_broadcast_to_dev(string dev,
                             INeighborhoodMissingArcHandler? missing_handler=null,
                             INeighborhoodNodeID? ignore_neighbour=null)
        {
            var bcid = new BroadcastID(ignore_neighbour);
            IAddressManagerRootDispatcher ret;
            if (missing_handler == null)
                ret = stub_factory.i_neighborhood_get_broadcast_to_dev(bcid, dev);
            else
                ret = stub_factory.i_neighborhood_get_broadcast_to_dev(bcid, dev,
                         new NeighborhoodAcknowledgementsCommunicator(bcid, nics.keys, this, missing_handler));
            return ret;
        }

        /* Remotable methods
         */

        public void here_i_am(INeighborhoodNodeID its_id, string mac, string nic_addr, zcd.CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // This is called in broadcast. Maybe it's me.
            if (its_id.i_neighborhood_equals(my_id)) return;
            // It's a neighbour. The message comes from my_nic and its mac is mac.
            string my_dev = rpc_caller.my_dev;
            INeighborhoodNetworkInterface? my_nic
                    = get_monitoring_interface_from_dev(my_dev);
            if (my_nic == null)
            {
                log_warn(@"Neighborhood.here_i_am: $(my_dev) is not being monitored");
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
            // Is it on my network?
            if (! its_id.i_neighborhood_is_on_same_network(my_id))
            {
                // It's on different network. Emit signal and ignore message.
                network_collision(its_id);
                return;
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
            catch (RPCError e)
            {
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
                                zcd.CallerInfo? _rpc_caller=null) throws NeighborhoodRequestArcError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from my_nic and its mac is mac.
            // TODO check that nic_addr is in 100.64.0.0/10 class.
            // TODO check that nic_addr is not conflicting with mine or my neighbors' ones.
            string my_dev = rpc_caller.my_dev;
            INeighborhoodNetworkInterface? my_nic
                    = get_monitoring_interface_from_dev(my_dev);
            if (my_nic == null)
            {
                log_warn(@"Neighborhood.request_arc: $(my_dev) is not being monitored");
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
                        log_warn("Neighborhood.request_arc: " +
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
            // Is it on my network?
            if (! its_id.i_neighborhood_is_on_same_network(my_id))
            {
                // It's on different network. Refuse.
                throw new NeighborhoodRequestArcError.NOT_SAME_NETWORK(
                @"Refusing $(mac) because on different network.");
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

        public void expect_ping(int guid,
                                zcd.CallerInfo? _rpc_caller=null) throws RPCError
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from my_nic.
            INeighborhoodNetworkInterface my_nic = null;
            if (rpc_caller.my_dev != null)
                my_nic = get_monitoring_interface_from_dev(rpc_caller.my_dev);
            else
                my_nic = get_monitoring_interface_from_localaddr(rpc_caller.my_ip);
            if (my_nic == null)
            {
                string msg = @"not found handled interface for dev $(rpc_caller.my_dev) addr $(rpc_caller.my_ip)";
                log_warn(@"Neighborhood.expect_ping: $(msg)");
                throw new RPCError.GENERIC(msg);
            }
            // Use the callback saved in the INetworkInterface to prepare to
            // receive the ping.
            my_nic.i_neighborhood_prepare_ping((uint)guid);
        }

        public void remove_arc(INeighborhoodNodeID its_id, string mac, string nic_addr,
                                zcd.CallerInfo? _rpc_caller=null)
        {
            assert(_rpc_caller != null);
            CallerInfo rpc_caller = (CallerInfo)_rpc_caller;
            // The message comes from my_nic.
            INeighborhoodNetworkInterface my_nic = null;
            if (rpc_caller.my_dev != null)
                my_nic = get_monitoring_interface_from_dev(rpc_caller.my_dev);
            else
                my_nic = get_monitoring_interface_from_localaddr(rpc_caller.my_ip);
            if (my_nic == null)
            {
                string msg = @"not found handled interface for dev $(rpc_caller.my_dev) addr $(rpc_caller.my_ip)";
                log_warn(@"Neighborhood.remove_arc: $(msg)");
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
                }
            }
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

    // Defining extern functions.
    // Do not make them 'public', because they are not exposed by this
    // module (convenience library), but instead the module use them
    // as they are provided by the core app.
    extern void log_warn(string msg);
    extern void log_error(string msg);
}

