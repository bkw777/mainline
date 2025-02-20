using l_misc;

namespace l_exec {
	public bool uri_open(string s) {
		bool r = true;
		try { AppInfo.launch_default_for_uri(s,null); }
		catch (Error e) { r = false; vprint(_("Unable to launch")+" "+s,1,stderr); }
		return r;
	}

	// blocking exec
	public int exec_sync(string cmd, out string? std_out = null, out string? std_err = null) {
		vprint("exec_sync("+cmd+")",3);
		//if (App.no_mode) return 0;
		int r = 0;
		try { Process.spawn_command_line_sync(cmd, out std_out, out std_err); }
		catch (SpawnError e) { r = 1; vprint(e.message,1,stderr); }
		return r;
	}

	// non-blocking exec
	public void exec_async(string cmd) {
		vprint("exec_async("+cmd+")",3);
		//if (App.no_mode) return;
		try { Process.spawn_command_line_async(cmd); }
		catch (SpawnError e) { vprint(e.message,1,stderr); }
	}
}
