/*
 * Main.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using Json;

using l_misc;
using l_exec;

#if !GLIB_JSON_1_6
using l_json;
#endif

[CCode(cname="BRANDING_SHORTNAME")] extern const string BRANDING_SHORTNAME;
[CCode(cname="BRANDING_LONGNAME")] extern const string BRANDING_LONGNAME;
[CCode(cname="BRANDING_VERSION")] extern const string BRANDING_VERSION;
[CCode(cname="BRANDING_COPYRIGHT")] extern const string BRANDING_COPYRIGHT;
[CCode(cname="BRANDING_AUTHORNAME")] extern const string BRANDING_AUTHORNAME;
[CCode(cname="BRANDING_AUTHOREMAIL")] extern const string BRANDING_AUTHOREMAIL;
[CCode(cname="BRANDING_WEBSITE")] extern const string BRANDING_WEBSITE;
[CCode(cname="INSTALL_PREFIX")] extern const string INSTALL_PREFIX;
[CCode(cname="TRANSLATORS")] extern const string TRANSLATORS;

const string LOCALE_DIR = INSTALL_PREFIX + "/share/locale";
const string APP_LIB_DIR = INSTALL_PREFIX + "/lib/" + BRANDING_SHORTNAME;
const string CLI_EXE = BRANDING_SHORTNAME;
const string GUI_EXE = BRANDING_SHORTNAME+"-gtk";

//////////////////////////////////////////////////////////////////////////////
// CONFIG FILE DEFAULTS
// .h files are a pain in the ass in vala so dump these here

// network
const string   MATCH_PPA_URI_OLD_1             = "//kernel.ubuntu.com/~kernel-ppa/mainline/"; // obsolete 20231014
const string   DEFAULT_PPA_URI                 = "https://kernel.ubuntu.com/mainline/"; // new 20231014
const string   DEFAULT_ALL_PROXY               = ""    ;
const int      DEFAULT_CONNECT_TIMEOUT_SECONDS = 15    ;
const int      DEFAULT_CONCURRENT_DOWNLOADS    = 4     ;
const bool     DEFAULT_VERIFY_CHECKSUMS        = true  ;
const bool     DEFAULT_KEEP_DEBS               = false ;
const bool     DEFAULT_KEEP_CACHE              = false ;
// filters
const bool     DEFAULT_HIDE_INVALID            = true  ;
const bool     DEFAULT_HIDE_UNSTABLE           = true  ;
const bool     DEFAULT_HIDE_FLAVORS            = false ;
const int      DEFAULT_PREVIOUS_MAJORS         = 0     ;
// notifications
const bool     DEFAULT_NOTIFY_MAJOR            = false ;
const bool     DEFAULT_NOTIFY_MINOR            = false ;
const int      DEFAULT_NOTIFY_INTERVAL_VALUE   = 4     ;
const int      DEFAULT_NOTIFY_INTERVAL_UNIT    = 0     ;
// external commands - the first in each list is the default
const string[] DEFAULT_AUTH_CMDS = {
	"pkexec",
	//"pkexec env DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY}", // only needed for gui apps, we only run dpkg
	"sudo",
	"su -c \"%s\"",
	"doas",
	"lxsudo",
	"lxsu",
	"lxdoas",
	"gksudo",
	"gksu --su-mode",
	"pbrun"
};
// Terminal command must stay foreground and block, not fork and return immediately.
// Most terminal apps are like like xterm and naturally block by default.
// Some require special commandline options to make them block.
// Don't try to include wrappers like exo-open or x-terminal-emulator
// because the needed commandline options varies depending on the actual
// terminal app they happen to point to at any given time.
const string[] DEFAULT_TERM_CMDS = {
	"[internal-vte]",
	"gnome-terminal --wait --",
	"konsole --no-fork -e",
	"xfce4-terminal --disable-server -e \"%s\"",
	"lxterminal -e",
	"Eterm -e",
	"rxvt -name "+BRANDING_SHORTNAME+" -bg black -fg white -sr -e",
	"mate-terminal -e \"%s\"",
	"cool-retro-term -e",
	"sakura -e",
	"termit -e",
	"kitty",
	"qterminal -e",
	"mlterm -e",
	"pangoterm -e",
	"stterm -e",
	"pterm -e",
	"xterm -e"
};

// window sizes
const int      DEFAULT_WINDOW_WIDTH            = 800   ;
const int      DEFAULT_WINDOW_HEIGHT           = 600   ;
const int      DEFAULT_WINDOW_X                = -1    ;
const int      DEFAULT_WINDOW_Y                = -1    ;
const int      DEFAULT_TERM_WIDTH              = 1100  ;
const int      DEFAULT_TERM_HEIGHT             = 600   ;
const int      DEFAULT_TERM_X                  = -1    ;
const int      DEFAULT_TERM_Y                  = -1    ;
const double   DEFAULT_TERM_FONT_SCALE         = 1     ;

/* Translators: uppercase, or otherwise emphasized, display version of a single character for "yes",
 * string may be longer than one character. Examples: "Y" or "[y]" */
const string YN_Y = _("Y");
/* Translators: lowercase, or otherwise not-emphasized, single keypress user response for "yes",
 * Example: "y" */
const string YN_y = _("y");
/* Translators: uppercase, or otherwise emphasized, display version of a single character for "no",
 * string may be longer than one character. Examples: "N" or "[n]" */
const string YN_N = _("N");
/* Translators: lowercase, or otherwise not-emphasized, single keypress user response for "no",
 * Example: "n" */
const string YN_n = _("n");

enum SIG {
#if VALA_0_40
	HUP = Posix.Signal.HUP,
	INT = Posix.Signal.INT,
	TERM = Posix.Signal.TERM
#else
	HUP = Posix.SIGHUP,
	INT = Posix.SIGINT,
	TERM = Posix.SIGTERM
#endif
}

extern void exit(int exit_code);

//public class Main : GLib.Object {
public class Main : Application {

	// constants ----------
	public string CONFIG_DIR = "";
	public static string CACHE_DIR = "";
	public static string DATA_DIR = "";
	public string APP_CONFIG_FILE = "";
	public string STARTUP_SCRIPT_FILE = "";
	public string STARTUP_DESKTOP_FILE = "";
	public string NOTIFICATION_ID_FILE = "";
	public string MAJOR_SEEN_FILE = "";
	public string MINOR_SEEN_FILE = "";

	// global progress ----------------
	public string status_line = "";
	public int progress_total = 0;
	public int progress_count = 0;
	public bool cancelled = false;

	// state flags ----------
	public static int VERBOSE = 1;
	public string command = "";
	public string requested_versions = "";
	public bool ppa_tried = false;
	public bool ppa_up = true;
	public bool index_is_fresh = false;
	public bool RUN_NOTIFY_SCRIPT = false;
	public bool yes_mode = true;
	public bool no_mode = false;
	public bool gui_mode = false;

	// config
	public string ppa_uri              = DEFAULT_PPA_URI;
	public string all_proxy            = DEFAULT_ALL_PROXY;
	public int connect_timeout_seconds = DEFAULT_CONNECT_TIMEOUT_SECONDS;
	public int concurrent_downloads    = DEFAULT_CONCURRENT_DOWNLOADS;
	public bool hide_invalid           = DEFAULT_HIDE_INVALID;
	public bool hide_unstable          = DEFAULT_HIDE_UNSTABLE;
	public bool hide_flavors           = DEFAULT_HIDE_FLAVORS;
	public int previous_majors         = DEFAULT_PREVIOUS_MAJORS;
	public bool notify_major           = DEFAULT_NOTIFY_MAJOR;
	public bool notify_minor           = DEFAULT_NOTIFY_MINOR;
	public int notify_interval_unit    = DEFAULT_NOTIFY_INTERVAL_UNIT;
	public int notify_interval_value   = DEFAULT_NOTIFY_INTERVAL_VALUE;
	public bool verify_checksums       = DEFAULT_VERIFY_CHECKSUMS;
	public bool keep_debs              = DEFAULT_KEEP_DEBS;
	public bool keep_cache             = DEFAULT_KEEP_CACHE;
	public string auth_cmd             = DEFAULT_AUTH_CMDS[0];
	public string term_cmd             = DEFAULT_TERM_CMDS[0];
	// save & restore window size & position
	public int    window_width         = DEFAULT_WINDOW_WIDTH;
	public int    window_height        = DEFAULT_WINDOW_HEIGHT;
	public int    window_x             = DEFAULT_WINDOW_X;
	public int    window_y             = DEFAULT_WINDOW_Y;
	public int    term_width           = DEFAULT_TERM_WIDTH;
	public int    term_height          = DEFAULT_TERM_HEIGHT;
	public int    term_x               = DEFAULT_TERM_X;
	public int    term_y               = DEFAULT_TERM_Y;
	public double term_font_scale      = DEFAULT_TERM_FONT_SCALE;

	// commandline config overrides
	public bool? opt_hide_invalid    = null;
	public bool? opt_hide_unstable   = null;
	public bool? opt_hide_flavors    = null;
	public int?  opt_previous_majors = null;

	public static Rand rnd;

	public Main() {
		Intl.setlocale(LocaleCategory.ALL,"");
		get_env();
		vprint(BRANDING_SHORTNAME+" "+BRANDING_VERSION);
	}

	public void init2() {
		if (!Thread.supported()) { vprint(_("Missing threads support in GLib."),1,stderr); exit(1); }

		APP_CONFIG_FILE = CONFIG_DIR + "/config.json";
		STARTUP_SCRIPT_FILE = CONFIG_DIR + "/" + BRANDING_SHORTNAME + "-notify.sh";
		STARTUP_DESKTOP_FILE = CONFIG_DIR + "/autostart/" + BRANDING_SHORTNAME + "-notify.desktop";
		NOTIFICATION_ID_FILE = CONFIG_DIR + "/notification_id";
		MAJOR_SEEN_FILE = CONFIG_DIR + "/notification_seen.major";
		MINOR_SEEN_FILE = CONFIG_DIR + "/notification_seen.minor";

		rnd = new Rand();

		load_app_config();

		Package.initialize();
		LinuxKernel.initialize();
	}

	public void get_env() {
		// VERBOSE - do before any vprint() you want affected
		var s = Environment.get_variable("VERBOSE");
		if (s != null) set_verbose(s.down().strip());

		// TERM - set window title
		s = Environment.get_variable("TERM");
		string[] l = { "xterm", "linux", "ansi", "vt" };
		foreach (var t in l) if (s.contains(t)) { vprint("\033]0;"+BRANDING_LONGNAME+"\007",1,stdout,false); break; }

		// PATHS
		CONFIG_DIR = Environment.get_user_config_dir() + "/" + BRANDING_SHORTNAME;
		DATA_DIR = Environment.get_user_data_dir() + "/" + BRANDING_SHORTNAME;
		CACHE_DIR = Environment.get_user_cache_dir() + "/" + BRANDING_SHORTNAME;
	}

	public bool set_verbose(string? s) {
		string a = (s==null) ? "" : s.strip();
		switch (a) {
			case "n":
			case "no":
			case "off":
			case "false": a = "0"; break;
			case "y":
			case "yes":
			case "on":
			case "true": a = "1"; break;
		}
		int v = VERBOSE;
		bool r = true;
		if (a=="" || a.has_prefix("-")) { r = false; v++; }
		else v = int.parse(a);
		VERBOSE = v;
		Environment.set_variable("VERBOSE",v.to_string(),true);
		return r;
	}

	public void save_app_config() {
		vprint("save_app_config()",3);

		var config = new Json.Object();
		config.set_string_member(  "ppa_uri",                 ppa_uri                 );
		config.set_string_member(  "all_proxy",               all_proxy               );
		config.set_int_member(     "connect_timeout_seconds", connect_timeout_seconds );
		config.set_int_member(     "concurrent_downloads",    concurrent_downloads    );
		config.set_boolean_member( "hide_invalid",            hide_invalid            );
		config.set_boolean_member( "hide_unstable",           hide_unstable           );
		config.set_boolean_member( "hide_flavors",            hide_flavors            );
		config.set_int_member(     "previous_majors",         previous_majors         );
		config.set_boolean_member( "notify_major",            notify_major            );
		config.set_boolean_member( "notify_minor",            notify_minor            );
		config.set_int_member(     "notify_interval_unit",    notify_interval_unit    );
		config.set_int_member(     "notify_interval_value",   notify_interval_value   );
		config.set_boolean_member( "verify_checksums",        verify_checksums        );
		config.set_boolean_member( "keep_debs",               keep_debs               );
		config.set_boolean_member( "keep_cache",              keep_cache              );
		config.set_string_member(  "auth_cmd",                auth_cmd                );
		config.set_string_member(  "term_cmd",                term_cmd                );
		config.set_int_member(     "window_width",            window_width            );
		config.set_int_member(     "window_height",           window_height           );
		config.set_int_member(     "window_x",                window_x                );
		config.set_int_member(     "window_y",                window_y                );
		config.set_int_member(     "term_width",              term_width              );
		config.set_int_member(     "term_height",             term_height             );
		config.set_int_member(     "term_x",                  term_x                  );
		config.set_int_member(     "term_y",                  term_y                  );
		config.set_double_member(  "term_font_scale",         term_font_scale         );

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		mkdir(CONFIG_DIR);
		try { json.to_file(APP_CONFIG_FILE); }
		catch (Error e) { vprint(e.message,1,stderr); }

		vprint(_("Wrote config file")+": "+APP_CONFIG_FILE,3);

		update_notification_files();
	}

	public void update_notification_files() {
		update_startup_script();
		update_startup_desktop_file();
	}

	public void load_app_config() {
		vprint("load_app_config()",3);

		var parser = new Json.Parser();

		bool cf = true;
		try { parser.load_from_file(APP_CONFIG_FILE); }
		catch (Error e) { cf = false; vprint(e.message,2); }
		if (!cf) {
			vprint(_("No config file"),3);
			save_app_config();
			try { parser.load_from_file(APP_CONFIG_FILE); }
			catch (Error e) { vprint(e.message,1,stderr); exit(1); }
		}

		if (VERBOSE>2) vprint(fread(APP_CONFIG_FILE));

		var node = parser.get_root();
		var config = node.get_object();

#if GLIB_JSON_1_6
		ppa_uri                 =       config.get_string_member_with_default(  "ppa_uri",                 DEFAULT_PPA_URI                 );
		all_proxy               =       config.get_string_member_with_default(  "all_proxy",               DEFAULT_ALL_PROXY               );
		connect_timeout_seconds = (int) config.get_int_member_with_default(     "connect_timeout_seconds", DEFAULT_CONNECT_TIMEOUT_SECONDS );
		concurrent_downloads    = (int) config.get_int_member_with_default(     "concurrent_downloads",    DEFAULT_CONCURRENT_DOWNLOADS    );
		hide_invalid            =       config.get_boolean_member_with_default( "hide_invalid",            DEFAULT_HIDE_INVALID            );
		hide_unstable           =       config.get_boolean_member_with_default( "hide_unstable",           DEFAULT_HIDE_UNSTABLE           );
		hide_flavors            =       config.get_boolean_member_with_default( "hide_flavors",            DEFAULT_HIDE_FLAVORS            );
		previous_majors         = (int) config.get_int_member_with_default(     "previous_majors",         DEFAULT_PREVIOUS_MAJORS         );
		notify_major            =       config.get_boolean_member_with_default( "notify_major",            DEFAULT_NOTIFY_MAJOR            );
		notify_minor            =       config.get_boolean_member_with_default( "notify_minor",            DEFAULT_NOTIFY_MINOR            );
		notify_interval_unit    = (int) config.get_int_member_with_default(     "notify_interval_unit",    DEFAULT_NOTIFY_INTERVAL_UNIT    );
		notify_interval_value   = (int) config.get_int_member_with_default(     "notify_interval_value",   DEFAULT_NOTIFY_INTERVAL_VALUE   );
		verify_checksums        =       config.get_boolean_member_with_default( "verify_checksums",        DEFAULT_VERIFY_CHECKSUMS        );
		keep_debs               =       config.get_boolean_member_with_default( "keep_debs",               DEFAULT_KEEP_DEBS               );
		keep_cache              =       config.get_boolean_member_with_default( "keep_cache",              DEFAULT_KEEP_CACHE              );
		auth_cmd                =       config.get_string_member_with_default(  "auth_cmd",                DEFAULT_AUTH_CMDS[0]            );
		term_cmd                =       config.get_string_member_with_default(  "term_cmd",                DEFAULT_TERM_CMDS[0]            );
		window_width            = (int) config.get_int_member_with_default(     "window_width",            DEFAULT_WINDOW_WIDTH            );
		window_height           = (int) config.get_int_member_with_default(     "window_height",           DEFAULT_WINDOW_HEIGHT           );
		window_x                = (int) config.get_int_member_with_default(     "window_x",                DEFAULT_WINDOW_X                );
		window_y                = (int) config.get_int_member_with_default(     "window_y",                DEFAULT_WINDOW_Y                );
		term_width              = (int) config.get_int_member_with_default(     "term_width",              DEFAULT_TERM_WIDTH              );
		term_height             = (int) config.get_int_member_with_default(     "term_height",             DEFAULT_TERM_HEIGHT             );
		term_x                  = (int) config.get_int_member_with_default(     "term_x",                  DEFAULT_TERM_X                  );
		term_y                  = (int) config.get_int_member_with_default(     "term_y",                  DEFAULT_TERM_Y                  );
		term_font_scale         =       config.get_double_member_with_default(  "term_font_scale",         DEFAULT_TERM_FONT_SCALE         );
#else
		ppa_uri                 = json_get_string( config, "ppa_uri",                 DEFAULT_PPA_URI                 );
		all_proxy               = json_get_string( config, "all_proxy",               DEFAULT_ALL_PROXY               );
		connect_timeout_seconds = json_get_int(    config, "connect_timeout_seconds", DEFAULT_CONNECT_TIMEOUT_SECONDS );
		concurrent_downloads    = json_get_int(    config, "concurrent_downloads",    DEFAULT_CONCURRENT_DOWNLOADS    );
		hide_invalid            = json_get_bool(   config, "hide_invalid",            DEFAULT_HIDE_INVALID            );
		hide_unstable           = json_get_bool(   config, "hide_unstable",           DEFAULT_HIDE_UNSTABLE           );
		hide_flavors            = json_get_bool(   config, "hide_flavors",            DEFAULT_HIDE_FLAVORS            );
		previous_majors         = json_get_int(    config, "previous_majors",         DEFAULT_PREVIOUS_MAJORS         );
		notify_major            = json_get_bool(   config, "notify_major",            DEFAULT_NOTIFY_MAJOR            );
		notify_minor            = json_get_bool(   config, "notify_minor",            DEFAULT_NOTIFY_MINOR            );
		notify_interval_unit    = json_get_int(    config, "notify_interval_unit",    DEFAULT_NOTIFY_INTERVAL_UNIT    );
		notify_interval_value   = json_get_int(    config, "notify_interval_value",   DEFAULT_NOTIFY_INTERVAL_VALUE   );
		verify_checksums        = json_get_bool(   config, "verify_checksums",        DEFAULT_VERIFY_CHECKSUMS        );
		keep_debs               = json_get_bool(   config, "keep_debs",               DEFAULT_KEEP_DEBS               );
		keep_cache              = json_get_bool(   config, "keep_cache",              DEFAULT_KEEP_CACHE              );
		auth_cmd                = json_get_string( config, "auth_cmd",                DEFAULT_AUTH_CMDS[0]            );
		term_cmd                = json_get_string( config, "term_cmd",                DEFAULT_TERM_CMDS[0]            );
		window_width            = json_get_int(    config, "window_width",            DEFAULT_WINDOW_WIDTH            );
		window_height           = json_get_int(    config, "window_height",           DEFAULT_WINDOW_HEIGHT           );
		window_x                = json_get_int(    config, "window_x",                DEFAULT_WINDOW_X                );
		window_y                = json_get_int(    config, "window_y",                DEFAULT_WINDOW_Y                );
		term_width              = json_get_int(    config, "term_width",              DEFAULT_TERM_WIDTH              );
		term_height             = json_get_int(    config, "term_height",             DEFAULT_TERM_HEIGHT             );
		term_x                  = json_get_int(    config, "term_x",                  DEFAULT_TERM_X                  );
		term_y                  = json_get_int(    config, "term_y",                  DEFAULT_TERM_Y                  );
		term_font_scale         = json_get_double( config, "term_font_scale",         DEFAULT_TERM_FONT_SCALE         );
#endif

		// update old or otherwise invalid config file
		bool resave = false;
		if ( ppa_uri.length==0 || ppa_uri.contains(MATCH_PPA_URI_OLD_1) ) { ppa_uri = DEFAULT_PPA_URI; resave = true; }
		if (!ppa_uri.has_suffix("/")) { ppa_uri += "/"; resave = true; }
		if (connect_timeout_seconds>600) connect_timeout_seconds = 600; // aria2c max allowed
		if (resave) save_app_config();

		// apply commandline overrides
		if (opt_hide_invalid != null) hide_invalid = opt_hide_invalid;
		if (opt_hide_unstable != null) hide_unstable = opt_hide_unstable;
		if (opt_hide_flavors != null) hide_flavors = opt_hide_flavors;
		if (opt_previous_majors != null && opt_previous_majors != previous_majors) {
			previous_majors = opt_previous_majors;
			keep_cache = true;
		}

		vprint(_("Loaded config file")+": "+APP_CONFIG_FILE,3);

	}

	private void update_startup_script() {
		vprint("update_startup_script()",3);

		// construct the commandline argument for "sleep"
		int n = notify_interval_value; string u = "";
		switch (notify_interval_unit) {
			case 0: u = "h"; break;
			case 1: u = "d"; break;
			case 2: n = n*7; u = "d"; break;
			case 3: break;
		}

		// TODO, ID file should not assume single DISPLAY
		//       ID and SEEN should probably be in /var/run ?
		//       Sleep for days or weeks makes no sense,
		//       should really compare target with current date/time
		//       or run from cron or at or systemd
		string s = "#!/bin/bash\n"
			+ "# "+_("Called from")+" "+STARTUP_DESKTOP_FILE+" "+_("at logon")+".\n"
			+ "# "+_("This file is over-written and executed again whenever settings are saved in")+" "+BRANDING_SHORTNAME+"-gtk\n"
			+ "\n"
			+ "# on reboot or login, forget previous showings and show again once\n"
			+ "[[ $1 == --autostart ]] && rm -f \""+NOTIFICATION_ID_FILE+"\" \""+MAJOR_SEEN_FILE+"\" \""+MINOR_SEEN_FILE+"\"\n"
			+ "TMP=${XDG_RUNTIME_DIR:-/tmp}\n"
			+ "N=${0//\\//_}\n"
			+ "F=\"${TMP}/${N}.${$}.p\" # our pid file\n"
			+ "G=\"${TMP}/${N}.+([0-9]).p\" # globbing pattern for other pid files (requires extglob)\n"
			+ "unset p s; typeset -i p s\n"
			+ "\n"
			+ "# on exit, kill our child sleep process and delete our pid file\n"
			+ "trap '((s)) && kill $s ;rm -f $F' 0\n"
			+ "\n"
			+ "# clear previous state (kill previous instance)\n"
			+ "echo -n \"${DISPLAY} ${$}\" > $F\n"
			+ "shopt -s extglob\n"
			+ "for f in $G ;do\n"
			+ "\t[[ -s $f ]] || continue  # no file found\n"
			+ "\t[[ $f -ot $F ]] || continue  # file is not older than our current one\n"
			+ "\tread d p x < $f  # read DISPLAY & PID\n"
			+ "\t[[ $d == ${DISPLAY} ]] || continue  # not our DISPLAY, not our desktop session\n"
			+ "\t((p>1)) || continue  # PID not sane\n"
			+ "\t# if we got this far, then we found a previous, now-obsolete instance of ourself\n"
			+ "\t# that needs to be killed and replaced with ourself\n"
			+ "\trm -f $f  # delete the other pid file\n"
			+ "\tkill $p  # kill the other process\n"
			+ "done\n"
			+ "unset N f p d x\n"
			+ "\n"
			+ "# run whatever the new state should be\n"
			+ "# (code below changes depending on notification settings in the app)\n";
		if (notify_minor || notify_major) {
			s += "VERBOSE=0\n"
			+ "while [[ -f $F ]] ;do\n"
			+ "\t"+CLI_EXE+" notify >&- 2>&-\n"
			+ "\tsleep %d%s &\n".printf(n,u)
			+ "\ts=$!\n"
			+ "\twait $s  # respond to signals during sleep\n"
			+ "done\n";
		} else {
			s += "# " + _("Notifications are disabled") + "\n"
			+ "exit 0\n";
		}

		fwrite(STARTUP_SCRIPT_FILE,s);
		RUN_NOTIFY_SCRIPT = true;
	}

	private void update_startup_desktop_file() {
		vprint("update_startup_desktop_file()",3);

		if (notify_minor || notify_major) {
			string s = "[Desktop Entry]\n"
				+ "Exec=bash \""+STARTUP_SCRIPT_FILE+"\" --autostart\n"
				;
			fwrite(STARTUP_DESKTOP_FILE,s);
		} else {
			rm(STARTUP_DESKTOP_FILE);
		}
	}

	public void run_notify_script_if_due() {
		if (!RUN_NOTIFY_SCRIPT) return;
		RUN_NOTIFY_SCRIPT = false;
		exec_async("bash "+STARTUP_SCRIPT_FILE);
	}

	public bool try_ppa() {
		vprint("try_ppa()",4);
		if (ppa_tried) return ppa_up;

		string std_err, std_out;

		string cmd = "aria2c"
		+ " --no-netrc"
		+ " --no-conf"
		+ " --max-file-not-found=3"
		+ " --retry-wait=2"
		+ " --max-tries=3"
		+ " --dry-run"
		+ " --quiet";
		if (connect_timeout_seconds>0) cmd += " --connect-timeout="+connect_timeout_seconds.to_string();
		if (all_proxy.length>0) cmd += " --all-proxy='"+all_proxy+"'";
		cmd += " '"+ppa_uri+"'";

		vprint(cmd,3);

		int status = exec_sync(cmd, out std_out, out std_err);
		if (std_err.length > 0) vprint(std_err,1,stderr);

		ppa_tried = true;
		ppa_up = false;
		if (status == 0) ppa_up = true;
		else vprint(_("Can not reach site")+": \""+ppa_uri+"\"",1,stderr);

		ppa_up = true;
		return ppa_up;
	}

}
