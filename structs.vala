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
    internal class NeighborhoodRealArc : Object, INeighborhoodArc
    {
        private NeighborhoodNodeID _neighbour_id;
        private string _mac;
        private string _nic_addr;
        private long? _cost;
        private INeighborhoodNetworkInterface _my_nic;
        public bool available {
            public get {
                return _cost != null;
            }
        }
        public bool exported;

        public NeighborhoodRealArc(NeighborhoodNodeID neighbour_id,
                       string mac,
                       string nic_addr,
                       INeighborhoodNetworkInterface my_nic)
        {
            _neighbour_id = neighbour_id;
            _mac = mac;
            _nic_addr = nic_addr;
            _my_nic = my_nic;
            _cost = null;
            exported = false;
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
}
