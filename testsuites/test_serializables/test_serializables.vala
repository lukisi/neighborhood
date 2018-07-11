/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2018 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;
using Netsukuku;
using Netsukuku.Neighborhood;

string json_string_object(Object obj)
{
    Json.Node n = Json.gobject_serialize(obj);
    Json.Generator g = new Json.Generator();
    g.root = n;
    g.pretty = true;
    string ret = g.to_data(null);
    return ret;
}


// fake
public interface Netsukuku.INeighborhoodNodeIDMessage : Object {}
public interface Netsukuku.ISourceID : Object {}
public interface Netsukuku.IUnicastID : Object {}
public interface Netsukuku.IBroadcastID : Object {}
namespace Netsukuku
{
    public class HCoord : Object
    {
        public int lvl {get; set;}
        public int pos {get; set;}
        public HCoord(int lvl, int pos)
        {
            this.lvl = lvl;
            this.pos = pos;
        }

        public bool equals(HCoord other)
        {
            return lvl == other.lvl && pos == other.pos;
        }
    }

    public class NodeID : Object
    {
        public int id {get; set;}
        public NodeID(int id)
        {
            this.id = id;
        }

        public bool equals(NodeID other)
        {
            return id == other.id;
        }
    }
}

void print_object(Object obj)
{
    print(@"$(obj.get_type().name())\n");
    string t = json_string_object(obj);
    print(@"$(t)\n");
}

class NeighborhoodTester : Object
{
    public void set_up ()
    {
    }

    public void tear_down ()
    {
    }

    public static int main(string[] args)
    {
        PRNGen.init_rngen(null, null);
        GLib.Test.init(ref args);
        // TODO
/*
        GLib.Test.add_func ("/Serializables/NetworkData", () => {
            var x = new HookingTester();
            x.set_up();
            x.test_NetworkData();
            x.tear_down();
        });
*/
        GLib.Test.run();
        return 0;
    }
}

