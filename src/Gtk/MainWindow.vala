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
using Gee;

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.GtkHelper;
using TeeJee.System;
using TeeJee.Misc;

public class MainWindow : Gtk.Window{

	private Gtk.Box vbox_main;
	private Gtk.Box hbox_list;

	private Gtk.TreeView tv;
	private Gtk.Button btn_refresh;
	private Gtk.Button btn_install;
	private Gtk.Button btn_remove;
	private Gtk.Button btn_purge;
	private Gtk.Button btn_changes;
	private Gtk.Label lbl_info;

	// helper members

	private int window_width = 800;
	private int window_height = 600;
	private uint tmr_init = -1;

	private Gee.ArrayList<LinuxKernel> selected_kernels;

	public MainWindow() {

		title = BRANDING_LONGNAME;
		window_position = WindowPosition.CENTER;
		icon = get_app_icon(16,".svg");

		// vbox_main
		vbox_main = new Gtk.Box(Orientation.VERTICAL, 6);
		vbox_main.margin = 6;
		vbox_main.set_size_request(window_width, window_height);
		add (vbox_main);

		selected_kernels = new Gee.ArrayList<LinuxKernel>();

		init_ui();

		tmr_init = Timeout.add(100, init_delayed);
	}

	private bool init_delayed() {

		/* any actions that need to run after window has been displayed */

		if (tmr_init > 0) {
			Source.remove(tmr_init);
			tmr_init = 0;
		}

		refresh_cache();

		tv_refresh();

		switch (App.command){
		case "install":

			LinuxKernel kern_requested = null;
			foreach(var kern in LinuxKernel.kernel_list){
				if (kern.name == App.requested_version){
					kern_requested = kern;
					break;
				}
			}

			if (kern_requested == null){
				var msg = _("Could not find requested version");
				msg += ": %s".printf(App.requested_version);
				log_error(msg);
				exit(1);
			}
			else{
				install(kern_requested);
			}

			break;

		case "notify":

			notify_user();
			break;
		}

		return false;
	}

	private void init_ui(){
		init_treeview();
		init_actions();
		init_infobar();
	}

	private void init_treeview(){

		// hbox
		hbox_list = new Gtk.Box(Orientation.HORIZONTAL, 6);
		//hbox.margin = 6;
		vbox_main.add(hbox_list);

		//add treeview
		tv = new TreeView();
		tv.get_selection().mode = SelectionMode.MULTIPLE;
		tv.headers_visible = true;
		tv.expand = true;

		tv.row_activated.connect(tv_row_activated);

		tv.get_selection().changed.connect(tv_selection_changed);

		var scrollwin = new ScrolledWindow(tv.get_hadjustment(), tv.get_vadjustment());
		scrollwin.set_shadow_type (ShadowType.ETCHED_IN);
		scrollwin.add (tv);
		hbox_list.add(scrollwin);

		//column
		var col = new TreeViewColumn();
		col.title = _("Kernel");
		col.resizable = true;
		col.min_width = 150;
		tv.append_column(col);

		// cell icon
		var cell_pix = new Gtk.CellRendererPixbuf ();
		cell_pix.xpad = 4;
		cell_pix.ypad = 6;
		col.pack_start (cell_pix, false);
		col.set_cell_data_func (cell_pix, (cell_layout, cell, model, iter)=>{
			Gdk.Pixbuf pix;
			model.get (iter, 1, out pix, -1);
			(cell as Gtk.CellRendererPixbuf).pixbuf = pix;
			//(cell as Gtk.CellRendererPixbuf).visible = !(App.hide_unstable);
		});

		//cell text
		var cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);
		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel kern;
			model.get (iter, 0, out kern, -1);
			(cell as Gtk.CellRendererText).text = "Linux " + kern.version_main;
		});

		//column
		col = new TreeViewColumn();
		col.title = _("Version");
		col.resizable = true;
		col.min_width = 150;
		tv.append_column(col);

		//cell text
		cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);
		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel kern;
			model.get (iter, 0, out kern, -1);
			(cell as Gtk.CellRendererText).text = kern.name;
		});

		//column
		col = new TreeViewColumn();
		col.title = _("Status");
		col.resizable = true;
		col.min_width = 100;
		tv.append_column(col);

		//cell text
		cellText = new CellRendererText();
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);
		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			LinuxKernel kern;
			model.get (iter, 0, out kern, -1);
			(cell as Gtk.CellRendererText).text = kern.is_running ? _("Running") : (kern.is_installed ? _("Installed") : "");
		});

		//column
		col = new TreeViewColumn();
		col.title = "";
		tv.append_column(col);

		//cell text
		cellText = new CellRendererText();
		cellText.width = 10;
		cellText.ellipsize = Pango.EllipsizeMode.END;
		col.pack_start (cellText, false);

		col.set_cell_data_func (cellText, (cell_layout, cell, model, iter)=>{
			bool odd_row;
			model.get (iter, 2, out odd_row, -1);
		});

		tv.set_tooltip_column(3);
	}

	private void tv_row_activated(TreePath path, TreeViewColumn column){
		TreeIter iter;
		tv.model.get_iter_from_string(out iter, path.to_string());
		LinuxKernel kern;
		tv.model.get (iter, 0, out kern, -1);

		set_button_state();
	}

	private void tv_selection_changed(){
		var sel = tv.get_selection();

		TreeModel model;
		TreeIter iter;
		var paths = sel.get_selected_rows (out model);

		selected_kernels.clear();
		foreach(var path in paths){
			LinuxKernel kern;
			model.get_iter(out iter, path);
			model.get (iter, 0, out kern, -1);
			selected_kernels.add(kern);
			//log_msg("size=%d".printf(selected_kernels.size));
		}

		set_button_state();
	}

	private void tv_refresh(){
		var model = new Gtk.ListStore(4, typeof(LinuxKernel), typeof(Gdk.Pixbuf), typeof(bool), typeof(string));

		Gdk.Pixbuf pix_ubuntu = null;
		Gdk.Pixbuf pix_mainline = null;
		Gdk.Pixbuf pix_mainline_rc = null;

		try {
			pix_ubuntu = new Gdk.Pixbuf.from_file ("/usr/share/" + BRANDING_SHORTNAME + "/images/ubuntu-logo.png");

			pix_mainline = new Gdk.Pixbuf.from_file ("/usr/share/" + BRANDING_SHORTNAME + "/images/tux.png");

			pix_mainline_rc = new Gdk.Pixbuf.from_file ("/usr/share/" + BRANDING_SHORTNAME + "/images/tux-red.png");
		}
		catch (Error e) {
			log_error (e.message);
		}

		var kern_4 = new LinuxKernel.from_version("4.0");
		var kern_5 = new LinuxKernel.from_version("5.0");

		TreeIter iter;
		bool odd_row = false;
		foreach(var kern in LinuxKernel.kernel_list) {
			if (!kern.is_valid){
				continue;
			}
			if (LinuxKernel.hide_unstable && kern.is_unstable){
				continue;
			}
			if (LinuxKernel.hide_older5 && (kern.compare_to(kern_5) < 0)){
				continue;
			}
			if (LinuxKernel.hide_older && (kern.compare_to(kern_4) < 0)){
				continue;
			}


			odd_row = !odd_row;

			//add row
			model.append(out iter);
			model.set (iter, 0, kern);

			if (kern.is_mainline){
				if (kern.is_unstable){
					model.set (iter, 1, pix_mainline_rc);
				}
				else{
					model.set (iter, 1, pix_mainline);
				}
			}
			else{
				model.set (iter, 1, pix_ubuntu);
			}

			model.set (iter, 2, odd_row);
			model.set (iter, 3, kern.tooltip_text());
		}

		tv.set_model(model);
		tv.columns_autosize();

		selected_kernels.clear();
		set_button_state();

		set_infobar();
	}

	private void set_button_state(){
		if (selected_kernels.size == 0){
			btn_install.sensitive = false;
			btn_remove.sensitive = false;
			btn_purge.sensitive = true;
			btn_changes.sensitive = false;
		}
		else{
			btn_install.sensitive = (selected_kernels.size == 1) && !selected_kernels[0].is_installed;
			btn_remove.sensitive = selected_kernels[0].is_installed && !selected_kernels[0].is_running;
			btn_purge.sensitive = true;
			btn_changes.sensitive = (selected_kernels.size == 1) && file_exists(selected_kernels[0].changes_file);
		}
	}

	private void init_actions(){

		var hbox = new Gtk.Box(Orientation.VERTICAL, 6);
		hbox_list.add (hbox);

		// refresh
		var button = new Gtk.Button.with_label (_("Refresh"));
		hbox.pack_start (button, true, true, 0);
		btn_refresh = button;

		button.clicked.connect(() => {

			if (!check_internet_connectivity()){
				gtk_messagebox(_("No Internet"), _("Internet connection is not active"), this, true);
				return;
			}

			refresh_cache();
			tv_refresh();
		});

		// install
		button = new Gtk.Button.with_label (_("Install"));
		hbox.pack_start (button, true, true, 0);
		btn_install = button;

		button.clicked.connect(() => {
			if (selected_kernels.size == 1){
				install(selected_kernels[0]);
			}
			else if (selected_kernels.size > 1){
				gtk_messagebox(_("Multiple Kernels Selected"),_("Select a single kernel to install"), this, true);
			}
			else{
				gtk_messagebox(_("Not Selected"),_("Select the kernel to install"), this, true);
			}
		});

		// remove
		button = new Gtk.Button.with_label (_("Remove"));
		hbox.pack_start (button, true, true, 0);
		btn_remove = button;

		button.clicked.connect(() => {
			if (selected_kernels.size == 0){
				gtk_messagebox(_("Not Selected"),_("Select the kernels to remove"), this, true);
			}
			else if (selected_kernels.size > 0){
				
				var term = new TerminalWindow.with_parent(this, false, true);

				term.script_complete.connect(()=>{
					term.allow_window_close();
				});

				term.destroy.connect(()=>{
					this.present();
					refresh_cache();
					tv_refresh();
				});

				string sh = "";
				sh += "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY "; 
				sh += BRANDING_SHORTNAME+" --user %s".printf(App.user_login);
				if (LOG_DEBUG){
					sh += " --debug";
				}

				string names = "";
				foreach(var kern in selected_kernels){
					if (names.length > 0){
						names += ",";
					}
					names += "%s".printf(kern.name);
				}

				sh += " --remove %s\n".printf(names);

				sh += "echo ''\n";
				sh += "echo 'Close window to exit...'\n";

				this.hide();

				term.execute_script(save_bash_script_temp(sh));
			}
		});

		// purge
		button = new Gtk.Button.with_label (_("Purge"));
		button.set_tooltip_text(_("Remove installed kernels older than running kernel"));
		hbox.pack_start (button, true, true, 0);
		btn_purge = button;

		button.clicked.connect(() => {

			var term = new TerminalWindow.with_parent(this, false, true);

			term.script_complete.connect(()=>{
				term.allow_window_close();
			});

			term.destroy.connect(()=>{
				this.present();
				refresh_cache();
				tv_refresh();
			});

			string sh = "";
			sh += "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY http_proxy=$http_proxy https_proxy=$https_proxy HTTP_PROXY=$HTTP_PROXY HTTPS_PROXY=$HTTPS_PROXY ";
			sh += BRANDING_SHORTNAME+" --user "+App.user_login;
			if (LOG_DEBUG){
				sh += " --debug";
			}

			sh += " --purge-old-kernels\n";

			log_debug(sh);

			sh += "echo ''\n";
			sh += "echo 'Close window to exit...'\n";

			this.hide();

			term.execute_script(save_bash_script_temp(sh));
		});

		// changes
		button = new Gtk.Button.with_label (_("Changes"));
		hbox.pack_start (button, true, true, 0);
		btn_changes = button;

		button.clicked.connect(() => {
			if ((selected_kernels.size == 1) && file_exists(selected_kernels[0].changes_file)){
				xdg_open(selected_kernels[0].changes_file);
			}
		});

		// settings
		button = new Gtk.Button.with_label (_("Settings"));
		hbox.pack_start (button, true, true, 0);

		button.clicked.connect(() => {

			bool prev_hide_older = LinuxKernel.hide_older;
			bool prev_hide_unstable = LinuxKernel.hide_unstable;

			var dlg = new SettingsDialog.with_parent(this);
			dlg.run();
			dlg.destroy();

			if (((prev_hide_older == true) && (LinuxKernel.hide_older == false))
				|| ((prev_hide_unstable == true) && (LinuxKernel.hide_unstable == false))){
				refresh_cache();
			}

			tv_refresh();
		});

		// about
		button = new Gtk.Button.with_label (_("About"));
		hbox.pack_start (button, true, true, 0);

		button.clicked.connect(btn_about_clicked);
	}

	private void btn_about_clicked () {

		var dialog = new AboutWindow();
		dialog.set_transient_for (this);

		// FIXME - this should come from the AUTHORS file, or from git
		dialog.authors = {
			"Tony George:teejeetech@gmail.com",
			BRANDING_AUTHORNAME+":"+BRANDING_AUTHOREMAIL
		};

		dialog.third_party = {
			"Elementary project (various icons):github.com/elementary/icons",
			"Tango project (various icons):tango.freedesktop.org/Tango_Desktop_Project"
		};
		// FIXME - generate from files
		dialog.translators = {
			"Åke Engelbrektson (Swedish):eson@svenskasprakfiler.se",
			"Иннусик (Russian):slavusik1988@gmail.com",
			"Waldemar Konik (Polish):valdi74@github",
			"gogo (Croatian):trebelnik2@gmail.com",
			"Adolfo Jayme Barrientos (Spanish):fitojb@ubuntu.com",
			"yolateng0 (French):github.com/yolateng0",
			"Hugo Posnic (French):hugo.posnic@gmail.com",
			"Faust3000 (Russian):slavusik1988@gmail.com",
			"Gökhan GÖKKAYA (Turkish):gokhanlnx@gmail.com"
		};

		dialog.documenters = null;
		dialog.artists = null;

		dialog.program_name = BRANDING_LONGNAME;
		dialog.comments = _("Kernel upgrade utility for Ubuntu-based distributions");
		dialog.copyright = "Original: \"ukuu\" © 2015-18 Tony George\nForked: \""+BRANDING_SHORTNAME+"\" 2019 "+BRANDING_AUTHORNAME+" ("+BRANDING_AUTHOREMAIL+")";
		dialog.version = BRANDING_VERSION;
		dialog.logo = get_app_icon(128);

		dialog.license = "This program is free for personal and commercial use and comes with absolutely no warranty. You use this program entirely at your own risk. The author will not be liable for any damages arising from the use of this program.";
		dialog.website = BRANDING_WEBSITE;
		dialog.website_label = BRANDING_WEBSITE;

		dialog.initialize();
		dialog.show_all();
	}

	private void refresh_cache(bool download_index = true){

		if (!check_internet_connectivity()){
			gtk_messagebox(_("No Internet"), _("Internet connection is not active"), this, true);
			return;
		}

		if (App.command != "list"){

			// refresh without GUI and return -----------------

			LinuxKernel.query(false);

			while (LinuxKernel.task_is_running) {

				sleep(200);
				gtk_do_events();
			}

			return;
		}

		string message = _("Refreshing...");
		var dlg = new ProgressWindow.with_parent(this, message, true);
		dlg.show_all();
		gtk_do_events();

		// TODO: Check if kernel.ubuntu.com is down

		LinuxKernel.query(false);

		var timer = timer_start();

		App.progress_total = 1;
		App.progress_count = 0;

		string msg_remaining = "";
		long count = 0;

		while (LinuxKernel.task_is_running) {

			if (App.cancelled){
				App.exit_app(1);
			}

			App.status_line = LinuxKernel.status_line;
			App.progress_total = LinuxKernel.progress_total;
			App.progress_count = LinuxKernel.progress_count;

			ulong ms_elapsed = timer_elapsed(timer, false);
			int64 remaining_count = App.progress_total - App.progress_count;
			int64 ms_remaining = (int64)((ms_elapsed * 1.0) / App.progress_count) * remaining_count;

			if ((count % 5) == 0){
				msg_remaining = format_time_left(ms_remaining);
			}

			if (App.progress_total > 0){
				dlg.update_message("%s %s/%s (%s)".printf(message, App.progress_count.to_string(), App.progress_total.to_string(), msg_remaining));
			}

			dlg.update_status_line();

			// FIXME - GTK error messages, and progressbar is always 100%
			//dlg.update_progressbar();

			gtk_do_events();

			dlg.sleep(200);

			count++;
		}

		timer_elapsed(timer, true);

		dlg.destroy();
		gtk_do_events();
	}


	private void init_infobar(){

		// scrolled
		var scrolled = new ScrolledWindow(null, null);
		scrolled.set_shadow_type (ShadowType.ETCHED_IN);
		//scrolled.margin = 6;
		scrolled.margin_top = 0;
		scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
		scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
		vbox_main.add(scrolled);

		// hbox
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		//hbox.margin = 6;
		scrolled.add(hbox);

		var img_status = new Gtk.Image();
		img_status.pixbuf = get_shared_icon_pixbuf("", "tux.svg", 64);
		img_status.margin = 6;
		hbox.add(img_status);

		lbl_info = new Gtk.Label("");
		lbl_info.margin = 6;
		lbl_info.set_use_markup(true);
		hbox.add(lbl_info);
	}

	private void set_infobar(){

		if (LinuxKernel.kernel_active != null){

			lbl_info.label = "Running <b>Linux %s</b>".printf(LinuxKernel.kernel_active.version_main);

			if (LinuxKernel.kernel_active.is_mainline){
				lbl_info.label += " (mainline)";
			}
			else{
				lbl_info.label += " (ubuntu)";
			}

			if (LinuxKernel.kernel_latest_stable.compare_to(LinuxKernel.kernel_active) > 0){
				lbl_info.label += " ~ " + "<b>Linux %s</b> available".printf(
					LinuxKernel.kernel_latest_stable.version_main);
			}
		}
		else{
			lbl_info.label = "Running <b>Linux %s</b>".printf(LinuxKernel.RUNNING_KERNEL);
		}
	}

	public void install(LinuxKernel kern){

		// check if installed
		if (kern.is_installed){
			gtk_messagebox("Already Installed", _("This kernel is already installed."), this, true);
			return;
		}

		if (!check_internet_connectivity()){
			gtk_messagebox(_("No Internet"), _("Internet connection is not active"), this, true);
			return;
		}

		this.hide();

		var term = new TerminalWindow.with_parent(this, false, true);

		term.script_complete.connect(()=>{
			term.allow_window_close();
		});

		term.destroy.connect(()=>{

			if (App.command == "list"){
				this.present();
				refresh_cache();
				tv_refresh();
			}
			else{
				this.destroy();
				Gtk.main_quit();
				App.exit_app(0);
			}
		});

		string sh = "";
		sh += "pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY ";
		sh += BRANDING_SHORTNAME+" --user "+App.user_login;
		if (LOG_DEBUG){
			sh += " --debug";
		}
		sh += " --install %s\n".printf(kern.name);

		sh += "echo ''\n";
		sh += "echo 'Close window to exit...'\n";

		term.execute_script(save_bash_script_temp(sh));
	}

	private void notify_user(){

		LinuxKernel.check_updates();

		var kern = LinuxKernel.kernel_update_major;

		if ((kern != null) && App.notify_major){

			var title = "Linux v%s Available".printf(kern.version_main);
			var message = "Major update available for installation";

			if (App.notify_bubble){

				OSDNotify.notify_send(title,message,3000,"normal","info");
			}

			if (App.notify_dialog){

				var win = new UpdateNotificationWindow(
					BRANDING_LONGNAME,
					"<span size=\"large\" weight=\"bold\">%s</span>\n\n%s".printf(title, message),
					null,
					kern);

				win.destroy.connect(()=>{
					log_debug("UpdateNotificationWindow destroyed");
					Gtk.main_quit();
				});

				Gtk.main(); // start event loop
			}

			log_msg(title);
			log_msg(message);
			return;
		}

		kern = LinuxKernel.kernel_update_minor;

		if ((kern != null) && App.notify_minor){

			var title = "Linux v%s Available".printf(kern.version_main);
			var message = "Minor update available for installation";

			if (App.notify_bubble){

				OSDNotify.notify_send(title,message,3000,"normal","info");
			}

			if (App.notify_dialog){

				var win = new UpdateNotificationWindow(
					BRANDING_LONGNAME,
					"<span size=\"large\" weight=\"bold\">%s</span>\n\n%s".printf(title, message),
					this,
					kern);

				win.destroy.connect(()=>{
					log_debug("UpdateNotificationWindow destroyed");
					Gtk.main_quit();
				});

				Gtk.main(); // start event loop
			}

			log_msg(title);
			log_msg(message);
			return;
		}

		log_msg(_("No updates found"));
	}
}
