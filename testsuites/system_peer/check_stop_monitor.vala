using Netsukuku.Neighborhood;

using Gee;
using Netsukuku;
using TaskletSystem;

namespace SystemPeer
{
    void stop_monitor(ArrayList<string> devs)
    {
        string dev = devs.remove_at(devs.size-1);
        PseudoNetworkInterface pseudonic = pseudonic_map[dev];
        skeleton_factory.stop_stream_system_listen(pseudonic.st_listen_pathname);
        print(@"stopped stream_system_listen $(pseudonic.st_listen_pathname).\n");
        neighborhood_mgr.stop_monitor(dev);
        skeleton_factory.stop_datagram_system_listen(pseudonic.listen_pathname);
        print(@"stopped datagram_system_listen $(pseudonic.listen_pathname).\n");
    }

    class StopMonitorTasklet : Object, ITaskletSpawnable
    {
        public StopMonitorTasklet(ArrayList<string> devs)
        {
            this.devs = devs;
        }
        private ArrayList<string> devs;

        public void * func()
        {
            tasklet.ms_wait(3000);
            stop_monitor(devs);
            return null;
        }
    }
}