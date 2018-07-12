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

    public void test_NodeID()
    {
        NodeID n0;
        {
            Json.Node node;
            {
                NodeID n = new NodeID(2);
                node = Json.gobject_serialize(n);
            }
            n0 = (NodeID)Json.gobject_deserialize(typeof(NodeID), node);
        }
        assert(n0.id == 2);
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

    int nn_1_id = 0;
    NeighborhoodNodeID make_nn_1() {
        var ret = new NeighborhoodNodeID();
        nn_1_id = ret.id;
        return ret;
    }

    void test_nn_1(NeighborhoodNodeID nn1) {
        assert(nn1.id == nn_1_id);
    }

    int nn_2_id = 0;
    NeighborhoodNodeID make_nn_2() {
        var ret = new NeighborhoodNodeID();
        nn_2_id = ret.id;
        return ret;
    }

    void test_nn_2(NeighborhoodNodeID nn2) {
        assert(nn2.id == nn_2_id);
    }

    public void test_WholeNodeSourceID()
    {
        WholeNodeSourceID wns0;
        {
            Json.Node node;
            {
                WholeNodeSourceID wns = new WholeNodeSourceID(make_nn_1());
                node = Json.gobject_serialize(wns);
            }
            wns0 = (WholeNodeSourceID)Json.gobject_deserialize(typeof(WholeNodeSourceID), node);
        }
        test_nn_1(wns0.id);
    }

    public void test_WholeNodeUnicastID()
    {
        WholeNodeUnicastID wnu0;
        {
            Json.Node node;
            {
                WholeNodeUnicastID wnu = new WholeNodeUnicastID();
                node = Json.gobject_serialize(wnu);
            }
            wnu0 = (WholeNodeUnicastID)Json.gobject_deserialize(typeof(WholeNodeUnicastID), node);
        }
    }

    public void test_WholeNodeBroadcastID()
    {
        WholeNodeBroadcastID wnb0;
        {
            Json.Node node;
            {
                WholeNodeBroadcastID wnb = new WholeNodeBroadcastID
                    (new ArrayList<NeighborhoodNodeID>.wrap({make_nn_1(), make_nn_2()}));
                node = Json.gobject_serialize(wnb);
            }
            wnb0 = (WholeNodeBroadcastID)Json.gobject_deserialize(typeof(WholeNodeBroadcastID), node);
        }
        assert(wnb0.id_set.size == 2);
        test_nn_1(wnb0.id_set[0]);
        test_nn_2(wnb0.id_set[1]);
    }

    public void test_NoArcWholeNodeUnicastID()
    {
        NoArcWholeNodeUnicastID na0;
        {
            Json.Node node;
            {
                NoArcWholeNodeUnicastID na = new NoArcWholeNodeUnicastID(make_nn_1(), "CAFE123456");
                node = Json.gobject_serialize(na);
            }
            na0 = (NoArcWholeNodeUnicastID)Json.gobject_deserialize(typeof(NoArcWholeNodeUnicastID), node);
        }
        test_nn_1(na0.id);
        assert(na0.mac == "CAFE123456");
    }

    public void test_EveryWholeNodeBroadcastID()
    {
        EveryWholeNodeBroadcastID ewb0;
        {
            Json.Node node;
            {
                EveryWholeNodeBroadcastID ewb = new EveryWholeNodeBroadcastID();
                node = Json.gobject_serialize(ewb);
            }
            ewb0 = (EveryWholeNodeBroadcastID)Json.gobject_deserialize(typeof(EveryWholeNodeBroadcastID), node);
        }
    }

    NodeID make_n_1() {
        return new NodeID(1);
    }

    void test_n_1(NodeID n1) {
        assert(n1.id == 1);
    }

    NodeID make_n_2() {
        return new NodeID(2);
    }

    void test_n_2(NodeID n2) {
        assert(n2.id == 2);
    }

    public void test_IdentityAwareSourceID()
    {
        IdentityAwareSourceID ias0;
        {
            Json.Node node;
            {
                IdentityAwareSourceID ias = new IdentityAwareSourceID(make_n_1());
                node = Json.gobject_serialize(ias);
            }
            ias0 = (IdentityAwareSourceID)Json.gobject_deserialize(typeof(IdentityAwareSourceID), node);
        }
        test_n_1(ias0.id);
    }

    public void test_IdentityAwareUnicastID()
    {
        IdentityAwareUnicastID iau0;
        {
            Json.Node node;
            {
                IdentityAwareUnicastID iau = new IdentityAwareUnicastID(make_n_1());
                node = Json.gobject_serialize(iau);
            }
            iau0 = (IdentityAwareUnicastID)Json.gobject_deserialize(typeof(IdentityAwareUnicastID), node);
        }
        test_n_1(iau0.id);
    }

    public void test_IdentityAwareBroadcastID()
    {
        IdentityAwareBroadcastID iab0;
        {
            Json.Node node;
            {
                IdentityAwareBroadcastID iab = new IdentityAwareBroadcastID
                    (new ArrayList<NodeID>.wrap({make_n_1(), make_n_2()}));
                node = Json.gobject_serialize(iab);
            }
            iab0 = (IdentityAwareBroadcastID)Json.gobject_deserialize(typeof(IdentityAwareBroadcastID), node);
        }
        assert(iab0.id_set.size == 2);
        test_n_1(iab0.id_set[0]);
        test_n_2(iab0.id_set[1]);
    }

    public static int main(string[] args)
    {
        PRNGen.init_rngen(null, null);
        GLib.Test.init(ref args);
        GLib.Test.add_func ("/Serializables/NodeID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_NodeID();
            x.tear_down();
        });
        GLib.Test.add_func ("/Serializables/NeighborhoodNodeID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_NeighborhoodNodeID();
            x.tear_down();
        });
        GLib.Test.add_func ("/Serializables/WholeNodeSourceID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_WholeNodeSourceID();
            x.tear_down();
        });
        GLib.Test.add_func ("/Serializables/WholeNodeUnicastID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_WholeNodeUnicastID();
            x.tear_down();
        });
        GLib.Test.add_func ("/Serializables/WholeNodeBroadcastID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_WholeNodeBroadcastID();
            x.tear_down();
        });
        GLib.Test.add_func ("/Serializables/NoArcWholeNodeUnicastID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_NoArcWholeNodeUnicastID();
            x.tear_down();
        });
        GLib.Test.add_func ("/Serializables/EveryWholeNodeBroadcastID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_EveryWholeNodeBroadcastID();
            x.tear_down();
        });
        GLib.Test.add_func ("/Serializables/IdentityAwareSourceID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_IdentityAwareSourceID();
            x.tear_down();
        });
        GLib.Test.add_func ("/Serializables/IdentityAwareUnicastID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_IdentityAwareUnicastID();
            x.tear_down();
        });
        GLib.Test.add_func ("/Serializables/IdentityAwareBroadcastID", () => {
            var x = new NeighborhoodTester();
            x.set_up();
            x.test_IdentityAwareBroadcastID();
            x.tear_down();
        });
        GLib.Test.run();
        return 0;
    }
}

