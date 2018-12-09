using Netsukuku.Neighborhood;

using Gee;
using Netsukuku;
using TaskletSystem;

namespace TestHereiam
{

    [CCode (array_length = false, array_null_terminated = true)]
    string[] interfaces;
    int pid;

    ITasklet tasklet;
    NeighborhoodManager? neighborhood_mgr;
    SkeletonFactory skeleton_factory;
    StubFactory stub_factory;

    ArrayList<string> listen_pathname_list;

    int main(string[] _args)
    {
        OptionContext oc = new OptionContext("<options>");
        OptionEntry[] entries = new OptionEntry[3];
        int index = 0;
        entries[index++] = {"pid", 'p', 0, OptionArg.INT, ref pid, "Fake PID (e.g. -p 1234).", null};
        entries[index++] = {"interfaces", 'i', 0, OptionArg.STRING_ARRAY, ref interfaces, "Interface (e.g. -i eth1). You can use it multiple times.", null};
        entries[index++] = { null };
        oc.add_main_entries(entries, null);
        try {
            oc.parse(ref _args);
        }
        catch (OptionError e) {
            print(@"Error parsing options: $(e.message)\n");
            return 1;
        }

        ArrayList<string> args = new ArrayList<string>.wrap(_args);

        ArrayList<string> devs;
        // Names of the network interfaces to monitor.
        devs = new ArrayList<string>();
        foreach (string dev in interfaces) devs.add(dev);

        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // Initialize modules that have remotable methods (serializable classes need to be registered).
        NeighborhoodManager.init(tasklet);
        //typeof(MainIdentitySourceID).class_peek();

        // Initialize pseudo-random number generators.
        uint32 seed_prn = 0;
        if (devs.size > 0)
        {
            string _seed = @"$(pid)_$(devs[0])";
            seed_prn = (uint32)_seed.hash();
        }
        //PRNGen.init_rngen(null, seed_prn);
        NeighborhoodManager.init_rngen(null, seed_prn);

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(tasklet);

        // RPC
        skeleton_factory = new SkeletonFactory();
        stub_factory = new StubFactory();
        // The RPC library will need many tasklets for stream/datagram listeners.
        // All of them will be identified by a string listen_pathname
        listen_pathname_list = new ArrayList<string>();
        // The tasklets will be launched after the NeighborhoodManager is
        // created and ready to start_monitor.

        // Init module Neighborhood
        neighborhood_mgr = new NeighborhoodManager(
            1000 /*very high max_arcs*/,
            new NeighborhoodStubFactory(),
            new NeighborhoodQueryCallerInfo(),
            new NeighborhoodIPRouteManager(),
            () => @"169.254.$(PRNGen.int_range(0, 255)).$(PRNGen.int_range(0, 255))");
        skeleton_factory.whole_node_id = neighborhood_mgr.get_my_neighborhood_id();
        // connect signals
        neighborhood_mgr.nic_address_set.connect(neighborhood_nic_address_set);
        neighborhood_mgr.arc_added.connect(neighborhood_arc_added);
        neighborhood_mgr.arc_changed.connect(neighborhood_arc_changed);
        neighborhood_mgr.arc_removing.connect(neighborhood_arc_removing);
        neighborhood_mgr.arc_removed.connect(neighborhood_arc_removed);
        neighborhood_mgr.nic_address_unset.connect(neighborhood_nic_address_unset);

        error("TODO");
    }
}