using Netsukuku.Neighborhood;

using Gee;
using Netsukuku;
using TaskletSystem;

namespace SystemPeer
{
    void do_check_stop_monitor(ArrayList<string> devs)
    {
        string dev = devs.remove_at(devs.size-1);
        stop_monitor(dev);
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
            do_check_stop_monitor(devs);
            return null;
        }
    }
}