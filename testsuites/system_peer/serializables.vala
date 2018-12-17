using Netsukuku;
using Netsukuku.Neighborhood;

namespace SystemPeer
{
    public class WholeNodeSourceID : Object, ISourceID
    {
        public WholeNodeSourceID(NeighborhoodNodeID id)
        {
            this.id = id;
        }
        public NeighborhoodNodeID id {get; set;}
    }

    public class WholeNodeUnicastID : Object, IUnicastID
    {
        public WholeNodeUnicastID(NeighborhoodNodeID neighbour_id)
        {
            this.neighbour_id = neighbour_id;
        }
        public NeighborhoodNodeID neighbour_id {get; set;}
    }

    public class EveryWholeNodeBroadcastID : Object, IBroadcastID
    {
    }

    public class NeighbourSrcNic : Object, ISrcNic
    {
        public NeighbourSrcNic(string mac)
        {
            this.mac = mac;
        }
        public string mac {get; set;}
    }
}