namespace Netsukuku
{
    public class MyNodeID : Object, Neighborhood.INodeID
    {
        private int id;
        private static int progr = 0;
        public MyNodeID()
        {
            id = progr++;
        }

        public bool equals(Neighborhood.INodeID other)
        {
            if (!(other is MyNodeID)) return false;
            return id == (other as MyNodeID).id;
        }
    }

    void main()
    {
        // generate my nodeID
        Neighborhood.INodeID id = new MyNodeID();
        assert(id.equals(id));
        Neighborhood.IArc a1 = Neighborhood.get_dummy_arc(id);
        Neighborhood.IArc a2 = Neighborhood.get_dummy_arc(id);
        assert(a1.equals(a1));
        assert(!a1.equals(a2));
        assert(a1.get_neighbour_id().equals(a2.get_neighbour_id()));
        Neighborhood.INodeID id2 = new MyNodeID();
        assert(! id2.equals(id));

        // This should be invalid code.
        var ret = new Neighborhood.RealArc();
    }
}

