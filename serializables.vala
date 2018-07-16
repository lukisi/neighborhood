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

namespace Netsukuku.Neighborhood
{
    internal class NeighborhoodNodeID : Object, INeighborhoodNodeIDMessage
    {
        public NeighborhoodNodeID()
        {
            id = PRNGen.int_range(1, int.MAX);
        }
        public int id {get; set;}

        public bool equals(NeighborhoodNodeID other)
        {
            return id == other.id;
        }
    }

    internal class WholeNodeSourceID : Object, ISourceID
    {
        public WholeNodeSourceID(NeighborhoodNodeID id)
        {
            this.id = id;
        }
        public NeighborhoodNodeID id {get; set;}
    }

    internal class WholeNodeUnicastID : Object, IUnicastID
    {
    }

    internal class EveryWholeNodeBroadcastID : Object, IBroadcastID
    {
    }

    internal class IdentityAwareSourceID : Object, ISourceID
    {
        public IdentityAwareSourceID(NodeID id)
        {
            this.id = id;
        }
        public NodeID id {get; set;}
    }

    internal class IdentityAwareUnicastID : Object, IUnicastID
    {
        public IdentityAwareUnicastID(NodeID id)
        {
            this.id = id;
        }
        public NodeID id {get; set;}
    }

    internal class IdentityAwareBroadcastID : Object, Json.Serializable, IBroadcastID
    {
        public IdentityAwareBroadcastID(Gee.List<NodeID> id_set)
        {
            this.id_set = new ArrayList<NodeID>((a, b) => a.equals(b));
            this.id_set.add_all(id_set);
        }
        public Gee.List<NodeID> id_set {get; set;}

        public bool deserialize_property
        (string property_name,
         out GLib.Value @value,
         GLib.ParamSpec pspec,
         Json.Node property_node)
        {
            @value = 0;
            switch (property_name) {
            case "id_set":
            case "id-set":
                try {
                    @value = deserialize_list_node_id(property_node);
                } catch (HelperDeserializeError e) {
                    return false;
                }
                break;
            default:
                return false;
            }
            return true;
        }

        public unowned GLib.ParamSpec? find_property
        (string name)
        {
            return get_class().find_property(name);
        }

        public Json.Node serialize_property
        (string property_name,
         GLib.Value @value,
         GLib.ParamSpec pspec)
        {
            switch (property_name) {
            case "id_set":
            case "id-set":
                return serialize_list_node_id((Gee.List<NodeID>)@value);
            default:
                error(@"wrong param $(property_name)");
            }
        }
    }

    internal errordomain HelperDeserializeError {
        GENERIC
    }

    internal Object? deserialize_object(Type expected_type, bool nullable, Json.Node property_node)
    throws HelperDeserializeError
    {
        Json.Reader r = new Json.Reader(property_node.copy());
        if (r.get_null_value())
        {
            if (!nullable)
                throw new HelperDeserializeError.GENERIC("element is not nullable");
            return null;
        }
        if (!r.is_object())
            throw new HelperDeserializeError.GENERIC("element must be an object");
        string typename;
        if (!r.read_member("typename"))
            throw new HelperDeserializeError.GENERIC("element must have typename");
        if (!r.is_value())
            throw new HelperDeserializeError.GENERIC("typename must be a string");
        if (r.get_value().get_value_type() != typeof(string))
            throw new HelperDeserializeError.GENERIC("typename must be a string");
        typename = r.get_string_value();
        r.end_member();
        Type type = Type.from_name(typename);
        if (type == 0)
            throw new HelperDeserializeError.GENERIC(@"typename '$(typename)' unknown class");
        if (!type.is_a(expected_type))
            throw new HelperDeserializeError.GENERIC(@"typename '$(typename)' is not a '$(expected_type.name())'");
        if (!r.read_member("value"))
            throw new HelperDeserializeError.GENERIC("element must have value");
        r.end_member();
        unowned Json.Node p_value = property_node.get_object().get_member("value");
        Json.Node cp_value = p_value.copy();
        return Json.gobject_deserialize(type, cp_value);
    }

    internal Json.Node serialize_object(Object obj)
    {
        Json.Builder b = new Json.Builder();
        b.begin_object();
        b.set_member_name("typename");
        b.add_string_value(obj.get_type().name());
        b.set_member_name("value");
        b.add_value(Json.gobject_serialize(obj));
        b.end_object();
        return b.get_root();
    }

    internal class ListDeserializer<T> : Object
    {
        internal Gee.List<T> deserialize_list_object(Json.Node property_node)
        throws HelperDeserializeError
        {
            ArrayList<T> ret = new ArrayList<T>();
            Json.Reader r = new Json.Reader(property_node.copy());
            if (r.get_null_value())
                throw new HelperDeserializeError.GENERIC("element is not nullable");
            if (!r.is_array())
                throw new HelperDeserializeError.GENERIC("element must be an array");
            int l = r.count_elements();
            for (uint j = 0; j < l; j++)
            {
                unowned Json.Node p_value = property_node.get_array().get_element(j);
                Json.Node cp_value = p_value.copy();
                ret.add(deserialize_object(typeof(T), false, cp_value));
            }
            return ret;
        }
    }

    internal Json.Node serialize_list_object(Gee.List<Object> lst)
    {
        Json.Builder b = new Json.Builder();
        b.begin_array();
        foreach (Object obj in lst)
        {
            b.add_value(serialize_object(obj));
        }
        b.end_array();
        return b.get_root();
    }

    internal Gee.List<NodeID> deserialize_list_node_id(Json.Node property_node)
    throws HelperDeserializeError
    {
        ListDeserializer<NodeID> c = new ListDeserializer<NodeID>();
        var first_ret = c.deserialize_list_object(property_node);
        // N.B. list of NeighborhoodNodeID must be searchable for the Neighborhood module to work.
        var ret = new ArrayList<NodeID>((a, b) => a.equals(b));
        ret.add_all(first_ret);
        return ret;
    }

    internal Json.Node serialize_list_node_id(Gee.List<NodeID> lst)
    {
        return serialize_list_object(lst);
    }
}
