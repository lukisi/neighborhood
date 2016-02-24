using Gee;
using TestSerializeInternals;

namespace Netsukuku
{
    internal class NeighborhoodNodeID : Object
    {
        public NeighborhoodNodeID(int id)
        {
            this.id = id;
        }
        public int id {get; set;}

        public bool equals(NeighborhoodNodeID other)
        {
            return id == other.id;
        }
    }

    internal class NodeID : Object
    {
        public NodeID(int id)
        {
            this.id = id;
        }
        public int id {get; set;}

        public bool equals(NodeID other)
        {
            return id == other.id;
        }
    }

    void main() {
        try {
            bool first = true;
            while(first) // while(true)   - to check memory growth
            {
              {
                Gee.List<NeighborhoodNodeID> lst0 = new ArrayList<NeighborhoodNodeID>();
                lst0.add(new NeighborhoodNodeID(12));
                lst0.add(new NeighborhoodNodeID(23));
                Json.Node x = serialize_list_neighborhood_node_id(lst0);
                if (first) print("serialized.\n");
                Gee.List<NeighborhoodNodeID> lst1 = deserialize_list_neighborhood_node_id(x);
                if (first) print("deserialized.\n");
                assert(lst1[0].id == 12);
                assert(lst1[1].id == 23);
              }

              {
                Gee.List<NodeID> lst0 = new ArrayList<NodeID>();
                lst0.add(new NodeID(12));
                lst0.add(new NodeID(23));
                Json.Node x = serialize_list_node_id(lst0);
                if (first) print("serialized.\n");
                Gee.List<NodeID> lst1 = deserialize_list_node_id(x);
                if (first) print("deserialized.\n");
                assert(lst1[0].id == 12);
                assert(lst1[1].id == 23);
              }

              first = false;
            }
        } catch (HelperDeserializeError e) {assert_not_reached();}
    }
}

