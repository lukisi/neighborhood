using Netsukuku.Neighborhood;

using Gee;
using Netsukuku;
using TaskletSystem;

namespace SystemPeer
{
    void do_check_remove_my_arc()
    {
        //
    }

    class RemoveArcTasklet : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(2000);
            do_check_remove_my_arc();
            return null;
        }
    }
}