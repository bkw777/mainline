/*
 * OneClickSettingsDialog.vala
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

public class SettingsDialog : Gtk.Dialog {

	private Gtk.CheckButton chk_notify_major;
	private Gtk.CheckButton chk_notify_minor;
	private Gtk.CheckButton chk_notify_bubble;
	private Gtk.CheckButton chk_notify_dialog;
	private Gtk.CheckButton chk_hide_unstable;
	private Gtk.CheckButton chk_hide_older;
	private Gtk.CheckButton chk_hide_older5;
		
	public SettingsDialog.with_parent(Window parent) {
		set_transient_for(parent);
		set_modal(true);
		set_skip_taskbar_hint(true);
		set_skip_pager_hint(true);
		window_position = WindowPosition.CENTER_ON_PARENT;
		deletable = false;
		resizable = false;
		
		icon = get_app_icon(16,".svg");

		title = _("Settings");
		
		// get content area
		var vbox_main = get_content_area();
		vbox_main.spacing = 6;
		vbox_main.margin = 12;
		//vbox_main.margin_bottom = 12;
		vbox_main.set_size_request(400,500);

		// notification
		var label = new Label("<b>" + _("Notification") + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_bottom = 6;
		vbox_main.add (label);
		
		// chk_notify_major
		var chk = new Gtk.CheckButton.with_label(_("Notify if a major release is available"));
		chk.active = App.notify_major;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_notify_major = chk;

		chk.toggled.connect(()=>{
			App.notify_major = chk_notify_major.active;
		});
		
		// chk_notify_minor
		chk = new Gtk.CheckButton.with_label(_("Notify if a point release is available"));
		chk.active = App.notify_minor;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_notify_minor = chk;
		
		chk.toggled.connect(()=>{
			App.notify_minor = chk_notify_minor.active;
		});

		// show bubble
		chk = new Gtk.CheckButton.with_label(_("Show notification bubble on desktop"));
		chk.active = App.notify_bubble;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_notify_bubble = chk;

		chk.toggled.connect(()=>{
			App.notify_bubble = chk_notify_bubble.active;
		});
		
		// show window
		chk = new Gtk.CheckButton.with_label(_("Show notification dialog"));
		chk.active = App.notify_dialog;
		chk.margin_start = 6;
		chk.margin_bottom = 6;
		vbox_main.add(chk);
		chk_notify_dialog = chk;
		
		chk.toggled.connect(()=>{
			App.notify_dialog = chk_notify_dialog.active;
		});

		// notification interval
		var hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add (hbox);
		
		label = new Label(_("Check every"));
		label.xalign = (float) 0.0;
		label.margin_start = 6;
		hbox.add (label);

		var adjustment = new Gtk.Adjustment(App.notify_interval_value, 1, 52, 1, 1, 0);
		var spin = new Gtk.SpinButton (adjustment, 1, 0);
		spin.xalign = (float) 0.5;
		hbox.add(spin);
		var spin_notify = spin;
		
		spin.changed.connect(()=>{
			App.notify_interval_value = (int) spin_notify.get_value();
		});

		// combo
		var combo = new Gtk.ComboBox();
		var cell_text = new Gtk.CellRendererText();
        combo.pack_start(cell_text, false);
        combo.set_attributes(cell_text, "text", 0);
        hbox.add(combo);

        combo.changed.connect(()=>{
			App.notify_interval_unit = combo.active;
			//log_debug("combo: %lf".printf(combo.active));
		});

        //populate
        TreeIter iter;
		var model = new Gtk.ListStore (2, typeof (string), typeof (string));
		model.append (out iter);
		model.set (iter,0,_("Hour(s)"),1,"hour");
		model.append (out iter);
		model.set (iter,0,_("Day(s)"),1,"day");
		model.append (out iter);
		model.set (iter,0,_("Week(s)"),1,"week");
		combo.set_model(model);
		combo.set_active(App.notify_interval_unit);
		
		// display
		label = new Label("<b>" + _("Display") + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_top = 12;
		label.margin_bottom = 6;
		vbox_main.add (label);

		// chk_hide_unstable
		chk = new CheckButton.with_label(_("Hide unstable and RC releases"));
		chk.active = LinuxKernel.hide_unstable;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_hide_unstable = chk;
		
		chk.toggled.connect(()=>{
			LinuxKernel.hide_unstable = chk_hide_unstable.active;
		});

		// chk_hide_older5
		chk = new CheckButton.with_label(_("Hide kernels older than 5.0"));
		chk.active = LinuxKernel.hide_older5;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_hide_older5 = chk;
		
		chk.toggled.connect(()=>{
			LinuxKernel.hide_older5 = chk_hide_older5.active;
		});

		// chk_hide_older
		chk = new CheckButton.with_label(_("Hide kernels older than 4.0"));
		chk.active = LinuxKernel.hide_older;
		chk.margin_start = 6;
		vbox_main.add(chk);
		chk_hide_older = chk;
		
		chk.toggled.connect(()=>{
			LinuxKernel.hide_older = chk_hide_older.active;
		});
		
		// other
		label = new Label("<b>" + _("Other") + "</b>");
		label.set_use_markup(true);
		label.xalign = (float) 0.0;
		label.margin_top = 12;
		label.margin_bottom = 6;
		vbox_main.add (label);

        // skip internet connection check
		chk = new CheckButton.with_label(_("Skip internet connection check"));
		chk.active = App.skip_connection_check;
		chk.margin_start = 6;
		vbox_main.add(chk);

		chk.toggled.connect(()=>{
			App.skip_connection_check = chk.active;
		});

        // timeout value
		hbox = new Gtk.Box(Orientation.HORIZONTAL, 6);
		vbox_main.add (hbox);

		label = new Label(_("Internet connection timeout in "));
		label.xalign = (float) 0.0;
		label.margin_start = 6;
		hbox.add (label);

		adjustment = new Gtk.Adjustment(App.connection_timeout_seconds, 1, 20, 1, 1, 0);
		spin = new Gtk.SpinButton (adjustment, 1, 0);
		spin.xalign = (float) 0.5;
		hbox.add(spin);

		spin.changed.connect(()=>{
			App.connection_timeout_seconds = (int) spin.get_value();
		});

		label = new Label(_("seconds"));
        hbox.add(label);

		// actions -------------------------
		
		// ok
        var button = (Button) add_button ("gtk-ok", Gtk.ResponseType.ACCEPT);
        button.clicked.connect(()=>{
			this.close();
		});

		this.destroy.connect(btn_ok_click);
		
        show_all();
	}

	private void btn_ok_click(){
		App.save_app_config();
	}
}
