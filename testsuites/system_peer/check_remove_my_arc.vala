using Netsukuku.Neighborhood;

using Gee;
using Netsukuku;
using TaskletSystem;

namespace SystemPeer
{
    void remove_my_arc()
    {
        //
    }

    class RemoveArcTasklet : Object, ITaskletSpawnable
    {
        public void * func()
        {
            tasklet.ms_wait(2000);
            remove_my_arc();
            return null;
        }
    }
}