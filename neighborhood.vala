namespace Netsukuku.Neighborhood
{
    public interface INodeID : Object
    {
        public abstract bool equals(INodeID other);
    }

    public class REM : Object
    {
    }

    public interface IArc : Object
    {
        public abstract INodeID get_neighbour_id();
        public abstract REM get_cost();
        public abstract bool equals(IArc other);
    }

    internal class RealArc : Object, IArc
    {
        public INodeID neighbour_id;
        public REM cost;
        public bool equals(IArc other)
        {
            // This kind of equality test is ok as long as I am sure
            // that this module is the only able to create an instance
            // of IArc and that it won't create more than one instance
            // for each arc.
            return other == this;
        }
        public INodeID get_neighbour_id()
        {
            return neighbour_id;
        }
        public REM get_cost()
        {
            return cost;
        }
    }

    public IArc get_dummy_arc(INodeID neighbour_id)
    {
        var ret = new RealArc();
        ret.cost = new REM();
        ret.neighbour_id = neighbour_id;
        return ret;
    }
}
