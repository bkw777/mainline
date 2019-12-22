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

extern void exit(int exit_code);

public class Main : GLib.Object{

	// constants ----------
	
	public string APP_CONFIG_FILE = "";
	public string STARTUP_SCRIPT_FILE = "";
	public string STARTUP_DESKTOP_FILE = "";

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
	public bool notify_bubble = true;
	public bool notify_dialog = true;
	public int notify_interval_unit = 0;
	public int notify_interval_value = 2;
	public bool skip_connection_check = false;
	public int connection_timeout_seconds = 15;
	public bool confirm = true;

	// constructors ------------
	
	public Main(string[] arg0, bool _gui_mode){

		GUI_MODE = _gui_mode;
		
		LOG_TIMESTAMP = false;

		Package.initialize();
		
		LinuxKernel.initialize();

		init_paths();

		load_app_config();
	}

	// helpers ------------
	
	public static bool check_dependencies(out string msg) {
		
		string[] dependencies = { "aptitude", "aria2c", "dpkg", "uname", "lsb_release" };

		msg = "";
		
		string path;
		foreach(string cmd_tool in dependencies) {
			path = get_cmd_path (cmd_tool);
			if ((path == null) || (path.length == 0)) {
				msg += " * " + cmd_tool + "\n";
			}
		}

		if (msg.length > 0) {
			msg = _("Commands listed below are not available on this system") + ":\n\n" + msg + "\n";
			msg += _("Please install required packages and try again");
			log_msg(msg);
			return false;
		}
		else{
			return true;
		}
	}

	public void init_paths(string custom_user_login = ""){

		// user info
		user_login = get_username();

		if (custom_user_login.length > 0){
			user_login = custom_user_login;
		}
		
		user_home = get_user_home(user_login);

		// app config files
		APP_CONFIG_FILE = user_home + "/.config/" + BRANDING_SHORTNAME + "/config.json";
		STARTUP_SCRIPT_FILE = user_home + "/.config/" + BRANDING_SHORTNAME + "/" + BRANDING_SHORTNAME + "-notify.sh";
		STARTUP_DESKTOP_FILE = user_home + "/.config/autostart/" + BRANDING_SHORTNAME + ".desktop";

		LinuxKernel.CACHE_DIR = user_home + "/.cache/" + BRANDING_SHORTNAME;
		LinuxKernel.CURRENT_USER = user_login;
		LinuxKernel.CURRENT_USER_HOME = user_home;
	}
	
	public void save_app_config(){
		
		var config = new Json.Object();
		config.set_string_member("notify_major", notify_major.to_string());
		config.set_string_member("notify_minor", notify_minor.to_string());
		config.set_string_member("notify_bubble", notify_bubble.to_string());
		config.set_string_member("notify_dialog", notify_dialog.to_string());
		config.set_string_member("hide_unstable", LinuxKernel.hide_unstable.to_string());
		config.set_string_member("hide_older", LinuxKernel.hide_older.to_string());
		config.set_string_member("hide_older5", LinuxKernel.hide_older5.to_string());
		config.set_string_member("notify_interval_unit", notify_interval_unit.to_string());
		config.set_string_member("notify_interval_value", notify_interval_value.to_string());
        config.set_string_member("connection_timeout_seconds", connection_timeout_seconds.to_string());
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

		// change owner to current user so that ukuu can access in normal mode
	    chown(APP_CONFIG_FILE, user_login, user_login);

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
			LinuxKernel.hide_older = true;
			LinuxKernel.hide_older5 = true;
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
		notify_bubble = json_get_bool(config, "notify_bubble", true);
		notify_dialog = json_get_bool(config, "notify_dialog", true);
		notify_interval_unit = json_get_int(config, "notify_interval_unit", 0);
		notify_interval_value = json_get_int(config, "notify_interval_value", 2);
		connection_timeout_seconds = json_get_int(config, "connection_timeout_seconds", 15);
		skip_connection_check = json_get_bool(config, "skip_connection_check", false);

		LinuxKernel.hide_unstable = json_get_bool(config, "hide_unstable", true);
		LinuxKernel.hide_older = json_get_bool(config, "hide_older", true);
		LinuxKernel.hide_older5 = json_get_bool(config, "hide_older5", true);

		log_debug("Load config file: %s".printf(APP_CONFIG_FILE));
	}

	public void exit_app(int exit_code){
		save_app_config();
		exit(exit_code);
	}

	// begin ------------


	private void update_startup_script(){

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
		}
		
		if (file_exists(STARTUP_SCRIPT_FILE)){
			file_delete(STARTUP_SCRIPT_FILE);
		}

		// UGLY - this should be a cron job
		string txt = "# Notifications are disabled\nexit 0\n";
		if (notify_minor || notify_major){
			txt = "while sleep %d%s".printf(count, suffix)+" ;do "+BRANDING_SHORTNAME+" --notify ;done\n";
		}

		file_write(STARTUP_SCRIPT_FILE,txt);

		chown(STARTUP_SCRIPT_FILE, user_login, user_login);
	}

	private void update_startup_desktop_file(){
		if (notify_minor || notify_major){
			
			string txt = "[Desktop Entry]\n"
				+ "Type=Application\n"
				+ "Exec=sh \"" + STARTUP_SCRIPT_FILE + "\"\n"
				+ "Hidden=false\n"
				+ "NoDisplay=false\n"
				+ "X-GNOME-Autostart-enabled=true\n"
				+ "Name="+BRANDING_SHORTNAME+" notification\n"
				+ "Comment="+BRANDING_SHORTNAME+" notification\n";

			file_write(STARTUP_DESKTOP_FILE, txt);

			chown(STARTUP_DESKTOP_FILE, user_login, user_login);
		}
		else{
			file_delete(STARTUP_DESKTOP_FILE);
		}
	}
}

