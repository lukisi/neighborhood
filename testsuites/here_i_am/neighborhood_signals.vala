using Gee;
using Netsukuku;
using Netsukuku.Neighborhood;
using TaskletSystem;

namespace TestHereiam
{
    void neighborhood_nic_address_set(INeighborhoodNetworkInterface nic, string my_addr)
    {
        string dev = nic.dev;
        PseudoNetworkInterface pseudonic = pseudonic_map[dev];
        pseudonic.linklocal = my_addr;
        pseudonic.st_listen_pathname = @"conn_$(my_addr)";
        skeleton_factory.start_stream_system_listen(pseudonic.st_listen_pathname);
    }

    void neighborhood_arc_added(INeighborhoodArc neighborhood_arc)
    {
        error("not implemented yet");
    }

    void neighborhood_arc_changed(INeighborhoodArc neighborhood_arc)
    {
        error("not implemented yet");
    }

    void neighborhood_arc_removing(INeighborhoodArc neighborhood_arc, bool is_still_usable)
    {
        error("not implemented yet");
    }

    void neighborhood_arc_removed(INeighborhoodArc neighborhood_arc)
    {
        error("not implemented yet");
    }

    void neighborhood_nic_address_unset(INeighborhoodNetworkInterface nic, string my_addr)
    {
    }
}
