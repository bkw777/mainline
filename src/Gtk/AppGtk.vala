/*
 * AppGtk.vala
 *
 * Copyright 2016 Tony George <teejee2008@gmail.com>
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
 */

using GLib;
using Gtk;
using Gee;
using Json;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public Main App;

public class AppGtk : GLib.Object {

	public static int main (string[] args) {
		
		set_locale();

		log_msg("%s %s".printf(Constants.BRANDING_SHORTNAME, Constants.BRANDING_VERSION));

		Gtk.init(ref args);

		App = new Main(args, true);
		parse_arguments(args);

		// create main window --------------------------------------

		var window = new MainWindow ();
		
		window.destroy.connect(()=>{
			log_debug("MainWindow destroyed");
			Gtk.main_quit();
		});
		
		window.delete_event.connect((event)=>{
			log_debug("MainWindow closed");
			Gtk.main_quit();
			return true;
		});

		if (App.command == "list"){
			window.show_all();
		}

		//start event loop -------------------------------------
		
		Gtk.main();

		//App.save_app_config();

		return 0;
	}

	private static void set_locale() {
		Intl.setlocale(GLib.LocaleCategory.MESSAGES, Constants.BRANDING_SHORTNAME);
		Intl.textdomain(Constants.BRANDING_SHORTNAME);
		Intl.bind_textdomain_codeset(Constants.BRANDING_SHORTNAME, "utf-8");
		Intl.bindtextdomain(Constants.BRANDING_SHORTNAME, LOCALE_DIR);
	}

	public static bool parse_arguments(string[] args) {

		App.command = "list";
		
		//parse options
		for (int k = 1; k < args.length; k++)
		{
			switch (args[k].down()) {
				
			case "--debug":
				LOG_DEBUG = true;
				break;

			case "--help":
			case "--h":
			case "-h":
				log_msg(help_message());
				exit(0);
				return true;
			}
		}

		for (int k = 1; k < args.length; k++)
		{
			switch (args[k].down()) {

			// commands ------------------------------------

			case "--install":
				App.command = "install";
				App.requested_version = args[++k];
				break;

			// options without argument --------------------------
			
			case "--help":
			case "--h":
			case "-h":
			case "--debug":
				// already handled - do nothing
				break;

			// options with argument --------------------------

			case "--user":
				k += 1;
				// already handled - do nothing
				break;

			default:
				//unknown option - show help and exit
				log_error(_("Unknown option") + ": %s".printf(args[k]));
				log_msg(help_message());
				return false;
			}
		}

		return true;
	}

	public static string help_message() {
		
		string msg = "\n" + Constants.BRANDING_SHORTNAME + " " + Constants.BRANDING_VERSION + " - " + Constants.BRANDING_LONGNAME + "\n";
		msg += "\n";
		msg += _("Syntax") + ": " + Constants.BRANDING_SHORTNAME + "-gtk [options]\n";
		msg += "\n";
		msg += _("Options") + ":\n";
		msg += "\n";
		msg += "  --debug      " + _("Print debug information") + "\n";
		msg += "  --help       " + _("Show all options") + "\n";
		msg += "\n";
		return msg;
	}
}
