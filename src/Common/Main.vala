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

using GLib;
using Gee;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

//  [CCode(cname="BRANDING_SHORTNAME")] extern const string BRANDING_SHORTNAME;
//  [CCode(cname="BRANDING_LONGNAME")] extern const string BRANDING_LONGNAME;
//  [CCode(cname="BRANDING_VERSION")] extern const string BRANDING_VERSION;
//  [CCode(cname="BRANDING_AUTHORNAME")] extern const string BRANDING_AUTHORNAME;
//  [CCode(cname="BRANDING_AUTHOREMAIL")] extern const string BRANDING_AUTHOREMAIL;
//  [CCode(cname="BRANDING_WEBSITE")] extern const string BRANDING_WEBSITE;
//  [CCode(cname="INSTALL_PREFIX")] extern const string INSTALL_PREFIX;
//  [CCode(cname="DEFAULT_SHOW_PREV_MAJORS")] extern const string DEFAULT_SHOW_PREV_MAJORS;

public const string LOCALE_DIR = Constants.INSTALL_PREFIX + "/share/locale";
public const string APP_LIB_DIR = Constants.INSTALL_PREFIX + "/lib/" + Constants.BRANDING_SHORTNAME;

extern void exit(int exit_code);

public class Main : GLib.Object{

	// constants ----------

	public string TMP_PREFIX = "";
	public string APP_CONF_DIR = "";
	public string APP_CONFIG_FILE = "";
	public string STARTUP_SCRIPT_FILE = "";
	public string STARTUP_DESKTOP_FILE = "";
	public string NOTIFICATION_ID_FILE = "";
	public string NOTIFICATION_SEEN_FILE = "";

	public string user_login = "";
	public string user_home = "";

	// global progress ----------------
	
	public string status_line = "";
	public int64 progress_total = 0;
	public int64 progress_count = 0;
	public bool cancelled = false;

	// state flags ----------
	
	public bool GUI_MODE = false;
	public string command = "list";
	public string requested_version = "";
	
	public bool notify_major = true;
	public bool notify_minor = true;
	public int notify_interval_unit = 0;
	public int notify_interval_value = 2;
	public int connect_timeout_seconds = 15;
	public int concurrent_downloads = 4;
	public bool skip_connection_check = false;
	public bool confirm = true;

	// constructors ------------
	
	public Main(string[] arg0, bool _gui_mode){
		//log_msg("Main()");

		GUI_MODE = _gui_mode;

		Package.initialize();

		LinuxKernel.initialize();

		init_paths();

		load_app_config();
	}

	// helpers ------------

	public void init_paths(string custom_user_login = ""){

		// user info
		user_login = GLib.Environment.get_user_name();

		if (custom_user_login.length > 0){
			user_login = custom_user_login;
		}

		user_home = GLib.Environment.get_home_dir();

		APP_CONF_DIR = user_home + "/.config/" + Constants.BRANDING_SHORTNAME;
		APP_CONFIG_FILE = APP_CONF_DIR + "/config.json";
		STARTUP_SCRIPT_FILE = APP_CONF_DIR + "/notify-loop.sh";
		STARTUP_DESKTOP_FILE = user_home + "/.config/autostart/" + Constants.BRANDING_SHORTNAME + ".desktop";
		NOTIFICATION_ID_FILE = APP_CONF_DIR + "/notification_id";
		NOTIFICATION_SEEN_FILE = APP_CONF_DIR + "/notification_seen";

		LinuxKernel.CACHE_DIR = user_home + "/.cache/" + Constants.BRANDING_SHORTNAME;
		LinuxKernel.CURRENT_USER = user_login;
		LinuxKernel.CURRENT_USER_HOME = user_home;

		// todo: consider get_user_runtime_dir() or get_user_cache_dir()
		TMP_PREFIX = Environment.get_tmp_dir() + "/." + Constants.BRANDING_SHORTNAME;

	}
	
	public void save_app_config(){
		
		var config = new Json.Object();
		config.set_string_member("notify_major", notify_major.to_string());
		config.set_string_member("notify_minor", notify_minor.to_string());
		config.set_string_member("hide_unstable", LinuxKernel.hide_unstable.to_string());
		config.set_string_member("show_prev_majors", LinuxKernel.show_prev_majors.to_string());
		config.set_string_member("notify_interval_unit", notify_interval_unit.to_string());
		config.set_string_member("notify_interval_value", notify_interval_value.to_string());
        config.set_string_member("connect_timeout_seconds", connect_timeout_seconds.to_string());
        config.set_string_member("concurrent_downloads", concurrent_downloads.to_string());
        config.set_string_member("skip_connection_check", skip_connection_check.to_string());

		var json = new Json.Generator();
		json.pretty = true;
		json.indent = 2;
		var node = new Json.Node(NodeType.OBJECT);
		node.set_object(config);
		json.set_root(node);

		try{
			json.to_file(APP_CONFIG_FILE);
		} catch (Error e) {
	        log_error (e.message);
	    }

	    log_debug("Saved config file: %s".printf(APP_CONFIG_FILE));

		update_notification_files();
	}

	public void update_notification_files(){
		update_startup_script();
	    update_startup_desktop_file();
	}

	public void load_app_config(){
	
		var f = File.new_for_path(APP_CONFIG_FILE);
		
		if (!f.query_exists()) {
			// initialize static
			LinuxKernel.hide_unstable = true;
			LinuxKernel.show_prev_majors = int.parse(Constants.DEFAULT_SHOW_PREV_MAJORS);
			return;
		}

		var parser = new Json.Parser();
		
        try{
			parser.load_from_file(APP_CONFIG_FILE);
		} catch (Error e) {
	        log_error (e.message);
	    }
	    
        var node = parser.get_root();
        var config = node.get_object();

		notify_major = json_get_bool(config, "notify_major", true);
		notify_minor = json_get_bool(config, "notify_minor", true);
		notify_interval_unit = json_get_int(config, "notify_interval_unit", 0);
		notify_interval_value = json_get_int(config, "notify_interval_value", 2);
		connect_timeout_seconds = json_get_int(config, "connect_timeout_seconds", 15);
		concurrent_downloads = json_get_int(config, "concurrent_downloads", 4);
		skip_connection_check = json_get_bool(config, "skip_connection_check", false);

		LinuxKernel.hide_unstable = json_get_bool(config, "hide_unstable", true);
		LinuxKernel.show_prev_majors = json_get_int(config, "show_prev_majors", int.parse(Constants.DEFAULT_SHOW_PREV_MAJORS));

		log_debug("Load config file: %s".printf(APP_CONFIG_FILE));
	}

	public void exit_app(int exit_code){
		// save_app_config();
		exit(exit_code);
	}

	// begin ------------

	private void update_startup_script(){

		// construct the commandline argument for "sleep"
		int count = App.notify_interval_value;
		string suffix = "h";
		switch (App.notify_interval_unit){
		case 0: // hour
			suffix = "h";
			break;
		case 1: // day
			suffix = "d";
			break;
		case 2: // week
			suffix = "d";
			count = App.notify_interval_value * 7;
			break;
		case 3: // second
			suffix = "";
			count = App.notify_interval_value;
			break;
		}

		file_delete(STARTUP_SCRIPT_FILE);

		// TODO, ID file should not assume single DISPLAY
		//       ID and SEEN should probably be in /var/run ?
		string s = "#!/bin/bash\n"
			+ "# " +_("Called from")+" "+STARTUP_DESKTOP_FILE+" at logon.\n"
			+ "# This file is over-written and executed again whenever settings are saved in "+Constants.BRANDING_SHORTNAME+"-gtk\n"
			+ "[[ \"${1}\" = \"--autostart\" ]] && rm -f "+NOTIFICATION_ID_FILE+" "+NOTIFICATION_SEEN_FILE+"\n"
			+ "TMP=${XDG_RUNTIME_DIR:-/tmp}\n"
			+ "F=\"${TMP}/"+Constants.BRANDING_SHORTNAME+"-notify-loop.${$}.p\"\n"
			+ "trap \"rm -f \\\"${F}\\\"\" 0\n"
			+ "echo -n \"${DISPLAY} ${$}\" > \"${F}\"\n"
			+ "typeset -i p\n"
			+ "shopt -s extglob\n"
			+ "\n"
			+ "# clear previous state (kill previous instance)\n"
			+ "for f in ${TMP}/"+Constants.BRANDING_SHORTNAME+"-notify-loop.+([0-9]).p ;do\n"
			+ "\t[[ -s ${f} ]] || continue\n"
			+ "\t[[ ${f} -ot ${F} ]] || continue\n"
			+ "\tread d p x < \"${f}\"\n"
			+ "\t[[ \"${d}\" == \"${DISPLAY}\" ]] || continue\n"
			+ "\t((${p}>1)) || continue\n"
			+ "\trm -f \"${f}\"\n"
			+ "\tkill ${p}\n"
			+ "done\n"
			+ "unset F f p d x\n"
			+ "\n"
			+ "# run current state\n";
		if (notify_minor || notify_major){
			// This gdbus check doesn't do what I'd hoped.
			// Still succeeds while logged out but sitting at a display manager login screen.
			s += "while gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.GetId 2>&- >&- ;do\n"
			+ "\t"+Constants.BRANDING_SHORTNAME+" --notify";
			if (LOG_DEBUG) s += " --debug";
			s += "\n"
			+ "\tsleep %d%s &\n".printf(count,suffix)
			+ "\twait ${!}\n"	// respond to signals during sleep
			+ "done\n";
		} else {
			s += "# " + _("Notifications are disabled") + "\n"
			+ "exit 0\n";
		}

		file_write(STARTUP_SCRIPT_FILE,s);
		exec_async("bash "+STARTUP_SCRIPT_FILE);
	}

	private void update_startup_desktop_file(){
		if (notify_minor || notify_major){
			
			string txt = "[Desktop Entry]\n"
				+ "Type=Application\n"
				+ "Exec=bash \""+STARTUP_SCRIPT_FILE+"\" --autostart\n"
				+ "Hidden=false\n"
				+ "NoDisplay=false\n"
				+ "X-GNOME-Autostart-enabled=true\n"
				+ "Name="+Constants.BRANDING_SHORTNAME+" notification\n"
				+ "Comment="+Constants.BRANDING_SHORTNAME+" notification\n";

			file_write(STARTUP_DESKTOP_FILE, txt);

		}
		else{
			file_delete(STARTUP_DESKTOP_FILE);
		}
	}
}
