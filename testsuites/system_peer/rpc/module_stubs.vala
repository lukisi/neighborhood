using Gee;
using Netsukuku;
using Netsukuku.Neighborhood;
using TaskletSystem;

namespace SystemPeer
{
    class NeighborhoodManagerStubHolder : Object, INeighborhoodManagerStub
    {
        public NeighborhoodManagerStubHolder(IAddressManagerStub addr)
        {
            this.addr = addr;
        }
        private IAddressManagerStub addr;

        public bool can_you_export(bool i_can_export)
        throws StubError, DeserializeError
        {
            return addr.neighborhood_manager.can_you_export(i_can_export);
        }

        public void here_i_am(INeighborhoodNodeIDMessage my_id, string my_mac, string my_nic_addr)
        throws StubError, DeserializeError
        {
            addr.neighborhood_manager.here_i_am(my_id, my_mac, my_nic_addr);
        }

        public void nop()
        throws StubError, DeserializeError
        {
            addr.neighborhood_manager.nop();
        }

        public void remove_arc
        (INeighborhoodNodeIDMessage your_id, string your_mac, string your_nic_addr,
        INeighborhoodNodeIDMessage my_id, string my_mac, string my_nic_addr)
        throws StubError, DeserializeError
        {
            addr.neighborhood_manager.remove_arc(your_id, your_mac, your_nic_addr,
                my_id, my_mac, my_nic_addr);
        }

        public void request_arc(INeighborhoodNodeIDMessage your_id, string your_mac, string your_nic_addr,
        INeighborhoodNodeIDMessage my_id, string my_mac, string my_nic_addr)
        throws StubError, DeserializeError
        {
            addr.neighborhood_manager.request_arc(your_id, your_mac, your_nic_addr,
                my_id, my_mac, my_nic_addr);
        }
    }
}