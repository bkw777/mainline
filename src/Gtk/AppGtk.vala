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

using l_misc;

public Main App;

public class AppGtk : GLib.Object {

	public static int main(string[] argv) {
		App = new Main();
		App.gui_mode = true;
		parse_arguments(argv);
		vprint(string.joinv(" ",argv),3);
		App.init2();

		X.init_threads();
		Gtk.init(ref argv);
		new MainWindow();

		Gtk.main();

		// window size basically always changes slightly even if you don't touch anything,
		// so don't bother detecting changes, just always re-write the config file on exit
		var x = App.RUN_NOTIFY_SCRIPT;  // save whether run_notify was already pending
		App.save_app_config();          // this sets run_notify blindly but we don't need that just for window size change
		App.RUN_NOTIFY_SCRIPT = x;      // restore the original pending/not-pending state
		App.run_notify_script_if_due(); // in case it was pending and somehow missed along the way

		return 0;
	}

	public static bool parse_arguments(string[] args) {

		string help = ""
		+ "\n" + BRANDING_SHORTNAME + " " + BRANDING_VERSION + " - " + BRANDING_LONGNAME + "\n"
		+ "\n"
		+ _("Syntax") + ": " + args[0] + " ["+_("command")+"] ["+_("options")+"]\n"
		+ "\n"
		+ _("Commands") + "\n"
		+ "  help                " + _("This help") + "\n"
		+ "\n"
		+ _("Options") + "\n"
		+ "  -v|--verbose [#]    " + _("Set verbosity level to #, or increment by 1") + "\n"
		+ "\n"
		;

		// parse options
		for (int i = 1; i < args.length; i++)
		{
			switch (args[i].down()) {

			// this is the notification action
			case "--install":
			case "install":
				App.command = "install";
				if (++i < args.length) App.requested_versions = args[i].down();
				break;

			case "-v":
			case "--debug":
			case "--verbose":
				if (App.set_verbose(args[i+1])) i++;
				break;

			case "-?":
			case "-h":
			case "--help":
			case "help":
			case "--version":
				vprint(help,0);
				exit(0);
				break;

			default:
				vprint(_("Unknown option") + ": \""+args[i]+"\"",1,stderr);
				vprint(help,0);
				exit(1);
				break;

			}
		}

		return true;
	}

	public static void alert(Gtk.Window win, string msg, Gtk.MessageType type = Gtk.MessageType.INFO) {
		var dlg = new Gtk.MessageDialog(win,
			Gtk.DialogFlags.MODAL,
			type,
			Gtk.ButtonsType.OK,
			msg);
		dlg.response.connect(() => { dlg.destroy(); });
		dlg.show();
	}

}
