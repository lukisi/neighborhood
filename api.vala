/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
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

namespace Netsukuku.Neighborhood
{
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

    // NeighborhoodNodeID is in serializables.vala

    public interface INeighborhoodArc : Object
    {
        public abstract string neighbour_mac {get;}
        public abstract string neighbour_nic_addr {get;}
        public abstract NeighborhoodNodeID neighbour_id {get;}
        public abstract long cost {get;}
        public abstract INeighborhoodNetworkInterface nic {get;}
    }

    /* This interface is implemented by an object passed to the Neighbor manager
     * which uses it to actually obtain a stub to send messages to other nodes.
     */
    public interface INeighborhoodStubFactory : Object
    {
        public abstract INeighborhoodManagerStub
        get_broadcast_for_radar(INeighborhoodNetworkInterface nic);

        public abstract INeighborhoodManagerStub
                        get_tcp(
                            INeighborhoodArc arc,
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
}
