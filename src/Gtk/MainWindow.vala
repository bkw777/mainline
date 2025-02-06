/*
 * MainWindow.vala
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

using Gtk;

using l.misc;
using l.exec;

public class MainWindow : Window {
//public class MainWindow : ApplicationWindow {

	const int SPACING = 6;

	Box vbox_main;
	Box hbox_list;

	Button btn_install;
	Button btn_uninstall;
	Button btn_uninstall_old;
	Button btn_reload;
	Label lbl_info;
	Spinner spn_info;
	Gdk.Pixbuf pix_ubuntu;
	Gdk.Pixbuf pix_mainline;
	Gdk.Pixbuf pix_mainline_rc;
	Gdk.Cursor cursor_busy;
	Gdk.Window? win = null;

	bool updating;

	Gee.ArrayList<LinuxKernel> selected_kernels;
	Gtk.ListStore tm;
	TreeView tv;

	enum TM {
		INDEX,
		KOBJ,
		ICON,
		VERSION,
		LOCKED,
		STATUS,
		NOTES,
		TOOLTIP,
		N_COLS
	}

	public MainWindow() {

		destroy.connect(Gtk.main_quit);

		set_default_size(App.window_width,App.window_height);
		if (App.window_x>=0 && App.window_y>=0) move(App.window_x,App.window_y);

		configure_event.connect ((event) => {
			App.window_width = event.width;
			App.window_height = event.height;
			App.window_x = event.x;
			App.window_y = event.y;
			return false;
		});

		title = BRANDING_LONGNAME;
		set_default_icon_name(BRANDING_SHORTNAME);
		try { set_default_icon(IconTheme.get_default().load_icon(BRANDING_SHORTNAME,48,0)); }
		catch (Error e) { vprint(e.message,1,stderr); }
		cursor_busy = new Gdk.Cursor.from_name(Gdk.Display.get_default(),"wait");

		selected_kernels = new Gee.ArrayList<LinuxKernel>();
		tm = new Gtk.ListStore(TM.N_COLS,
			typeof(int),         // TM.INDEX
			typeof(LinuxKernel), // TM.KOBJ
			typeof(Gdk.Pixbuf),  // TM.ICON
			typeof(string),      // TM.VERSION
			typeof(bool),        // TM.LOCKED
			typeof(string),      // TM.STATUS
			typeof(string),      // TM.NOTES
			typeof(string)       // TM.TOOLTIP
		);
		tv = new TreeView.with_model(tm);

		try {
			pix_ubuntu = new Gdk.Pixbuf.from_file(INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/ubuntu-logo.png");
			pix_mainline = new Gdk.Pixbuf.from_file(INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux.png");
			pix_mainline_rc = new Gdk.Pixbuf.from_file(INSTALL_PREFIX + "/share/pixmaps/" + BRANDING_SHORTNAME + "/tux-red.png");
		} catch (Error e) { vprint(e.message,1,stderr); }

		vbox_main = new Box(Orientation.VERTICAL, SPACING);
		vbox_main.margin = SPACING;

		add(vbox_main);

		init_ui();
		/*vprint("show_all()");*/ show_all();
		win = get_window();
		update_cache();
	}

	void init_ui() {
		//vprint("init_ui()");
		init_treeview();
		init_actions();
		init_infobar();
	}

	void init_treeview() {
		//vprint("init_treeview()");
		hbox_list = new Box(Orientation.HORIZONTAL, SPACING);
		vbox_main.add(hbox_list);

		// add treeview
		tv.get_selection().mode = SelectionMode.MULTIPLE;
		tv.headers_visible = true;
		tv.set_grid_lines(TreeViewGridLines.BOTH);
		tv.expand = true;

		tv.row_activated.connect(tv_row_activated);

		tv.get_selection().changed.connect(tv_selection_changed);

		var scrollwin = new ScrolledWindow(((Scrollable) tv).get_hadjustment(), ((Scrollable) tv).get_vadjustment());
		scrollwin.set_shadow_type(ShadowType.ETCHED_IN);
		scrollwin.add (tv);
		hbox_list.add(scrollwin);

		// kernel icon & version
		// sort on the index column not on the version column
		// special version number sorting built by compare_to()
		var col = new TreeViewColumn();
		col.title = _("Kernel");
		col.resizable = true;
		col.set_sort_column_id(TM.INDEX);
		col.min_width = 200;
		tv.append_column(col);

		var k_version_icon = new CellRendererPixbuf();
		k_version_icon.xpad = SPACING;
		col.pack_start(k_version_icon, false);
		col.add_attribute(k_version_icon, "pixbuf", TM.ICON);

		var k_version_text = new CellRendererText();
		k_version_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start(k_version_text, true);
		col.add_attribute(k_version_text, "text", TM.VERSION);

		// locked
		var k_lock_toggle = new CellRendererToggle();
#if LOCK_TOGGLES_IN_KERNEL_COLUMN  // not sortable
		col.pack_end(k_lock_toggle, false);
#else                              // sortable
		col = new TreeViewColumn();
		col.set_sort_column_id(TM.LOCKED);
		col.title = _("Lock");
		col.pack_start(k_lock_toggle, false);
		tv.append_column (col);
#endif
		col.add_attribute(k_lock_toggle,"active", TM.LOCKED);
		k_lock_toggle.toggled.connect((toggle,path) => {
			TreeIter iter;
			tm.get_iter_from_string(out iter, path);
			LinuxKernel k;
			tm.get(iter, TM.KOBJ, out k, -1);
			k.set_locked(!toggle.active);
			tm.set(iter, TM.LOCKED, k.is_locked);
			tm.set(iter, TM.TOOLTIP, k.tooltip_text());
		});

		// status
		col = new TreeViewColumn();
		col.title = _("Status");
		col.set_sort_column_id(TM.STATUS);
		col.resizable = true;
		tv.append_column(col);
		var k_status_text = new CellRendererText();
		k_status_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start(k_status_text, false);
		col.add_attribute(k_status_text, "text", TM.STATUS); // text from column 4

		// notes
		col = new TreeViewColumn();
		col.title = _("Notes");
		col.set_sort_column_id(TM.NOTES);
		col.resizable = true;
		col.min_width = 200;
		tv.append_column(col);
		var k_notes_text = new CellRendererText();
		k_notes_text.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (k_notes_text, false);
		col.add_attribute(k_notes_text, "text", TM.NOTES); // text from column 5
		k_notes_text.editable = true;
		k_notes_text.edited.connect((path, data) => {
			TreeIter i;
			LinuxKernel k;
			tm.get_iter_from_string(out i, path);
			tm.get(i, TM.KOBJ, out k, -1);
			var t_old = k.notes.strip();
			var t_new = data.strip();
			if (t_old != t_new) {
				k.set_notes(t_new);
				tm.set(i, TM.NOTES, t_new);
				tm.set(i, TM.TOOLTIP, k.tooltip_text());
			}
		});

		// tooltip
		tv.set_tooltip_column(TM.TOOLTIP);

	}

	void tv_row_activated(TreePath path, TreeViewColumn column) {
		set_button_state();
	}

	void tv_selection_changed() {
		TreeModel model;
		TreeIter iter;
		var sel = tv.get_selection();
		var paths = sel.get_selected_rows (out model);

		selected_kernels.clear();
		foreach (var path in paths) {
			LinuxKernel k;
			model.get_iter(out iter, path);
			model.get(iter, 1, out k, -1);
			selected_kernels.add(k);
		}

		set_button_state();
	}

	void tv_refresh() {
		//vprint("tv_refresh()",3);

		int i = -1;
		Gdk.Pixbuf p;
		TreeIter iter;
		tm.clear();

		foreach (var k in LinuxKernel.kernel_list) {

			// apply filters, but don't hide any installed
			if (!k.is_installed) {
				if (k.is_invalid && App.hide_invalid) continue;
				if (k.is_unstable && App.hide_unstable) continue;
				if (k.flavor!="generic" && App.hide_flavors) continue;
			}

			tm.append(out iter);

			tm.set(iter, TM.INDEX, ++i); // saves the special sort built by compare_to()

			tm.set(iter, TM.KOBJ, k);

			p = pix_mainline;
			if (k.is_unstable) p = pix_mainline_rc;
			if (!k.is_mainline) p = pix_ubuntu;
			tm.set(iter, TM.ICON, p);

#if DISPLAY_VERSION_SORT
			tm.set(iter, TM.VERSION, k.version_sort);
#else
			tm.set(iter, TM.VERSION, k.version_main);
#endif

			tm.set(iter, TM.LOCKED, k.is_locked);

			tm.set(iter, TM.STATUS, k.status);

			tm.set(iter, TM.NOTES, k.notes);

			tm.set(iter, TM.TOOLTIP, k.tooltip_text());
		}

		selected_kernels.clear();
		updating = false;
		set_infobar();
		set_button_state();
	}

	void set_button_state() {
		btn_install.sensitive = false;
		btn_uninstall.sensitive = false;

		if (updating) {
			btn_uninstall_old.sensitive = false;
			btn_reload.sensitive = false;
			return;
		}

		btn_uninstall_old.sensitive = true;
		btn_reload.sensitive = true;

		foreach (var k in selected_kernels) {
			if (k.is_locked || k.is_running) continue;
			if (k.is_installed) btn_uninstall.sensitive = true;
			else if (!k.is_invalid) btn_install.sensitive = true;
		}
	}

	void init_actions() {
		//vprint("init_actions()");

		Button button;

		var hbox = new Box(Orientation.VERTICAL, SPACING);
		hbox_list.add (hbox);

		// install
		btn_install = new Button.with_label (_("Install"));
		hbox.pack_start (btn_install, true, true, 0);
		btn_install.clicked.connect(() => { do_install(selected_kernels); });

		// uninstall
		btn_uninstall = new Button.with_label (_("Uninstall"));
		hbox.pack_start (btn_uninstall, true, true, 0);
		btn_uninstall.clicked.connect(() => { do_uninstall(selected_kernels); });

		// ppa
		button = new Button.with_label ("PPA");
		button.set_tooltip_text(_("Changelog, build status, etc"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(() => {
			string uri = App.ppa_uri;
			if (selected_kernels.size==1 && selected_kernels[0].is_mainline) uri=selected_kernels[0].page_uri;
			if (!uri_open(uri)) AppGtk.alert(this,_("Unable to launch")+" "+uri,Gtk.MessageType.ERROR);
		});

		// uninstall-old
		btn_uninstall_old = new Button.with_label (_("Uninstall Old"));
		btn_uninstall_old.set_tooltip_text(_("Uninstall everything except:\n* the highest installed version\n* the currently running kernel\n* any kernels that are locked"));
		hbox.pack_start (btn_uninstall_old, true, true, 0);
		btn_uninstall_old.clicked.connect(uninstall_old);

		// reload
		btn_reload = new Button.with_label (_("Reload"));
		btn_reload.set_tooltip_text(_("Delete and reload all cached kernel info\n(the same as \"mainline --delete-cache\")"));
		hbox.pack_start (btn_reload, true, true, 0);
		btn_reload.clicked.connect(() => { update_cache(true); });

		// settings
		button = new Button.with_label (_("Settings"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_settings);

		// about
		button = new Button.with_label (_("About"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(do_about);

		// exit
		button = new Button.with_label (_("Exit"));
		hbox.pack_start (button, true, true, 0);
		button.clicked.connect(Gtk.main_quit);

	}

	void do_settings () {
		// capture some settings before to detect if they change

		// settings that change the selection set -> trigger cache update
		var old_hide_invalid = App.hide_invalid;
		var old_hide_unstable = App.hide_unstable;
		var old_hide_flavors = App.hide_flavors;
		var old_previous_majors = App.previous_majors;

		// settings that change the notification behavior -> trigger notify script update
		var old_notify_interval_unit = App.notify_interval_unit;
		var old_notify_interval_value = App.notify_interval_value;
		var old_notify_major = App.notify_major;
		var old_notify_minor = App.notify_minor;

		var swin = new SettingsWindow(this);

		swin.destroy.connect(() => {

			App.save_app_config(); // blindly sets RUN_NOTIFY_SCRIPT = true;

			// if notify settings did not change, then un-flag notify script update
			if (App.notify_interval_value == old_notify_interval_value &&
				App.notify_interval_unit == old_notify_interval_unit &&
				App.notify_major == old_notify_major &&
				App.notify_minor == old_notify_minor) App.RUN_NOTIFY_SCRIPT = false;

			// if the selection set changed, then update cache
			if (App.hide_invalid != old_hide_invalid ||
				App.hide_unstable != old_hide_unstable ||
				App.hide_flavors != old_hide_flavors ||
				App.previous_majors != old_previous_majors) update_cache();

			// in case we didn't run update_cache()
			App.run_notify_script_if_due();

		});

		swin.show_all();

	}

	void do_about() {

		string[] authors = {
			"Tony George <teejeetech@gmail.com>",
			BRANDING_AUTHORNAME+" <"+BRANDING_AUTHOREMAIL+">"
		};

		show_about_dialog(this,
			program_name:BRANDING_LONGNAME,
			logo_icon_name:BRANDING_SHORTNAME,
			version:BRANDING_VERSION,
			website:BRANDING_WEBSITE,
			website_label:BRANDING_WEBSITE,
			comments:_("A tool for installing kernel packages\nfrom the Ubuntu Mainline Kernels PPA"),
			copyright:
				"\"ukuu\" 2015 Tony George\n" +
				"\""+BRANDING_SHORTNAME+"\" "+BRANDING_COPYRIGHT+" "+BRANDING_AUTHORNAME,
			authors:authors,
			translator_credits:TRANSLATORS,
			license_type:License.GPL_3_0
		);
	}

	// Update the cache as optimally as possible.
	void update_cache(bool reload=false) {
		vprint("update_cache(reload="+reload.to_string()+")",3);
		string msg = _("Updating Kernels...");
		win.set_cursor(cursor_busy);
		updating = true;
		set_button_state();
		set_infobar(msg,updating);
		//tm.clear(); // blank the list while updating
		if (reload) { tm.clear(); LinuxKernel.delete_cache(); }
		LinuxKernel.mk_kernel_list(false, (last) => { update_status_line(msg, last); });
	}

	// I really don't like this 'last' hack to detect end of job
	void update_status_line(string message, bool last = false) {
		if (last) {
			Gdk.threads_add_idle_full(Priority.DEFAULT_IDLE, () => {
				tv_refresh();
				win.set_cursor(null);
				// I hate that this is here, there must be a better way
				// it's here because it requires mk_kernel_list finished
				if (App.command == "install") {
					App.command = "";
					do_install(LinuxKernel.vlist_to_klist(App.requested_versions));
				}
				return false;
			});
		}

		Gdk.threads_add_idle_full(Priority.DEFAULT_IDLE, () => {
			if (updating) set_infobar("%s: %s %d/%d".printf(message, App.status_line, App.progress_count, App.progress_total),updating);
			return false;
		});
	}

	void init_infobar() {
		//vprint("init_infobar()");
		var hbox = new Box(Orientation.HORIZONTAL,SPACING);
		vbox_main.add(hbox);
		lbl_info = new Label("");
		spn_info = new Spinner();
		hbox.set_homogeneous(false);
		hbox.pack_start(lbl_info);
		hbox.pack_end(spn_info);
		lbl_info.set_use_markup(true);
		lbl_info.selectable = false;
		lbl_info.hexpand = true;
		lbl_info.halign = Align.START;
		spn_info.active = false;
		spn_info.hexpand = false;
		spn_info.halign = Align.END;
	}

	void set_infobar(string? text=null, bool busy=false) {
		string s;

		if (text!=null) s = text;
		else {
			s = _("Running")+" <b>%s</b>".printf(LinuxKernel.kernel_active.version_main);
			if (LinuxKernel.kernel_active.is_mainline) s += " (mainline)"; else s += " (ubuntu)";
			if (LinuxKernel.kernel_latest_available.compare_to(LinuxKernel.kernel_latest_installed) > 0)
				s += " ~ <b>%s</b> ".printf(LinuxKernel.kernel_latest_available.version_main)+_("available");
		}

		lbl_info.set_label(s);
		spn_info.active = busy;
	}

	public void do_install(Gee.ArrayList<LinuxKernel> klist) {
		string[] vlist = {};
		if (Main.VERBOSE>2) {
			foreach (var k in klist) vlist += k.version_main;
			vprint("do_install("+string.joinv(" ",vlist)+")");
		}
		if (klist==null || klist.size<1) return;
		vlist = {};
		foreach (var k in klist) vlist += k.version_main;

		string[] cmd = { BRANDING_SHORTNAME, "--from-gui" };
		if (App.term_cmd!=DEFAULT_TERM_CMDS[0]) cmd += "--pause";
		cmd += "install";
		cmd += string.joinv(",",vlist);
		exec_in_term(cmd);
	}

	public void do_uninstall(Gee.ArrayList<LinuxKernel> klist) {
		string[] vlist = {};
		if (Main.VERBOSE>2) {
			foreach (var k in klist) vlist += k.version_main;
			vprint("do_uninstall("+string.joinv(" ",vlist)+")");
		}
		if (klist==null || klist.size<1) return;
		vlist = {};
		foreach(var k in klist) vlist += k.version_main;

		string[] cmd = { BRANDING_SHORTNAME, "--from-gui" };
		if (App.term_cmd!=DEFAULT_TERM_CMDS[0]) cmd += "--pause";
		cmd += "uninstall";
		cmd += string.joinv(",",vlist);
		exec_in_term(cmd);
	}

	public void uninstall_old() {
		string[] cmd = { BRANDING_SHORTNAME, "--from-gui" };
		if (App.term_cmd!=DEFAULT_TERM_CMDS[0]) cmd += "--pause";
		cmd += "uninstall-old";
		exec_in_term(cmd);
	}

	public void exec_in_term(string[] argv) {

		if (App.term_cmd==DEFAULT_TERM_CMDS[0]) {
			// internal vte terminal
			var term = new TerminalWindow.with_parent(this);
			term.cmd_complete.connect(() => { update_cache(); });
			term.execute_cmd(argv);
		} else {
			// external terminal app
			var cmd = sanitize_cmd(App.term_cmd).printf(string.joinv(" ",argv));
			vprint(cmd,3);
			Posix.system(cmd); // cmd must block!
			update_cache();
		}

	}

}
