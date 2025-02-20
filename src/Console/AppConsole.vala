/*
 * AptikConsole.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
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
using l_exec;

public Main App;
public AppConsole CLI;

public class AppConsole : GLib.Object {

	string help = "\n"
		+ BRANDING_LONGNAME + " " + BRANDING_VERSION + " - " + _("install kernel packages from %s").printf(DEFAULT_PPA_URI) + "\n"
		+ "\n"
		+ _("Syntax") + ": %s <"+_("command")+"> ["+_("options")+"]\n"
		+ "\n"
		+ _("Commands") + "\n"
		+ "\n"
		+ "  check               " + _("Check for kernel updates") + "\n"
		+ "  notify              " + _("Check for kernel updates and send a desktop notification") + "\n"
		+ "  list                " + _("List the available kernels") + "\n"
		+ "  list-installed      " + _("List the installed kernels") + "\n"
		+ "  install-latest      " + _("Install the latest mainline kernel") + "\n"
		+ "  install-minor       " + _("Install the latest mainline kernel without going to a new major version") + "\n"
		+ "  install <"+_("names")+">     " + _("Install the specified kernels") + "(1)(2)\n"
		+ "  uninstall <"+_("names")+">   " + _("Uninstall the specified kernels") + "(1)(2)\n"
		+ "  uninstall-old       " + _("Uninstall all but the highest installed version") + "(2)\n"
		+ "  download <"+_("names")+">    " + _("Download the specified kernels") + "(1)\n"
		+ "  lock <"+_("names")+">        " + _("Lock the specified kernels") + "(1)\n"
		+ "  unlock <"+_("names")+">      " + _("Unlock the specified kernels") + "(1)\n"
		+ "  delete-cache        " + _("Delete the cached info about available kernels") + "\n"
		+ "  write-config        " + _("Write the given include/exclude & previous-majors options to the config file") + "\n"
		+ "  help                " + _("This help") + "\n"
		+ "\n"
		+ _("Options") + "\n"
		+ "\n"
		+ "  --include-rc        " + _("Include release-candidate and unstable releases") + "\n"
		+ "  --exclude-rc        " + _("Exclude release-candidate and unstable releases") + "\n"
		+ "  --include-flavors   " + _("Include flavors other than \"%s\"").printf("generic") + "\n"
		+ "  --exclude-flavors   " + _("Exclude flavors other than \"%s\"").printf("generic") + "\n"
		+ "  --include-invalid   " + _("Include failed/incomplete builds") + "\n"
		+ "  --exclude-invalid   " + _("Exclude failed/incomplete builds") + "\n"
		+ "  --previous-majors # " + _("Include # (or \"%s\" or \"%s\") previous major versions").printf("all","none") + "\n"
		+ "  --include-all       " + _("Short for \"%s\"").printf("--include-rc --include-flavors --include-invalid --previous-majors all") + "\n"
		+ "  --exclude-all       " + _("Short for \"%s\"").printf("--exclude-rc --exclude-flavors --exclude-invalid --previous-majors none") + "\n"
		//+ "  -y|--yes            " + _("Assume Yes for all prompts") + "\n"
		//+ "  -n|--no|--dry-run   " + _("Assume No for all prompts - takes precedence over \"%s\"").printf("--yes") + "\n"
		+ "  -n|--dry-run        " + _("Don't actually install or uninstall") + "\n"
		+ "  -v|--verbose [#]    " + _("Set verbosity level to #, or increment by 1") + "\n"
		+ "  --pause             " + _("Pause and require keypress before exiting") + "\n"
		+ "\n"
		+ _("Notes") + "\n"
		+ "(1) " +_("One or more version strings taken from the output of \"%s\"").printf("list") + "\n"
		+ "    " +_("comma, pipe, colon, or space separated. (space requires quotes or backslashes)") + "\n"
		+ "(2) " +_("Locked kernels and the currently running kernel are ignored") + "\n"
		;

	static bool hold_on_exit = false;
	static bool help_shown = false;

	public static int main (string[] argv) {
		App = new Main();
		CLI = new AppConsole();
		var r = CLI.parse_arguments(argv);
		vprint(BRANDING_SHORTNAME+": "+_("done"));
		if (hold_on_exit) ask(_("(press Enter to close)"),false,true);
		return r;
	}

	void show_help(string c=BRANDING_SHORTNAME) {
		if (help_shown) return;
		help_shown = true;
		vprint(help.printf(c),0);
	}

	// misnomer, it's not just parsing but dispatching and doing everything
	public int parse_arguments(string[] args) {

		string cmd = "help";
		string vlist = "";
		string a = "";

		// parse options first --------------
		for (int i = 1; i < args.length; i++) {
			a = args[i].down();
			switch (a) {

				// ==== commands ====

				// commands that take no argument
				case "":
				case "-?":
				case "-h":
				case "--help":
				case "help":
				case "--version":
					cmd = "help";
					break;

				case "--clean-cache":
				case "--delete-cache":
				case "delete-cache":
				case "write-config":
				case "--list":
				case "list":
				case "--list-installed":
				case "list-installed":
				case "--check":
				case "check":
				case "--notify":
				case "notify":
				case "--install-latest":
				case "install-latest":
				case "--install-point":
				case "--install-minor":
				case "install-minor":
				case "--purge-old-kernels":
				case "--uninstall-old":
				case "uninstall-old":
					cmd = a;
					break;

				// commands that take a list of names argument
				case "--lock":
				case "lock":
				case "--unlock":
				case "unlock":
				case "--download":
				case "download":
				case "--install":
				case "install":
				case "--remove":
				case "--uninstall":
				case "uninstall":
					cmd = a;
					if (++i < args.length) vlist = args[i];
					break;

				// ==== options ====

				case "-v":
				case "--debug":
				case "--verbose":
					if (App.set_verbose(args[i+1])) i++;
					break;

				//case "-y":
				//case "--yes":
				//	App.yes_mode = true;
				//	break;

				case "-n":
				case "--no":
				case "--dry-run":
					App.no_mode = true;
					break;

				case "--pause":
					hold_on_exit = true;
					break;

				case "--from-gui":
					App.index_is_fresh = true;
					string c = "";
					for (int j = 1; j < args.length; j++) if (args[j]!="--from-gui" && args[j]!="--pause") c += args[j]+" ";
					vprint(c);
					break;

				case "--show-unstable": // back compat
				case "--include-unstable":
				case "--include-rc":
					App.opt_hide_unstable = false;
					break;

				case "--hide-unstable": // back compat
				case "--exclude-unstable":
				case "--exclude-rc":
					App.opt_hide_unstable = true;
					break;

				case "--include-flavors":
					App.opt_hide_flavors = false;
					break;

				case "--exclude-flavors":
					App.opt_hide_flavors = true;
					break;

				case "--include-invalid":
					App.opt_hide_invalid = false;
					break;

				case "--exclude-invalid":
					App.opt_hide_invalid = true;
					break;

				case "--previous-majors":
					if (set_previous_majors(args[i+1])) i++;
					break;

				case "--include-all":
					App.opt_hide_unstable = false;
					App.opt_hide_flavors = false;
					App.opt_hide_invalid = false;
					App.opt_previous_majors = -1;
					break;

				case "--exclude-all":
					App.opt_hide_unstable = true;
					App.opt_hide_flavors = true;
					App.opt_hide_invalid = true;
					App.opt_previous_majors = 0;
					break;

				default:
					show_help(args[0]);
					vprint(_("Unknown option \"%s\"").printf(args[i]),1,stderr);
					return 1;
			}
		}

		// ================= perform the actions ==================

		// commands that don't need anything
		if (cmd=="help") {
			show_help(args[0]);
			return 0;
		}

		// transition notices
		if (cmd=="--remove") {
			vprint(_("Notice: \"%s\" has been renamed to \"%s\"").printf(cmd,"uninstall"));
			cmd = "uninstall";
		}
		if (cmd=="--clean-cache") {
			vprint(_("Notice: \"%s\" has been renamed to \"%s\"").printf(cmd,"delete-cache"));
			cmd = "delete-cache";
		}
		if (cmd=="--install-point") {
			vprint(_("Notice: \"%s\" has been renamed to \"%s\"").printf(cmd,"install-minor"));
			cmd = "install-minor";
		}
		if (cmd=="--purge-old-kernels") {
			vprint(_("Notice: \"%s\" has been renamed to \"%s\"").printf(cmd,"uninstall-old"));
			cmd = "uninstall-old";
		}
		if (cmd.has_prefix("--")) {
			cmd = cmd.substring(2);
			vprint(_("Notice: \"%s\" has been renamed to \"%s\"").printf("--"+cmd,cmd));
		}

		// apply some of the options effects
		if (App.no_mode) vprint(_("DRY-RUN"),2);
		vprint(string.joinv(" ",args),3);

		// commands that don't require full init but do want to be affected by options
		if (cmd=="delete-cache") {
			int r = 1;
			if (rm(Main.CACHE_DIR)) { r = 0; vprint(_("Deleted %s").printf(Main.CACHE_DIR)); }
			else vprint(_("Error deleting %s").printf(Main.CACHE_DIR),1,stderr);
			return r;
		}

		// finish init
		App.init2();

		// commands that don't need kernel_list
		if (cmd=="write-config") {
			App.save_app_config();
			vprint(_("Wrote %s").printf(App.APP_CONFIG_FILE));
			if (Main.VERBOSE>1) vprint(fread(App.APP_CONFIG_FILE));
			return 0;
		}
		if (cmd=="list-installed") {
			Package.mk_dpkg_list();
			vprint(_("Installed Kernels")+":");
			foreach (var p in Package.dpkg_list) if (p.name.has_prefix("linux-image-")) vprint(p.name);
			return 0;
		}
		if (cmd=="notify") {
			if (!App.notify_major && !App.notify_minor) {
				vprint(_("Notifications disabled"),2);
				return 1;
			}
			if (Environment.get_variable("DISPLAY")==null) {
				vprint(_("No")+" $DISPLAY",2);
				return 1;
			}
		}

		// populate kernel_list
		LinuxKernel.mk_kernel_list(true);

		// commands that require everything
		switch (cmd) {
			case "list":
				LinuxKernel.print_list();
				break;

			//case "list-installed":
				// -- output from check_installed()
				//Package.mk_dpkg_list();
				//LinuxKernel.check_installed(true);
				// -- full normal print_list(), just filtered
				//LinuxKernel.print_list(true);
				//break;

			case "check":
				print_updates();
				break;

			case "notify":
				return notify_user();

			case "install-latest":
				return LinuxKernel.kinst_latest(false);

			case "install-minor":
				return LinuxKernel.kinst_latest(true);

			case "uninstall-old":
				return LinuxKernel.kunin_old();

			case "lock":
				return LinuxKernel.lock_vlist(true,vlist);

			case "unlock":
				return LinuxKernel.lock_vlist(false,vlist);

			case "download":
				return LinuxKernel.download_vlist(vlist);

			case "uninstall":
				return LinuxKernel.uninstall_vlist(vlist);

			case "install":
				return LinuxKernel.install_vlist(vlist);

			// should be unreachable
			default:
				show_help(args[0]);
				vprint(_("Unknown command") + ": \""+cmd+"\"",1,stderr);
				return 1;
		}

		return 0;
	}

	bool set_previous_majors(string? s) {
		string a = (s==null) ? "" : s.strip();
		if (a.length<1 || a.has_prefix("-")) return false;
		if (a=="none") a = "0";
		if (a=="all") a = "-1";
		App.opt_previous_majors = int.parse(a);
		return true;
	}

	void print_updates() {
		var km = LinuxKernel.kernel_update_major;
		var kp = LinuxKernel.kernel_update_minor;
		if (km != null) vprint(_("Latest update")+": "+km.version_main);
		if (kp != null) vprint(_("Latest point update")+": "+kp.version_main);
		if ((km == null) && (kp == null)) vprint(_("No updates found"));
	}

	int notify_user() {
		vprint("notify_user()",3);

		string title = _("No updates found");
		string seen = "";
		string available = "";

		if (App.notify_minor) {
			var k = LinuxKernel.kernel_update_minor;
			if (k!=null && k.version_main!="") available = k.version_main;
			if (exists(App.MINOR_SEEN_FILE)) seen = fread(App.MINOR_SEEN_FILE).strip();
			if (seen!=available) fwrite(App.MINOR_SEEN_FILE,available);
		} else vprint(_("notify minor releases disabled"),2);

		// if notify_major enabled and there is one, simply overwrite available
		if (App.notify_major) {
			var k = LinuxKernel.kernel_update_major;
			if (k!=null && k.version_main!="") available = k.version_main;
			if (exists(App.MAJOR_SEEN_FILE)) seen = fread(App.MAJOR_SEEN_FILE).strip();
			if (seen!=available) fwrite(App.MAJOR_SEEN_FILE,available);
		} else vprint(_("notify major releases disabled"),2);

		if (seen==available) available = "";
		if (available!="") {
			title = _("Kernel %s Available").printf(available);
			string s = APP_LIB_DIR+"/notice.sh"
				+ " -i \"@"+App.NOTIFICATION_ID_FILE+"\""
				+ " -N \""+BRANDING_LONGNAME+"\""
				+ " -n "+BRANDING_SHORTNAME
				+ " -t0"
				+ " -a \""+_("Show")+":"+GUI_EXE+"\""
				+ " -a \""+_("Install")+":"+GUI_EXE+" install "+available+"\""
				+ " -s \""+title+"\""
			;
			exec_async(s);
		} else {
			if (seen!="") title = _("Previously notified")+": \""+seen+"\"";
		}

		vprint(title,2);
		return 0;
	}

}
