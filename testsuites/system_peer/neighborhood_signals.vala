using Gee;
using Netsukuku;
using Netsukuku.Neighborhood;
using TaskletSystem;

namespace SystemPeer
{
    void neighborhood_nic_address_set(INeighborhoodNetworkInterface nic, string my_addr)
    {
        print(@"signal nic_address_set $(my_addr).\n");
        string dev = nic.dev;
        PseudoNetworkInterface pseudonic = pseudonic_map[dev];
        pseudonic.linklocal = my_addr;
        pseudonic.st_listen_pathname = @"conn_$(my_addr)";
        skeleton_factory.start_stream_system_listen(pseudonic.st_listen_pathname);
        print(@"started stream_system_listen $(pseudonic.st_listen_pathname).\n");
    }

    void neighborhood_arc_added(INeighborhoodArc neighborhood_arc)
    {
        print(@"signal arc_added.\n");
        if (do_count_arcs) arcs_count++;
    }

    void neighborhood_arc_changed(INeighborhoodArc neighborhood_arc)
    {
        print(@"signal arc_changed.\n");
    }

    void neighborhood_arc_removing(INeighborhoodArc neighborhood_arc, bool is_still_usable)
    {
        print(@"signal arc_removing.\n");
    }

    void neighborhood_arc_removed(INeighborhoodArc neighborhood_arc)
    {
        print(@"signal arc_removed.\n");
    }

    void neighborhood_nic_address_unset(INeighborhoodNetworkInterface nic, string my_addr)
    {
        print(@"signal nic_address_unset $(my_addr).\n");
    }
}
