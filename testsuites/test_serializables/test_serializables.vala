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

void print_object(Object obj)
{
    print(@"$(obj.get_type().name())\n");
    string t = json_string_object(obj);
    print(@"$(t)\n");
}

public interface Netsukuku.INeighborhoodNodeIDMessage : Object {}

class NeighborhoodTester : Object
{
    public void set_up ()
    {
    }

    public void tear_down ()
    {
    }

    public void test_NeighborhoodNodeID()
    {
        int id1;
        int id2;

        NeighborhoodNodeID nn1;
        {
            Json.Node node;
            {
                NeighborhoodNodeID nn = new NeighborhoodNodeID();
                id1 = nn.id;
                node = Json.gobject_serialize(nn);
            }
            nn1 = (NeighborhoodNodeID)Json.gobject_deserialize(typeof(NeighborhoodNodeID), node);
        }
        assert(nn1.id == id1);

        NeighborhoodNodeID nn2;
        {
            Json.Node node;
            {
                NeighborhoodNodeID nn = new NeighborhoodNodeID();
                id2 = nn.id;
                node = Json.gobject_serialize(nn);
            }
            nn2 = (NeighborhoodNodeID)Json.gobject_deserialize(typeof(NeighborhoodNodeID), node);
        }
        assert(nn2.id == id2);

        assert(id1 != id2);
    }

    public static int main(string[] args)
    {
        PRNGen.init_rngen(null, null);
        GLib.Test.init(ref args);
        GLib.Test.add_func ("/Serializables/NeighborhoodNodeID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_NeighborhoodNodeID();
            x.tear_down();
        });
        GLib.Test.run();
        return 0;
    }
}

