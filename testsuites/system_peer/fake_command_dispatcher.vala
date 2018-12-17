using Gee;
using TaskletSystem;

namespace SystemPeer
{
    internal string cmd_repr(ArrayList<string> cmd_args)
    {
        string cmd = ""; string sep = "";
        foreach (string arg in cmd_args)
        {
            cmd += sep;
            if (" " in arg) cmd += @"'$(arg)'";
            else cmd += arg;
            sep = " ";
        }
        return cmd;
    }

    class FakeCommandDispatcher : Object
    {
        public FakeCommandDispatcher()
        {
            command_dispatcher = tasklet.create_dispatchable_tasklet();
            blocks = new HashMap<int, BeginBlockTasklet>();
            next_block_id = 0;
        }

        private DispatchableTasklet command_dispatcher;

        // Single command

        public void single_command(ArrayList<string> cmd_args, bool wait=true)
        {
            SingleCommandTasklet ts = new SingleCommandTasklet();
            ts.cm_t = this;
            ts.cmd_args = cmd_args;
            command_dispatcher.dispatch(ts, wait);
        }
        class SingleCommandTasklet : Object, ITaskletSpawnable
        {
            public FakeCommandDispatcher cm_t;
            public ArrayList<string> cmd_args;
            public void * func()
            {
                cm_t.tasklet_single_command(cmd_args);
                return null;
            }
        }
        private void tasklet_single_command(ArrayList<string> cmd_args)
        {
            string cmd = cmd_repr(cmd_args);
            print(@"$$ $(cmd)\n");
            // simulate a command execution, which could take some time in the current tasklet.
            tasklet.ms_wait(10);
        }

        // Block of commands

        private HashMap<int, BeginBlockTasklet> blocks;
        private int next_block_id;
        public int begin_block()
        {
            int block_id = next_block_id++;
            blocks[block_id] = new BeginBlockTasklet(this);
            command_dispatcher.dispatch(blocks[block_id], false, true); // wait for start, not for end
            return block_id;
        }
        private class BeginBlockTasklet : Object, ITaskletSpawnable
        {
            public BeginBlockTasklet(FakeCommandDispatcher cm_t)
            {
                this.cm_t = cm_t;
                ch = tasklet.get_channel();
                cmds = new ArrayList<ArrayList<string>>();
            }

            private FakeCommandDispatcher cm_t;
            private IChannel ch;
            private ArrayList<ArrayList<string>> cmds;
            private bool wait;

            public void single_command_in_block(ArrayList<string> cmd_args)
            {
                cmds.add(cmd_args);
            }

            public void end_block(bool wait)
            {
                this.wait = wait;
                if (wait)
                {
                    ch.send(0);
                    ch.recv();
                }
                else
                {
                    ch.send_async(0);
                }
            }

            public void * func()
            {
                ch.recv();
                foreach (ArrayList<string> cmd_args in cmds) cm_t.tasklet_single_command(cmd_args);
                if (wait) ch.send(0);
                return null;
            }
        }

        public void single_command_in_block(int block_id, ArrayList<string> cmd_args)
        {
            assert(blocks.has_key(block_id));
            blocks[block_id].single_command_in_block(cmd_args);
        }

        public void end_block(int block_id, bool wait=true)
        {
            assert(blocks.has_key(block_id));
            blocks[block_id].end_block(wait);
            blocks.unset(block_id);
        }
    }
}
