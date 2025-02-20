
using l_misc;
using l_exec;

public class Package : GLib.Object {
	public string name;
	public string vers;
	public string arch;
	public bool is_installed = false;
	public static Gee.ArrayList<Package> dpkg_list = new Gee.ArrayList<Package>();

	public static void initialize() {
		new Package();
	}

	public Package(string nm="", string vs="", string ar="") {
		vprint("Package("+nm+","+vs+","+ar+")",4);
		name = nm;
		vers = vs;
		arch = ar;
	}

	// get installed packages from dpkg
	public static void mk_dpkg_list() {
		vprint("mk_dpkg_list()",3);
		dpkg_list.clear();
		string std_out, std_err;
		exec_sync("dpkg-query -f '${Package}|${Version}|${Architecture}|${db:Status-Abbrev}\n' -W 'linux-image-*' 'linux-modules-*' 'linux-headers-*'", out std_out, out std_err);
		if (std_out!=null) foreach (var row in std_out.split("\n")) {
			var x = row.split("|");
			if (x.length != 4) continue;
			if (x[3].substring(1,1) == "n" ) continue;
			//var ar = x[2].strip() if (ar != LinuxKernel.NATIVE_ARCH && ar != "all" && ar != "any") continue;
			dpkg_list.add(new Package(x[0].strip(),x[1].strip(),x[2].strip()));
		}
		if (dpkg_list.size<1) vprint(_("!!! Error running %s").printf("dpkg-query")+": \n"+std_err,1,stderr);
	}
}
