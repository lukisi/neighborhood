using Netsukuku.Neighborhood;

using Gee;
using Netsukuku;
using TaskletSystem;

namespace TestHereiam
{

    [CCode (array_length = false, array_null_terminated = true)]
    string[] interfaces;
    int pid;
    int check_count_arcs;

    ITasklet tasklet;
    NeighborhoodManager? neighborhood_mgr;
    SkeletonFactory skeleton_factory;
    StubFactory stub_factory;
    bool do_count_arcs;
    int arcs_count;

    HashMap<string,PseudoNetworkInterface> pseudonic_map;

    int main(string[] _args)
    {
        pid = 0; // default
        check_count_arcs = -1; // default
        OptionContext oc = new OptionContext("<options>");
        OptionEntry[] entries = new OptionEntry[4];
        int index = 0;
        entries[index++] = {"pid", 'p', 0, OptionArg.INT, ref pid, "Fake PID (e.g. -p 1234).", null};
        entries[index++] = {"interfaces", 'i', 0, OptionArg.STRING_ARRAY, ref interfaces, "Interface (e.g. -i eth1). You can use it multiple times.", null};
        entries[index++] = {"check-count-arcs", '\0', 0, OptionArg.INT, ref check_count_arcs, "Finally check that this number of arcs were been added.", null};
        entries[index++] = { null };
        oc.add_main_entries(entries, null);
        try {
            oc.parse(ref _args);
        }
        catch (OptionError e) {
            print(@"Error parsing options: $(e.message)\n");
            return 1;
        }
        do_count_arcs = false; // default
        arcs_count = 0; // default

        ArrayList<string> args = new ArrayList<string>.wrap(_args);

        ArrayList<string> devs;
        // Names of the network interfaces to monitor.
        devs = new ArrayList<string>();
        foreach (string dev in interfaces) devs.add(dev);

        if (pid == 0) error("Bad usage");
        if (devs.is_empty) error("Bad usage");
        if (check_count_arcs != -1) do_count_arcs = true;

        // Initialize tasklet system
        PthTaskletImplementer.init();
        tasklet = PthTaskletImplementer.get_tasklet_system();

        // Initialize modules that have remotable methods (serializable classes need to be registered).
        NeighborhoodManager.init(tasklet);
        //typeof(MainIdentitySourceID).class_peek();
        typeof(WholeNodeSourceID).class_peek();
        typeof(WholeNodeUnicastID).class_peek();
        typeof(EveryWholeNodeBroadcastID).class_peek();
        typeof(NeighbourSrcNic).class_peek();

        // Initialize pseudo-random number generators.
        uint32 seed_prn = 0;
        if (devs.size > 0)
        {
            string _seed = @"$(pid)_$(devs[0])";
            seed_prn = (uint32)_seed.hash();
        }
        PRNGen.init_rngen(null, seed_prn);
        NeighborhoodManager.init_rngen(null, seed_prn);

        // Pass tasklet system to the RPC library (ntkdrpc)
        init_tasklet_system(tasklet);

        // RPC
        skeleton_factory = new SkeletonFactory();
        stub_factory = new StubFactory();

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

        pseudonic_map = new HashMap<string,PseudoNetworkInterface>();
        foreach (string dev in devs)
        {
            assert(!(dev in pseudonic_map.keys));
            string listen_pathname = @"recv_$(pid)_$(dev)";
            string send_pathname = @"send_$(pid)_$(dev)";
            string mac = @"fe:aa:aa:$(PRNGen.int_range(10, 99)):$(PRNGen.int_range(10, 99)):$(PRNGen.int_range(10, 99))";
            pseudonic_map[dev] = new PseudoNetworkInterface(dev, listen_pathname, send_pathname, mac);

            // Start listen datagram on dev
            skeleton_factory.start_datagram_system_listen(listen_pathname, send_pathname, new NeighbourSrcNic(mac));
            print(@"started datagram_system_listen $(listen_pathname) $(send_pathname) $(mac).\n");
            // Run monitor. This will also set the IP link-local address and the field will be compiled.
            neighborhood_mgr.start_monitor(pseudonic_map[dev].nic);
        }

        // Temporary: register handlers for SIGINT and SIGTERM to exit
        Posix.@signal(Posix.Signal.INT, safe_exit);
        Posix.@signal(Posix.Signal.TERM, safe_exit);
        // Main loop
        while (true)
        {
            tasklet.ms_wait(100);
            if (do_me_exit) break;
        }

        // Call stop_monitor of NeighborhoodManager.
        foreach (string dev in pseudonic_map.keys)
        {
            PseudoNetworkInterface pseudonic = pseudonic_map[dev];
            skeleton_factory.stop_stream_system_listen(pseudonic.st_listen_pathname);
            print(@"stopped stream_system_listen $(pseudonic.st_listen_pathname).\n");
            neighborhood_mgr.stop_monitor(dev);
            skeleton_factory.stop_datagram_system_listen(pseudonic.listen_pathname);
            print(@"stopped datagram_system_listen $(pseudonic.listen_pathname).\n");
        }

        // Then we destroy the object NeighborhoodManager.
        neighborhood_mgr = null;
        tasklet.ms_wait(100);

        PthTaskletImplementer.kill();

        //tests
        if (check_count_arcs != -1 && check_count_arcs != arcs_count) error(@"Wrong number of arcs: $(arcs_count).");

        return 0;
    }

    bool do_me_exit = false;
    void safe_exit(int sig)
    {
        // We got here because of a signal. Quick processing.
        do_me_exit = true;
    }

    class PseudoNetworkInterface : Object
    {
        public PseudoNetworkInterface(string dev, string listen_pathname, string send_pathname, string mac)
        {
            this.dev = dev;
            this.listen_pathname = listen_pathname;
            this.send_pathname = send_pathname;
            this.mac = mac;
            nic = new NeighborhoodNetworkInterface(this);
        }
        public string mac {get; private set;}
        public string send_pathname {get; private set;}
        public string listen_pathname {get; private set;}
        public string dev {get; private set;}
        public string linklocal {get; set;}
        public string st_listen_pathname {get; set;}
        public INeighborhoodNetworkInterface nic {get; set;}
    }
}