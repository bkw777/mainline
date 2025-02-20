/*
 * TerminalWindow.vala
 *
 * Copyright 2015 Tony George <teejee2008@gmail.com>
 * 2023 Brian K. White
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

using l.misc;

public class TerminalWindow : Gtk.Window {

	const double FONT_SCALE_MIN = 0.25;
	const double FONT_SCALE_MAX = 4.0;
	const double FONT_SCALE_STEP = 0.125; // exactly expressable with type double keeps the math results neat

	Vte.Terminal term;
	Pid child_pid = -1;
	Gtk.Window parent_win = null;
	Gtk.Button btn_close;
	Gtk.Button btn_cancel;

	public bool cancelled = false;
	public bool is_running = false;

	public signal void cmd_complete();

	public TerminalWindow.with_parent(Gtk.Window? parent) {
		if (parent != null) {
			set_transient_for(parent);
			parent_win = parent;
			window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
		}

		init_window();
		show_all();
		allow_close(false);
	}

	public bool cancel_window_close() { return true; }

	public void init_window() {
		set_modal(true);

		set_default_size(App.term_width,App.term_height);
		if (App.term_x>=0 && App.term_y>=0) move(App.term_x,App.term_y);

		title = BRANDING_LONGNAME;

		// vbox_main ---------------

		var vbox_main = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		add(vbox_main);

		// terminal ----------------------

		term = new Vte.Terminal();
		term.expand = true;
		term.font_scale = App.term_font_scale;

		var display = term.get_display();
		var clipboard = Gtk.Clipboard.get_for_display(display, Gdk.SELECTION_CLIPBOARD);

		var scroll_win = new Gtk.ScrolledWindow(null, null);
		scroll_win.set_shadow_type (Gtk.ShadowType.ETCHED_IN);
		scroll_win.add(term);
		scroll_win.expand = true;
		scroll_win.hscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		scroll_win.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
		vbox_main.add(scroll_win);

		term.input_enabled = true;
		term.backspace_binding = Vte.EraseBinding.AUTO;
		term.cursor_blink_mode = Vte.CursorBlinkMode.SYSTEM;
		term.cursor_shape = Vte.CursorShape.UNDERLINE;

		term.scroll_on_keystroke = true;
		term.scroll_on_output = true;
		term.scrollback_lines = -1;

#if VALA_0_50
		// rude blasting away the clipboard instead of using a context menu
		term.selection_changed.connect(() => { term.copy_clipboard_format(Vte.Format.TEXT); });
#endif

		// ctrl+scroll to zoom font size
		term.scroll_event.connect((event) => {
			if ((event.state & Gdk.ModifierType.CONTROL_MASK) > 0) {
				int d = 0;
				if (event.direction == Gdk.ScrollDirection.UP) d = 1;
				if (event.direction == Gdk.ScrollDirection.DOWN) d = -1;
				if (event.direction == Gdk.ScrollDirection.SMOOTH) d = (int)event.delta_y;
				if (d>0) dec_font_scale();
				if (d<0) inc_font_scale();
				return Gdk.EVENT_STOP;
			}
			return Gdk.EVENT_PROPAGATE;
		});

		// colors -----------------------------
		//var color = Gdk.RGBA();
		//color.parse("#FFFFFF");
		//term.set_color_foreground(color);
		//color.parse("#404040");
		//term.set_color_background(color);

		term.grab_focus();

		// Bottom bar buttons

		var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		hbox.homogeneous = true;
		vbox_main.add(hbox);

		// copy the entire output & scrollback to clipboard
		var btn_copy = new Gtk.Button.with_label(_("Copy"));
		btn_copy.clicked.connect(()=>{
			long output_end_col, output_end_row;
			term.get_cursor_position(out output_end_col, out output_end_row);
#if VTE_0_72
			string? buf = term.get_text_range_format(TEXT,0,0,output_end_row,-1,null);
#else
			string? buf = term.get_text_range(0, 0, output_end_row, -1, null, null);
#endif
			clipboard.set_text(buf,-1);
			AppGtk.alert(this, "copied "+output_end_row.to_string()+" lines to clipboard");
		});
		btn_copy.set_tooltip_text(_("Copies the entire output buffer, including scrollback, to the clipboard."));
		hbox.pack_start(btn_copy, true, true, 0);

		var label = new Gtk.Label("");
		hbox.pack_start(label, true, true, 0);

		// btn_cancel
		btn_cancel = new Gtk.Button.with_label(_("Cancel"));
		btn_cancel.clicked.connect(()=>{
			cancelled = true;
			if (child_pid>1) Posix.kill(child_pid,SIG.HUP);
		});
		hbox.pack_start(btn_cancel, true, true, 0);

		// btn_close
		btn_close = new Gtk.Button.with_label(_("Close"));
		btn_close.clicked.connect(()=>{
			get_size(out App.term_width, out App.term_height);
			get_position(out App.term_x, out App.term_y);
			App.term_font_scale = term.font_scale;
			destroy();
		});
		hbox.pack_start(btn_close, true, true, 0);

		label = new Gtk.Label("");
		hbox.pack_start(label, true, true, 0);

		// font +/-
		// box within box to make these buttons together take the same space as one of the other buttons.
		var fhbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
		//
		var btn_minus = new Gtk.Button.with_label("-");
		btn_minus.clicked.connect(dec_font_scale);
		fhbox.pack_start(btn_minus, true, true, 0);
		//
		var btn_zero = new Gtk.Button.with_label("0");
		btn_zero.clicked.connect(() => { term.font_scale = 1; });
		fhbox.pack_start(btn_zero, true, true, 0);
		//
		var btn_plus = new Gtk.Button.with_label("+");
		btn_plus.clicked.connect(inc_font_scale);
		fhbox.pack_start(btn_plus, true, true, 0);
		//
		hbox.pack_start(fhbox, true, true, 0);

	}

	public void inc_font_scale() {
		term.font_scale = (term.font_scale + FONT_SCALE_STEP).clamp(FONT_SCALE_MIN, FONT_SCALE_MAX);
	}

	public void dec_font_scale() {
		term.font_scale = (term.font_scale - FONT_SCALE_STEP).clamp(FONT_SCALE_MIN, FONT_SCALE_MAX);
	}

	void spawn_cb(Vte.Terminal t, Pid p, Error? e) {
		vprint("child_pid="+p.to_string(),4);
		if (p>1) child_pid = p;
		else child_has_exited(e.code);
		if (e!=null) term.feed((uint8[])e.message);
	}

	public void execute_cmd(string[] argv) {
		vprint("TerminalWindow execute_cmd("+string.joinv(" ",argv)+")",3);
		cmd_complete.connect(()=>{ present(); allow_close(true); });
		term.child_exited.connect(child_has_exited);
		is_running = true;
#if VALA_0_50 // vte 0.66 or so
		term.spawn_async(
			Vte.PtyFlags.DEFAULT,        // pty_flags
			null,                        // working directory
			argv,                        // argv
			null,                        // env
			GLib.SpawnFlags.SEARCH_PATH, // spawn flags
			null,                        // child_setup()
			-1,                          // timeout
			null,                        // cancellable
			spawn_cb                     // spawn callback
		);
#else
		Pid p = -1; Error e = null;
		try {
			term.spawn_sync(
				Vte.PtyFlags.DEFAULT,        // pty flags
				null,                        // working directory
				argv,                        // argv
				null,                        // env
				GLib.SpawnFlags.SEARCH_PATH, // spawn flags
				null,                        // child_setup()
				out p,                       // child pid out
				null                         // cancellable
			);
		} catch (Error _e) { e = _e; }
		spawn_cb(term,p,e);
#endif
	}

	public void child_has_exited(int status) {
		vprint("TerminalWindow child_has_exited("+status.to_string()+")",3);
		is_running = false;
		cmd_complete();
	}

	public void allow_close(bool allow) {
		if (allow) delete_event.disconnect(cancel_window_close);
		else delete_event.connect(cancel_window_close);
		deletable = allow;
		btn_close.sensitive = allow;
		btn_close.visible = allow;
		btn_cancel.sensitive = !allow;
		btn_cancel.visible = !allow;
	}

}
