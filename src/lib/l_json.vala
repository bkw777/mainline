// Remove this file after bionic no longer supported.
// These are not as bulletproof as Json.get_*_member_with_default(),
// but those don't exist before json-glib 1.6


#if GLIB_JSON_1_6
#else

using Json;

namespace l_json {

	public int json_get_int(Json.Object jobj, string member, int def=0) {
		if (!jobj.has_member(member)) return def;
		return (int)jobj.get_int_member(member);
	}

	public double json_get_double(Json.Object jobj, string member, double def=0) {
		if (!jobj.has_member(member)) return def;
		return jobj.get_double_member(member);
	}

	public bool json_get_bool(Json.Object jobj, string member, bool def=false) {
		if (!jobj.has_member(member)) return def;
		return jobj.get_boolean_member(member);
	}

	public string json_get_string(Json.Object jobj, string member, string def="") {
		if (jobj.get_string_member(member)==null) return def;
		return jobj.get_string_member(member);
	}

}

#endif
