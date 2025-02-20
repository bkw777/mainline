
using l_misc;

public class SettingsWindow : Gtk.Window {

	public SettingsWindow(Gtk.Window parent) {

		const int SPACING = 6;

		this.set_transient_for(parent);
		this.set_modal(true);
		this.title = BRANDING_LONGNAME + " " +_("Configuration");
		this.window_position = Gtk.WindowPosition.CENTER_ON_PARENT;

		// vbox_main holds the notebook and the close button
		var vbox_main = new Gtk.Box(Gtk.Orientation.VERTICAL,0);
		this.add(vbox_main);

		// notebook holds a page for each settings section
		var notebook = new Gtk.Notebook();
		vbox_main.add(notebook);

		// close button outside of notebook always visible
		var btn_close = new Gtk.Button.with_label(_("Done"));
		vbox_main.add(btn_close);
		btn_close.clicked.connect(close);

		// fill the notebook pages
		Gtk.Box pgbox;
		Gtk.Box hbox;
		Gtk.Label pgtitle;
		Gtk.Label label;

		//==============================================================
		// Page 1 - FILTERS
		//==============================================================

		//pgtitle = new Gtk.Label("<b>" + _("Filters") + "</b>");
		//pgtitle.set_use_markup(true);
		pgtitle = new Gtk.Label(_("Filter"));
		pgbox = new Gtk.Box(Gtk.Orientation.VERTICAL,SPACING);
		notebook.append_page(pgbox,pgtitle);
		pgbox.spacing = SPACING;
		pgbox.margin = SPACING*2;

		// hide unstable
		var chk_hide_rc = new Gtk.CheckButton.with_label(_("Hide RC and unstable releases"));
		pgbox.add(chk_hide_rc);
		//chk_hide_rc.set_tooltip_text(_("..."));
		chk_hide_rc.active = App.hide_unstable;
		chk_hide_rc.toggled.connect(()=>{ App.hide_unstable = chk_hide_rc.active; });

		// hide invalid
		var chk_hide_invalid = new Gtk.CheckButton.with_label(_("Hide failed or incomplete builds"));
		pgbox.add(chk_hide_invalid);
		chk_hide_invalid.set_tooltip_text(
			_("If a kernel version exists on the mainline-ppa site, but is an incomplete or failed build for your arch (%s), then don't show it in the list.").printf(LinuxKernel.NATIVE_ARCH)
		);
		chk_hide_invalid.active = App.hide_invalid;
		chk_hide_invalid.toggled.connect(()=>{ App.hide_invalid = chk_hide_invalid.active; });

		// hide flavors
		var chk_hide_flavors = new Gtk.CheckButton.with_label(_("Hide flavors other than %s").printf("\"generic\""));
		pgbox.add(chk_hide_flavors);
		chk_hide_flavors.set_tooltip_text(
			_("Don't show the alternative flavors such as %s and %s").printf("\"lowlatency\"","\"generic-64k\"")
		);
		chk_hide_flavors.active = App.hide_flavors;
		chk_hide_flavors.toggled.connect(()=>{ App.hide_flavors = chk_hide_flavors.active; });

		// show prior versions
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		pgbox.add(hbox);
		label = new Gtk.Label(_("Show"));
		hbox.add(label);
		var adj_show_prior = new Gtk.Adjustment(App.previous_majors, -1, LinuxKernel.kernel_latest_available.version_major , 1, 1, 0);
		var spn_show_prior = new Gtk.SpinButton (adj_show_prior, 1, 0);
		hbox.add(spn_show_prior);
		spn_show_prior.changed.connect(()=>{ App.previous_majors = (int)spn_show_prior.get_value(); });
		label = new Gtk.Label(_("prior major versions  ( -1 = all )"));
		hbox.add(label);
		//hbox.set_tooltip_text(_("...show previous majors tooltip text..."));

		//==============================================================
		// Page 2 - NOTIFICATIONS
		//==============================================================

		pgtitle = new Gtk.Label(_("Notification"));
		pgbox = new Gtk.Box(Gtk.Orientation.VERTICAL,SPACING);
		notebook.append_page(pgbox,pgtitle);
		pgbox.spacing = SPACING;
		pgbox.margin = SPACING*2;

		// notify major
		var chk_notify_major = new Gtk.CheckButton.with_label(_("Notify if a major release is available"));
		pgbox.add(chk_notify_major);
		chk_notify_major.active = App.notify_major;
		chk_notify_major.toggled.connect(()=>{ App.notify_major = chk_notify_major.active; });

		// notify minor
		var chk_notify_minor = new Gtk.CheckButton.with_label(_("Notify if a minor release is available"));
		pgbox.add(chk_notify_minor);
		chk_notify_minor.active = App.notify_minor;
		chk_notify_minor.toggled.connect(()=>{ App.notify_minor = chk_notify_minor.active; });

		// notification interval
		if (Main.VERBOSE>1) {
			label = new Gtk.Label("( VERBOSE="+Main.VERBOSE.to_string()+" : "+_("Seconds interval enabled for debugging")+" )");
			pgbox.add(label);
			label.xalign = 0;
		}
		// replace invalid debug-only values with valid values
		int max_intervals = 52;
		if (Main.VERBOSE>1) {
			// debug allows seconds, allow up to 1 hour of seconds
			max_intervals = 3600;
		} else {
			if (App.notify_interval_unit == 3) {
				App.notify_interval_value = DEFAULT_NOTIFY_INTERVAL_VALUE;
				App.notify_interval_unit = DEFAULT_NOTIFY_INTERVAL_UNIT;
			}
		}
		//
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		pgbox.add(hbox);
		//
		label = new Gtk.Label(_("Check every"));
		hbox.add(label);
		// value
		var adj_interval = new Gtk.Adjustment(App.notify_interval_value, 1, max_intervals, 1, 1, 0);
		var spn_interval = new Gtk.SpinButton(adj_interval, 1, 0);
		hbox.add(spn_interval);
		spn_interval.changed.connect(()=>{ App.notify_interval_value = (int)spn_interval.get_value(); });
		// units
		var cbt_units = new Gtk.ComboBoxText();
		hbox.add(cbt_units);
		cbt_units.append_text(_("Hours"));
		cbt_units.append_text(_("Days"));
		cbt_units.append_text(_("Weeks"));
		if (Main.VERBOSE>1) cbt_units.append_text(_("Seconds"));
		cbt_units.active = App.notify_interval_unit;
		cbt_units.changed.connect(() => { App.notify_interval_unit = cbt_units.active; });
		//hbox.set_tooltip_text(_("...notification interval tooltip text..."));

		//==============================================================
		// Page 3 - NETWORK
		//==============================================================

		pgtitle = new Gtk.Label(_("Network"));
		pgbox = new Gtk.Box(Gtk.Orientation.VERTICAL,SPACING);
		notebook.append_page(pgbox,pgtitle);
		pgbox.spacing = SPACING;
		pgbox.margin = SPACING*2;

        // connect timeout
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		pgbox.add(hbox);
		//
		label = new Gtk.Label(_("Connection Timeout:"));
		hbox.add(label);
		//
		var adj_ict = new Gtk.Adjustment(App.connect_timeout_seconds, 1, 60, 1, 1, 0);
		var spn_ict = new Gtk.SpinButton (adj_ict, 1, 0);
		hbox.add(spn_ict);
		spn_ict.changed.connect(()=>{ App.connect_timeout_seconds = (int)spn_ict.get_value(); });
		//
		label = new Gtk.Label(_("seconds"));
		hbox.add(label);
		//hbox.set_tooltip_text(_("...http connect timeout tooltip text..."));

		// concurrent downloads
		hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, SPACING);
		pgbox.add (hbox);
		//
		label = new Gtk.Label(_("Concurrent Downloads:"));
		hbox.add(label);
		//
		var adj_pdl = new Gtk.Adjustment(App.concurrent_downloads, 1, 25, 1, 1, 0);
		var spn_pdl = new Gtk.SpinButton (adj_pdl, 1, 0);
		hbox.add(spn_pdl);
		spn_pdl.changed.connect(()=>{ App.concurrent_downloads = (int)spn_pdl.get_value(); });
		//hbox.set_tooltip_text(_("...concurrent downloads tooltip text..."));

		// verify checksums
		var chk_checksums = new Gtk.CheckButton.with_label(_("Verify Checksums"));
		pgbox.add(chk_checksums);
		chk_checksums.active = App.verify_checksums;
		chk_checksums.set_tooltip_text(_("Use the sha-256 hashes from the CHECKSUMS file to verify the *.deb file downloads."));
		chk_checksums.toggled.connect(()=>{ App.verify_checksums = chk_checksums.active; });

		// keep downloads
		var chk_keep_debs = new Gtk.CheckButton.with_label(_("Keep Debs"));
		pgbox.add(chk_keep_debs);
		chk_keep_debs.set_tooltip_text(
			_("Retain downloaded *.deb files after install and re-use them for uninstall/reinstall instead of downloading again.") + "\n"
			+ "\n"
			+ _("They are still deleted once they become older than the \"prior major versions\" setting, or if they have been updated on the mainline-ppa site.")
		);
		chk_keep_debs.active = App.keep_debs;
		chk_keep_debs.toggled.connect(()=>{ App.keep_debs = chk_keep_debs.active; });

		// keep cache
		var chk_keep_cache = new Gtk.CheckButton.with_label(_("Keep Cache"));
		pgbox.add(chk_keep_cache);
		chk_keep_cache.set_tooltip_text(
			_("Don't trim the cached index.html files to just the installed versions and higher, instead essentially maintain a local mirror of the entire history from the mainline-ppa site.") + "\n"
			+ "\n"
			+ _("This speeds up some things a little at the cost of about 20M of hard drive space.") + "\n"
			+ _("It skips a step on every startup that loops through all known kernel versions just to see if there are any old ones to delete, and avoids deleting and re-downloading the same files if you change the \"prior major versions\" setting up and down.") + "\n"
			+ "\n"
			+ _("As of 6.5.x a full cache is about 22M, and a trimmed cache is about 2M.")
		);
		chk_keep_cache.active = App.keep_cache;
		chk_keep_cache.toggled.connect(()=>{ App.keep_cache = chk_keep_cache.active; });

		// proxy
		label = new Gtk.Label(_("Proxy"));
		pgbox.add(label);
		label.xalign = 0;

		var ent_proxy = new Gtk.Entry ();
		pgbox.add(ent_proxy);
		ent_proxy.set_placeholder_text("[http://][USER:PASSWORD@]HOST[:PORT]");
		//ent_proxy.set_tooltip_text(_("..."));
		ent_proxy.set_text(App.all_proxy);
		ent_proxy.activate.connect(()=>{ App.all_proxy = ent_proxy.get_text(); });

		// ppa url
		label = new Gtk.Label(_("Mainline-PPA URL"));
		pgbox.add(label);
		label.xalign = 0;

		var ent_ppaurl = new Gtk.Entry ();
		pgbox.add(ent_ppaurl);
		//ent_ppaurl.set_tooltip_text(_("..."));
		ent_ppaurl.set_text(App.ppa_uri);
		ent_ppaurl.activate.connect(()=>{
			App.ppa_uri = ent_ppaurl.get_text().strip();
			if (App.ppa_uri=="") {
				App.ppa_uri = DEFAULT_PPA_URI;
				ent_ppaurl.set_text(App.ppa_uri);
			}
		});

		//==============================================================
		// Page 4 - EXTERNAL COMMANDS
		//==============================================================

		pgtitle = new Gtk.Label(_("External Commands"));
		pgbox = new Gtk.Box(Gtk.Orientation.VERTICAL,SPACING);
		notebook.append_page(pgbox,pgtitle);
		pgbox.spacing = SPACING;
		pgbox.margin = SPACING*2;

		// auth command
		label = new Gtk.Label(_("Superuser Authorization"));
		pgbox.add(label);
		label.xalign = 0;

		var cbt_authcmd = new Gtk.ComboBoxText.with_entry();
		pgbox.add(cbt_authcmd);
		cbt_authcmd.active = -1;
		for (int i=0;i<DEFAULT_AUTH_CMDS.length;i++) {
			cbt_authcmd.append_text(DEFAULT_AUTH_CMDS[i]);
			if (App.auth_cmd == DEFAULT_AUTH_CMDS[i]) cbt_authcmd.active = i;
		}
		if (cbt_authcmd.active<0) {
			cbt_authcmd.append_text(App.auth_cmd);
			cbt_authcmd.active = DEFAULT_AUTH_CMDS.length;
		} else {
			cbt_authcmd.append_text("");
		}
		cbt_authcmd.changed.connect(() => {
			string s = cbt_authcmd.get_active_text().strip();
			if (s != App.auth_cmd) App.auth_cmd = s;
		});
		cbt_authcmd.set_tooltip_text(
			_("Command used to run dpkg with root permissions.") + "\n"
			+ "\n"
			+ /* xgettext:no-c-format */ _("The dpkg command is appended to the end, unless a %s is present.") + "\n"
			+ /* xgettext:no-c-format */ _("If a %s is present, then the %s is replaced with the dpkg command.") + "\n"
			+ _("The built-in list contains examples of both.") +"\n"
			+ "\n"
			+ _("To modify any of the built-in default commands, just select it and edit.") + "\n"
			+ _("The edited command is saved in the config file, the original is not changed.")
		);

		// xterm command
		label = new Gtk.Label(_("Terminal Window"));
		pgbox.add(label);
		label.xalign = 0;

		var cbt_termcmd = new Gtk.ComboBoxText.with_entry();
		pgbox.add(cbt_termcmd);
		cbt_termcmd.active = -1;
		for (int i=0;i<DEFAULT_TERM_CMDS.length;i++) {
			cbt_termcmd.append_text(DEFAULT_TERM_CMDS[i]);
			if (App.term_cmd == DEFAULT_TERM_CMDS[i]) cbt_termcmd.active = i;
		}
		if (cbt_termcmd.active<0) {
			cbt_termcmd.append_text(App.term_cmd);
			cbt_termcmd.active = DEFAULT_TERM_CMDS.length;
		} else {
			cbt_termcmd.append_text("");
		}
		cbt_termcmd.changed.connect(() => {
			string s = cbt_termcmd.get_active_text().strip();
			if (s != App.term_cmd) App.term_cmd = s;
		});
		cbt_termcmd.set_tooltip_text(
			_("Terminal command used to run")+" \""+BRANDING_SHORTNAME+" install|uninstall ...\"\n"
			+ "\n"
			+ /* xgettext:no-c-format */ _("The install/uninstall command is appended to the end, unless a %s is present.") + "\n"
			+ /* xgettext:no-c-format */ _("If a %s is present, then the %s is replaced with the install/uninstall command.") + "\n"
			+ _("The built-in list contains examples of both.") + "\n"
			+ "\n"
			+ _("The terminal program must stay in the foreground and block while the command is running, not fork and return immediately.") + "\n"
			+ _("Most terminal programs block by default, some require special commandline options.") + "\n"
			+ _("For example, %s requires \"%s\".").printf("gnome-terminal","--wait") + "\n"
			+ "\n"
			+ _("To modify any of the built-in default commands, just select it and edit.") + "\n"
			+ _("The edited command is saved in the config file, the original is not changed.")
		);

	}

}
