
using l_misc;
using l_exec;

public class LinuxKernel : GLib.Object, Gee.Comparable<LinuxKernel> {

	public string version = "";      // display version without _flavor
	public string flavor = "";       // generic, lowlatency, lpae, etc
	public string name = "";         // dpkg name
	public string vers = "";         // dpkg version
	public string version_main = ""; // display version with _flavor
	public string page_uri = "";
	public string notes = "";

	public int version_major = -1;
	public int version_minor = -1;
	public int version_micro = -1;
	public int version_rc = -1;
	public string version_extra = "";
	public string version_sort = "";

	public Gee.HashMap<string,string> deb_url_list = new Gee.HashMap<string,string>(); // assosciated .deb files K=filename,V=url
	public Gee.HashMap<string,string> deb_checksum_list = new Gee.HashMap<string,string>(); // assosciated .deb files K=filename,V=checksum
	public string[] pkg_list = {}; // assosciated dpkg package names

	public int PPA_DIRS_VER = 0; // 0 = not set, 1 = old single dirs, 2 = new /<arch>/ subdirs
	public string CACHE_KDIR;
	public string CACHED_PAGE;
	public string CHECKSUMS_FILE;
	public string CHECKSUMS_URI;
	public string INVALID_FILE;

	public string DATA_KDIR;
	public string NOTES_FILE;
	public string LOCKED_FILE;

	public bool is_invalid = false;
	public bool is_locked = false;
	public bool is_installed = false;
	public bool is_running = false;
	public bool is_mainline = true;
	public bool is_unstable = false;
	public int64 ppa_datetime = -1; // timestamp from the main index
	public string status = ""; // Running, Installed, Invalid, for display only

	// static
	public static string NATIVE_ARCH;
	public static string LINUX_DISTRO;
	public static string RUNNING_KERNEL;
	public static int THRESHOLD_MAJOR = -1;

	public static string MAIN_INDEX_FILE;

	public static LinuxKernel kernel_active;
	public static LinuxKernel kernel_update_major;
	public static LinuxKernel kernel_update_minor;
	public static LinuxKernel kernel_latest_available;
	public static LinuxKernel kernel_latest_installed;
	public static LinuxKernel kernel_oldest_installed;
	public static LinuxKernel kernel_last_stable_ppa_dirs_v1;
	public static LinuxKernel kernel_last_unstable_ppa_dirs_v1;
	//public static LinuxKernel kernel_last_stable_ppa_dirs_v2; // add more if the site changes again
	//public static LinuxKernel kernel_last_unstable_ppa_dirs_v2;

	public static Gee.ArrayList<LinuxKernel> kernel_list = new Gee.ArrayList<LinuxKernel>();
	public static Gee.ArrayList<LinuxKernel> kall = new Gee.ArrayList<LinuxKernel>();

	public static Regex rex_pageuri = null;
	public static Regex rex_datetime = null;
	public static Regex rex_fileuri = null;
	public static Regex rex_header = null;
	public static Regex rex_header_all = null;
	public static Regex rex_image = null;
	public static Regex rex_image_extra = null;
	public static Regex rex_modules = null;

	// constructor
	public LinuxKernel(string v="",string f="generic") {
		vprint("LinuxKernel("+v+","+f+")",4);

		version = v;
		flavor = f;

		split_version_string();
		version_main = version;
		if (flavor!="generic") version_main+="_"+flavor;

		// for cache dir, strip off "_flavor"
		CACHE_KDIR = Main.CACHE_DIR+"/"+version;
		CACHED_PAGE = CACHE_KDIR+"/index.html";
		CHECKSUMS_FILE = CACHE_KDIR+"/CHECKSUMS";
		INVALID_FILE = CACHE_KDIR+"/invalid";

		// for data dir, do not strip off "_flavor"
		DATA_KDIR = Main.DATA_DIR+"/"+version_main;
		NOTES_FILE = DATA_KDIR+"/notes";
		LOCKED_FILE = DATA_KDIR+"/locked";
	}

	// wrap kernel_list.add(k) to avoid doing some work unless we're actually going to use it
	public void kernel_list_add() {
		vprint("kernel_list_add("+this.version_main+")",4);

		PPA_DIRS_VER = ppa_dirs_ver();
		CHECKSUMS_URI = checksums_uri();
		if (exists(NOTES_FILE)) notes = fread(NOTES_FILE).strip();
		is_invalid = exists(INVALID_FILE);
		is_locked = exists(LOCKED_FILE);
		set_status();

		kernel_list.add(this);
	}

	// class initialize
	public static void initialize() {
		vprint("LinuxKernel initialize()",3);
		new LinuxKernel(); // instance must be created before setting static members

		MAIN_INDEX_FILE = Main.CACHE_DIR+"/index.html";

		LINUX_DISTRO = check_distribution();
		NATIVE_ARCH = check_package_architecture();
		RUNNING_KERNEL = check_running_kernel();
		initialize_regex();

		kernel_active = new LinuxKernel(RUNNING_KERNEL);
		kernel_latest_installed = kernel_active;
		kernel_oldest_installed = kernel_active;
		kernel_latest_available = kernel_active;
		kernel_update_major = kernel_active;
		kernel_update_minor = kernel_active;

		// Special threshold kernel versions where the mainline-ppa site changed their directory structure.
		// ppa_dirs_ver=1       ppa_dirs_ver=2
		// ./foo.deb       vs   ./<arch>/foo.deb
		// ./CHECKSUMS     vs   ./<arch>/CHECKSUMS
		// ./BUILT         vs   ./<arch>/status
		kernel_last_stable_ppa_dirs_v1 = new LinuxKernel("5.6.17");
		kernel_last_unstable_ppa_dirs_v1 = new LinuxKernel("5.7-rc7");
		//kernel_last_stable_ppa_dirs_v2 = new LinuxKernel("x.y.z"); // if the site changes again
		//kernel_last_unstable_ppa_dirs_v2 = new LinuxKernel("x.y-rcZ");
	}

	// dep: lsb_release
	public static string check_distribution() {
		vprint("check_distribution()",3);
		string dist = "";

		string std_out, std_err;
		int e = exec_sync("lsb_release -sd", out std_out, out std_err);
		if ((e == 0) && (std_out != null)) {
			dist = std_out.strip();
			vprint(_("Distribution")+": "+dist,2);
		}

		return dist;
	}

	// dep: dpkg
	public static string check_package_architecture() {
		vprint("check_package_architecture()",3);
		string arch = "";

		string std_out, std_err;
		int e = exec_sync("dpkg --print-architecture", out std_out, out std_err);
		if ((e == 0) && (std_out != null)) {
			arch = std_out.strip();
			vprint(_("Architecture")+": "+arch,2);
		}

		return arch;
	}

	// dep: uname
	public static string check_running_kernel() {
		vprint("check_running_kernel()",3);
		string ver = "";

		string std_out;
		exec_sync("uname -r", out std_out, null);
		ver = std_out.strip().replace("\n","");

		return ver;
	}

	public static void initialize_regex() {
		vprint("initialize_regex()",3);
		try {

			// uri to a kernel page and it's datetime, in the main index.html
			// <tr><td valign="top"><img src="/icons/folder.gif" alt="[DIR]"></td><td><a href="v2.6.27.61/">v2.6.27.61/</a></td><td align="right">2018-05-13 20:40  </td><td align="right">  - </td><td>&nbsp;</td></tr>
			//                                                                                 ###########                                        #### ## ## ## ##
			//                                                                                 fetch(1)                                           2    3  4  5  6
			rex_pageuri     = new Regex("""href="(v.+/)".+>[\t ]*([0-9]{4})-([0-9]{2})-([0-9]{2})[\t ]+([0-9]{2}):([0-9]{2})[\t ]*<""");

			// date & time for any uri in a per-kernel page
			// <tr><td valign="top"><img src="/icons/text.gif" alt="[TXT]"></td><td><a href="HEADER.html">HEADER.html</a></td><td align="right">2023-05-11 23:21  </td><td align="right">5.6K</td><td>&nbsp;</td></tr>
			// <tr><td valign="top"><img src="/icons/folder.gif" alt="[DIR]"></td><td><a href="amd64/">amd64/</a></td><td align="right">2023-05-11 22:30  </td><td align="right">  - </td><td>&nbsp;</td></tr>
			//                                                                                                                          #### ## ## ## ##
			//                                                                                                                          1    2  3  4  5
			rex_datetime    = new Regex(""">[\t ]*([0-9]{4})-([0-9]{2})-([0-9]{2})[\t ]+([0-9]{2}):([0-9]{2})[\t ]*<""");

			// uri to any .deb file in a per-kernel page
			// <a href="linux-headers-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb">//same deb name//</a>
			//          ############################################################################
			rex_fileuri     = new Regex("""href="(.+\.deb)"""");

			// linux-image-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			//                           ###1###
			rex_image       = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-.+-(.+)_.+_"""       + NATIVE_ARCH + ".deb");

			// linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			//                                 ###1###
			rex_image_extra = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-extra-.+-(.+)_.+_""" + NATIVE_ARCH + ".deb");

			// linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			//                                 ###1###
			rex_modules     = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-modules-.+-(.+)_.+_"""     + NATIVE_ARCH + ".deb");

			// linux-headers-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			//                             ###1###
			rex_header      = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-.+-(.+)_.+_"""     + NATIVE_ARCH + ".deb");

			// linux-headers-3.4.75-030475_3.4.75-030475.201312201255_all.deb
			rex_header_all  = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-.+_all.deb""");

		} catch (Error e) {
			vprint(e.message,1,stderr);
		}
	}

	static void trim_cache() {
		if (App.keep_cache) return;
		foreach (var k in kall) {
			if (k.is_installed) continue;
			// don't remove anything >= threshold_major even if hidden
			if (k.version_major<THRESHOLD_MAJOR && File.parse_name(k.CACHE_KDIR).query_exists()) rm(k.CACHE_KDIR);
		}
	}

	public static void delete_cache() {
		vprint("delete_cache()",3);
		kernel_list.clear();
		kall.clear();
		rm(Main.CACHE_DIR);
	}

	public void set_invalid(bool b) {
		if (b) fwrite(INVALID_FILE,"");
		else rm(INVALID_FILE);
		is_invalid = b;
	}

	public void set_locked(bool b) {
		if (b) fwrite(LOCKED_FILE,"");
		else rm(LOCKED_FILE);
		is_locked = b;
	}

	public void set_notes(string s="") {
		if (s.length>0) fwrite(NOTES_FILE,s);
		else rm(NOTES_FILE);
		notes = s;
	}

	public void set_status() {
		status =
			is_running ? _("Running") :
			is_installed ? _("Installed") :
			is_invalid ? _("Invalid") :
			"";
	}

	public delegate void Notifier(bool last = false);

	public static void mk_kernel_list(bool wait = true, owned Notifier? notifier = null) {
		vprint("mk_kernel_list()",3);
		try {
			var worker = new Thread<bool>.try(null, () => mk_kernel_list_worker((owned)notifier) );
			if (wait) worker.join();
		} catch (Error e) { vprint(e.message,1,stderr); }
	}

	static bool mk_kernel_list_worker(owned Notifier? notifier) {
		vprint("mk_kernel_list_worker()",3);
		if ((!App.gui_mode && !App.index_is_fresh) || Main.VERBOSE>1) vprint("Updating Kernels...");

		kernel_list.clear();
		App.progress_total = 0;
		App.progress_count = 0;
		App.cancelled = false;

		// find the oldest major version to include
		Package.mk_dpkg_list();
		find_thresholds();

		// ===== download the main index.html listing all kernels =====
		download_main_index(); // download the main index.html
		load_main_index();  // scrape the main index.html to make the initial kernel_list

		// ===== download the per-kernel index.html and CHANGES =====

		// list of kernels - one LinuxKernel object per kernel to update
		var kernels_to_update = new Gee.ArrayList<LinuxKernel>();
		// list of files - one DownloadItem object per individual file to download
		var downloads = new Gee.ArrayList<DownloadItem>();

		// add files to download list
		vprint(_("loading cached pages"),3);
		foreach (var k in kernel_list) {
			if (App.cancelled) break;

			// skip some kernels for various reasons

			// don't try to skip this kernel by looking at is_invalid yet.
			// is_invalid is cached and might be obsolete

			// try to load cached info for this kernel
			if (k.load_cached_page()) continue;

			// now we can consider is_invalid
			// an invalid kernel might be installed, but that would have to
			// be a distro kernel or self-compiled, not a mainline-ppa one,
			// so it's ok to filter out an invalid mainline-ppa one here
			if (k.is_invalid && App.hide_invalid) continue;

			// there may be installed rc kernels even if rc are currently disabled
			// so don't try to filter out rc kernels yet

			// we have either not found a cached page,
			// or found it to be out of date and deleted it,
			// and have not skipped this kernel due to is_invalid

			// add index.html to download list
			vprint(_("queuing download")+" "+k.version_main,3);
			downloads.add(new DownloadItem(k.page_uri,Path.get_dirname(k.CACHED_PAGE),Path.get_basename(k.CACHED_PAGE)));

			// add kernel to update list
			kernels_to_update.add(k);

			if (notifier != null) notifier();
		}

		// process the download list
		if (downloads.size>0 && App.ppa_up) {

			// download the indexes
			vprint(_("downloading new pages"),3);
			App.progress_total = downloads.size;
			var mgr = new DownloadTask();
			foreach (var item in downloads) mgr.add_to_queue(item);
			mgr.execute();
			while (mgr.is_running) {
				App.progress_count = mgr.prg_count;
				pbar(App.progress_count,App.progress_total);
				Thread.usleep(250000);
				if (notifier != null) notifier();
			}
			pbar(0,0);

			// load the indexes
			vprint(_("loading new pages"),3);
			foreach (var k in kernels_to_update) {
				k.load_cached_page();
				k.set_status();
			}
			if (notifier != null) notifier();

		}

		check_installed();
		trim_cache();
		check_updates();

		// print summary
		if (Main.VERBOSE>1) {
			vprint(_("Currently Running")+": "+kernel_active.version_main);
			vprint(_("Oldest Installed")+": "+kernel_oldest_installed.version_main);
			vprint(_("Newest Installed")+": "+kernel_latest_installed.version_main);
			vprint(_("Newest Available")+": "+kernel_latest_available.version_main);
			if (kernel_update_minor!=null) vprint(_("Available Minor Update")+": "+kernel_update_minor.version_main);
			if (kernel_update_major!=null) vprint(_("Available Major Update")+": "+kernel_update_major.version_main);
		}

		// This is here because it had to be delayed from whenever settings
		// changed until now, so that the notify script instance of ourself
		// doesn't do it's own mk_kernel_list() at the same time while we still are.
		App.run_notify_script_if_due();

		if (notifier != null) notifier(true);
		return true;
	}

	// download the main index.html listing all mainline kernels
	static bool download_main_index() {
		vprint("download_main_index()",3);

		if (!exists(MAIN_INDEX_FILE)) App.index_is_fresh=false;
		if (App.index_is_fresh) return true;
		if (!App.try_ppa()) return false;

		mkdir(Main.CACHE_DIR);

		// preserve the old index in case the dl fails
		string tbn = "%8.8X".printf(Main.rnd.next_int());
		string tfn = Main.CACHE_DIR+"/"+tbn;
		vprint("+ DownloadItem("+App.ppa_uri+","+Main.CACHE_DIR+","+tbn+")",4);
		var item = new DownloadItem(App.ppa_uri, Main.CACHE_DIR, tbn);
		var mgr = new DownloadTask();
		mgr.add_to_queue(item);

		mgr.execute();
		while (mgr.is_running) Thread.usleep(250000);

		if (exists(tfn)) {
			FileUtils.rename(tfn,MAIN_INDEX_FILE);
			App.index_is_fresh=true;
			vprint(_("OK"),3);
			return true;
		} else {
			vprint(_("FAILED"),1,stderr);
			return false;
		}
	}

	// read the main index.html listing all kernels
	static void load_main_index() {
		vprint("load_main_index()",3);
		if (THRESHOLD_MAJOR<0) { vprint("load_index(): MISSING THRESHOLD_MAJOR"); exit(1); }

		if (!exists(MAIN_INDEX_FILE)) return;
		string txt = fread(MAIN_INDEX_FILE);
		kernel_list.clear();
		kall.clear();

		MatchInfo mi;
		foreach (string l in txt.split("\n")) {
			if (!rex_pageuri.match(l, 0, out mi)) continue;
			var v = mi.fetch(1);
			var k = new LinuxKernel(v);

			// Don't try to exclude unstable here, just k.version_major<THRESHOLD_MAJOR.
			// They all need to exist in kernel_list at least long enough for check_installed()
			// to recognize any already-installed even if they would otherwise be hidden.

			k.page_uri = App.ppa_uri + v;
			k.is_mainline = true;
			if (k.version_major>=THRESHOLD_MAJOR) {
				k.ppa_datetime = int64.parse(mi.fetch(2)+mi.fetch(3)+mi.fetch(4)+mi.fetch(5)+mi.fetch(6));
				k.kernel_list_add(); // the active list
			}
			kall.add(k); // a seperate list with nothing removed, used in trim_cache()
		}

		// sort the list, highest first
		kernel_list.sort((a,b) => { return b.compare_to(a); });

	}

	public static void check_installed() {
		vprint("check_installed()",3);

		//string msg = "";

		if (Package.dpkg_list.size<1) vprint("!!! dpkg_list empty!");
		if (kernel_list.size<1) vprint("!!! kernel_list empty!");

		foreach (var p in Package.dpkg_list) {
			if (!p.name.has_prefix("linux-image-")) continue;
			vprint("\t"+p.name,3);

			// search kernel_list for matching package,
			// fill k.pkg_list with list of associated pkgs
			bool found_mainline = false;
			foreach (var k in kernel_list) {
				if (k.name != p.name) continue;
				found_mainline = true;
				k.is_installed = true;
				//vprint("mainline: n:"+k.name+" v:"+k.vers+" f:"+k.flavor);
				k.set_pkg_list();
				break;
			}

			// installed package was not found in the mainline list
			// add to kernel_list as a distro kernel
			if (!found_mainline) {
				// FIXME - See also load_cached_page() rex_image
				//
				// We have to somehow determine the "flavor" from the information
				// available from dpkg. The flavor is part of p.name, but it's
				// hard to isolate it, because although it is always a suffix
				// seperated by "-", like "-foo", "foo" itself can also contain
				// anything, including "-". "###-generic-64k"  "###-generic-lpae"
				//
				// And the stuff before flavor isn't consistent either. The trailing
				// end of the version component might contain anything, including
				// non-numbers and multiple "." and "-", so there is no regex
				// to tell where the version ends and the flavor begins.
				//
				// You can't count the number of "-" because that is also variable.
				// Both the beginning name component and the version component may contain
				// variable numbers of "-". "linux-image-#..." "linux-image-unsigned-#..."
				//
				// So we are merely splitting on "-" and calling the last field the "flavor".
				//
				// Right now at least the mechanics are working because check_installed()
				// and load_cached_page() are both arriving at the same value for "flavor"
				// for a given kernel, which is then needed by set_pkg_list().
				// As long as it's only used internally as a unique identifier,
				// then it only needs to be unique and reproducible from the different
				// sources of info like dpkg and web pages, not meaningfully correct.
				//
				// The problems are:
				// * It will break if there is ever a flavor named "64k" or
				//   "someother-64k", at the same time with "generic-64k",
				//   in the same arch, in the same base kernel version.
				// * We are displaying this wrong "flavor" value in the kernel
				//   list in the form of the constructed value version_main.
				//
				// Mostly no one sees the problem because the amd64 arch doesn't
				// happen to have any flavors with embedded "-" so far.
				//
				var x = p.name.split("-");
				var k = new LinuxKernel(p.vers,x[x.length-1]);
				k.name = p.name;
				k.vers = p.vers;
				k.is_mainline = false;
				k.is_installed = true;
				//vprint("non-mainline: n:"+k.name+" v:"+k.vers+" f:"+k.flavor);
				k.set_pkg_list();
				k.kernel_list_add();
			}
		}

		// kernel_list contains both mainline and installed distro kernels now
		// find the running kernel
		var s = "-"+RUNNING_KERNEL;
		foreach (var k in kernel_list) {
			if (k.name.has_suffix(s)) {
				k.is_running = true;
				kernel_active = k;
				break;
			}
		}

		// sort, reverse
		kernel_list.sort((a,b) => { return b.compare_to(a); });

		// find the highest & lowest installed versions
		kernel_latest_installed = new LinuxKernel();
		kernel_oldest_installed = kernel_latest_installed;
		foreach(var k in kernel_list) {
			if (k.is_installed) {
				k.set_status();
				if (kernel_latest_installed.version_major==0) kernel_latest_installed = k;
				kernel_oldest_installed = k;
				//msg = _("Found installed")+": "+k.name;
				//if (k.is_locked) msg += " (" + _("locked") +")";
				//if (k.is_running) msg += " (" + _("running") +")";
				//vprint(msg,2);
			}
		}
	}

	// scan kernel_list for versions newer than latest installed
	public static void check_updates() {
		vprint("check_updates()",3);
		kernel_update_major = null;
		kernel_update_minor = null;
		kernel_latest_available = kernel_latest_installed;

		bool major_available = false;
		bool minor_available = false;

		foreach(var k in kernel_list) {
			vprint(k.version_main,3);
			if (k.is_invalid) continue;
			if (k.is_installed) continue;
			if (k.is_locked) continue;
			if (k.is_unstable && App.hide_unstable) continue;
			if (k.version_major < THRESHOLD_MAJOR) break;
			if (k.compare_to(kernel_latest_installed)<1) break;

			// kernel_list is sorted so first match is highest match
			if (k.version_major > kernel_latest_installed.version_major) major_available = true;
			else if (k.version_major == kernel_latest_installed.version_major) {
				if (k.version_minor > kernel_latest_installed.version_minor) major_available = true;
				else if (k.version_minor == kernel_latest_installed.version_minor) {
					if (k.version_micro > kernel_latest_installed.version_micro) minor_available = true;
					else if (k.version_micro == kernel_latest_installed.version_micro) {
						if (k.version_rc > kernel_latest_installed.version_rc) minor_available = true;
					}
				}
			}

			if (major_available && (kernel_update_major == null)) kernel_update_major = k;
			if (minor_available && (kernel_update_minor == null)) kernel_update_minor = k;

			// if we have everything possible, skip the rest
			if (kernel_update_major != null && kernel_update_minor != null) break;
		}

		if (kernel_update_minor != null) kernel_latest_available = kernel_update_minor;
		if (kernel_update_major != null) kernel_latest_available = kernel_update_major;
	}

	// There is a circular dependency here.
	// (1) Ideally we want to know THRESHOLD_MAJOR before running mk_kernel_list(),
	//     so mk_kernel_list() can use it to set bounds on the size of it's job,
	//     instead of processing all kernels since the beginning of time, every time.
	// (2) Ideally we want to use is_mainline while finding THRESHOLD_MAJOR,
	//     to prevent non-mainline kernels from pulling THRESHOLD_MAJOR down.
	// (3) The only way to find out is_mainline for real is to scan kernel_list[],
	//     and see if a given installed package matches one of those.
	// (4) But we don't have kernel_list[] yet, and we can't get it yet, because GOTO (1)
	// 
	// So for this early task, we rely on a weak assumption made previously in
	// split_version_string(), when mk_dpkg_list() generates some kernel objects from
	// the installed package info from dpkg, which is just that if the version
	// has 12 bytes after a ".", then it's an installed mainline package.
	//
	// TODO maybe...
	// Get a full kernel_list from a preliminary pass with load_index() before runing mk_dpkg_list().
	// Have mk_dpkg_list() use that to fill in a real actual is_mainline for each item in dpkg_list[].
	// Use that here, and along the way delete the unwanted items from kernel_list[].
	// Then mk_kernel_list() can just process that kernel_list[].
	//
	static void find_thresholds() {
		vprint("find_thresholds()",3);

		if (Package.dpkg_list.size<1) { vprint("MISSING dpkg_list") ;exit(1); }

		if (App.previous_majors<0 || App.previous_majors>=kernel_latest_available.version_major) { THRESHOLD_MAJOR = 0; return; }

		// start from the latest available and work down, ignore distro kernels
		kernel_oldest_installed = kernel_latest_installed;
		foreach (var p in Package.dpkg_list) {
			if (!p.name.has_prefix("linux-image-")) continue;
			var k = new LinuxKernel(p.vers);
			if (k.version_major < kernel_oldest_installed.version_major && k.is_mainline) kernel_oldest_installed = k;
		}

		THRESHOLD_MAJOR = kernel_latest_available.version_major - App.previous_majors;
		if (kernel_oldest_installed.is_mainline && kernel_oldest_installed.version_major < THRESHOLD_MAJOR) THRESHOLD_MAJOR = kernel_oldest_installed.version_major;
	}

	// two main forms of input string:
	//
	// directory name & display version from the mainline-ppa web site
	// with or without leading "v" and/or trailing "/"
	//    v4.4-rc2+cod1/
	//    v4.2-rc1-unstable/
	//    v4.4.10-xenial/
	//    v4.6-rc2-wily/
	//    v4.2.8-ckt7-wily/
	//    v2.6.27.62/
	//    v4.19.285/
	//    v5.12-rc1-dontuse/
	//    v6.0/         trailing .0 but only one (not "6", nor "6.0.0")
	//    v6.0-rc5/
	//    v6.1/         no trailing .0 (not 6.1.0)
	//    v6.1-rc8/
	//    v6.1.9/
	//
	// version field from dpkg from installed packages
	//    5.19.0-42.43                  distro package
	//    5.4.0-155.172                 distro package
	//    6.3.6-060306.202306050836     mainline package
	//    4.6.0-040600rc1.201603261930  sigh, rc without a delimiter, and "040600" is not always 6 characters
	//
	// We don't actually know is_mainline for sure yet, so at this point we just
	// assume if it has 12 bytes after a ".", it's an installed mainline package.
	//
	// TODO: this should be split into seperate parsers for each type of version string,
	// or maybe seperate modes controlled by a parameter.
	// Ukuu originally did have a 2nd constructor .from_version(), but it didn't actually
	// do anything useful, they still both used the same split_version_string().

	void split_version_string() {
		//vprint("\n-new-: "+s);
		version_major = 0;
		version_minor = 0;
		version_micro = 0;
		version_rc = 0;
		version_extra = "";
		is_mainline = true;
		is_unstable = false;

		string t = version.strip();
		if (t.has_prefix("v")) t = t[1: t.length - 1];
		if (t.has_suffix("/")) t = t[0: t.length - 1];

		if (t==null || t=="") t = "0";
		version = t;

		//vprint("\n"+t);

		var chunks = version.split_set(".-_+~ ");
		int i = 0, n = 0;
		foreach (string chunk in chunks) {
			++i;
			if (chunk.length<1) continue;
			if (chunk.has_prefix("rc")) { version_rc = int.parse(chunk.substring(2)); continue; }
			n = int.parse(chunk);
			if (n>0 || chunk=="0") switch (i) {  // weakness, would still fail on "00"  or "000" etc
				case 1: version_major = n; continue;
				case 2: version_minor = n; continue;
				case 3: version_micro = n; continue;
			}
			if (i>=chunks.length) {
				if (chunk.length==12) continue;
				is_mainline = false;
			} else if (i==chunks.length-1) {
				if (chunk.contains("rc")) { var x = chunk.split("c"); version_rc = int.parse(x[x.length-1]); continue; }
				if (version_micro<100 && chunk.has_prefix("%02d%02d%02d".printf(version_major,version_minor,version_micro))) continue;
				else if (chunk.has_prefix("%02d%02d%d".printf(version_major,version_minor,version_micro))) continue;
			}
			version_extra += "."+chunk;
		}
		version_sort = "%d.%d.%d".printf(version_major,version_minor,version_micro);
		if (version_rc>0) version_sort += ".rc"+version_rc.to_string();
		version_sort += version_extra;

		if (version_rc>0 || version_extra.contains("unstable")) is_unstable = true;
		//vprint("major: %d\nminor: %d\nmicro: %d\nrc   : %d\nextra: %s\nunstable: %s\nsort :%s".printf(version_major,version_minor,version_micro,version_rc,version_extra,is_unstable.to_string(),version_sort));
		//vprint(version_sort);
	}

// complicated comparison logic for kernel versions
// * version_sort is delimited by . so the individual chunks can be numerically compared
//   so 1.2.3-rc4-unstable is 1.2.3.rc4.unstable
// * version_sort has at least the first 3 chunks filled with at least 0
//   so 6 is 6.0.0
// * 1.12.0 is higher than 1.2.0
// * 1.2.3-rc5 is higher than 1.2.3-rc4
// * 1.2.3 is higher than 1.2.3-rc4
// * 1.2.3 is higher than 1.2.3-unstable
// * 1.2.3-rc4 is higher than 1.2.3-rc4-unstable
//
// TODO version_sort is a transitional hack to keep doing the old way of
// parsing version_main, since version_main has a different format now.
// The better way will be to just examine the individual variables
// which we already did the work of parsing in split_version_string()
//
// like strcmp(l,r), but l & r are LinuxKernel objects
// l.compare_to(r)   name & interface to please Gee.Comparable
//  l<r  return -1
//  l==r return 0
//  l>r  return 1
	public int compare_to(LinuxKernel t) {
		if (Main.VERBOSE>4) vprint(version_main+" compare_to() "+t.version_main);
		var a = version_sort.split(".");
		var b = t.version_sort.split(".");
		int x, y, i = -1;
		while (++i<a.length && i<b.length) {            // while both strings have chunks
			if (a[i] == b[i]) continue;                 // both the same, next chunk
			x = int.parse(a[i]); y = int.parse(b[i]);   // parse strings to ints
			if (x>0 && y>0) return (x - y);             // both numeric>0, numeric compare
			if (x==0 && y==0) return strcmp(a[i],b[i]); // neither numeric>0 (alpha or maybe 0), lex compare
			if (x>0) return 1;                          // only left is numeric>0, left is greater
			return -1;                                  // only right is numeric>0, right is greater
		}
		if (i<a.length) { if (int.parse(a[i])>0) return 1; return -1; } // if left is longer { if left is numeric>0, left is greater else right is greater }
		if (i<b.length) { if (int.parse(b[i])>0) return -1; return 1; } // if right is longer { if right is numeric>0, right is greater else left is greater }
		return 0;                                       // left & right identical the whole way
	}

	void set_pkg_list() {
		vprint("set_pkg_list("+version_main+")",3);
		foreach(var p in Package.dpkg_list) {
			//vprint("vers="+vers+"\tp.vers="+p.vers,4);
			// BLARGH!!!!
			// The mainline-ppa site sometimes updates and replaces .deb packages after
			// you've installed them. The new packages have the same base name & version,
			// just with a new later .123456789012 datestamp suffix in the vers field.
			// This breaks us because the 'vers' we get from todays index.html
			// no longer matches the 'p.vers' we get from the installed packages in dpkg.
			//
			// pkg on kernel.ubuntu.com today   installed pkg from kernel.ubuntu.com a week ago
			// vers=6.4.6-060406.202308041557   p.vers=6.4.6-060406.202307241739
			//
			// Until I think of a better way, strip off the .datetime before compare.
			//
			// It's crap. Two builds with only different datetime should be
			// installable and removable side-by-side, but we just have very little
			// reliable way to associate dpkg info with mainline-ppa site info.
			// This code to do the crappy thing is itself also brute force crap, but working,
			// if you can call deliberately ignoring a part of a unique key value "working".
			var tv = vers;
			var pv = p.vers;
			var tvs = tv.split(".");
			var pvs = pv.split(".");
			var tvse = tvs[tvs.length-1];
			var pvse = pvs[pvs.length-1];
			//vprint("tvse="+tvse+"\tpvse="+pvse);
			// if the last part is exactly 12 bytes long, and is all numbers, then strip it off.
			if (tvse.length==12 && uint64.parse(tvse)>0) tv = tv.substring(0,tv.length-13);
			if (pvse.length==12 && uint64.parse(pvse)>0) pv = pv.substring(0,pv.length-13);
			// TODO - if tvse>pvse alert user that the package has been updated on the server.
			// TODO - preserve a copy of cached_page at install-time until the matching
			// packages are uninstalled, so we can track builds seperately like versions,flavors,archs
			//vprint("tv="+tv+"\tpv="+pv);
			if (pv != tv) continue;
			//vprint("\tp.name="+p.name+"\tp.arch="+p.arch+"\tflavor="+flavor);
			if (!p.name.has_suffix("-"+flavor) && p.arch != "all") continue;
			var l = pkg_list;
			l += p.name;
			pkg_list = l;
			vprint("  p: "+p.name,3);
		}
	}

	int ppa_dirs_ver() {
		int v = 1;
		var k = kernel_last_stable_ppa_dirs_v1;                // Which threshold,
		if (is_unstable) k = kernel_last_unstable_ppa_dirs_v1; // stable or unstable?
		if (compare_to(k)>0) v = 2;                 // Do we exceed it?
		// in the future if the ppa site changes again,
		// add more copies of these 3 lines
		//k = kernel_last_stable_ppa_dirs_v2;
		//if (is_unstable) k = kernel_last_unstable_ppa_dirs_v2;
		//if (compare_to(k)>0) v = 3;
		return v;
	}

	string checksums_uri() {
		switch (PPA_DIRS_VER) {
			case 1: return page_uri+"CHECKSUMS";
			//case 2: return page_uri+NATIVE_ARCH+"/CHECKSUMS";
			default: return page_uri+NATIVE_ARCH+"/CHECKSUMS";
		}
	}

	public string tooltip_text() {
		string txt = "";

		// available packages
		string list = "";
		foreach (var x in deb_url_list.keys) list += "\n"+x;
		if (list.length > 0) txt += "<b>"+_("Packages Available")+"</b>"+list;

		// installed packages
		list = "";
		foreach (var x in pkg_list) list += "\n"+x;
		if (list.length > 0) {
			if (txt.length > 0) txt += "\n\n";
			txt += "<b>"+_("Packages Installed")+"</b>"+list;
		}

		// user notes
		if (notes.length > 0) {
			if (txt.length > 0) txt += "\n\n";
			txt += "<b>"+_("Notes")+"</b>\n"+notes;
		}

		// other
		if (is_locked) {
			if (txt.length > 0) txt += "\n\n";
			txt += "<b>"+_("Locked")+"</b>\n";
			if (is_installed) txt += _("removal"); else txt += _("installation");
			txt += " " + _("prevented");
		}

		return txt;
	}

	// return false if we don't have the cached page
	//   or if it's older than its timestamp in the main index.html
	// return true if we have a valid cached page,
	//   whether the kernel itself is a valid build or not
	bool load_cached_page() {
		vprint("load_cached_page("+CACHED_PAGE+")",4);
		name = "";
		vers = "";
		deb_url_list.clear();
		if (!exists(CACHED_PAGE)) { vprint(_("not found"),4); return false; }

		string txt = "";
		int64 d_this = 0;
		int64 d_max = 0;
		MatchInfo mi;
		var _url_list = new Gee.HashMap<string,string>(); // local temp deb_url_list
		var _flavors = new Gee.HashMap<string,string>(); // flavors[flavor]=name
		string? _flavor;
		string? _name;
		string? _vers;

		// read cached page
		txt = fread(CACHED_PAGE);

		// detect and delete out-of-date cache
		//
		// find the latest timestamp anywhere in the cached page
		foreach (string l in txt.split("\n")) {
			if (rex_datetime.match(l, 0, out mi)) {
				d_this = int64.parse(mi.fetch(1)+mi.fetch(2)+mi.fetch(3)+mi.fetch(4)+mi.fetch(5));
				if (d_this>d_max) d_max = d_this;
			}
		}
		// if this kernel's timestamp from the main index is later than the latest in this
		// kernel's cached page, then delete the cache for this kernel and return false.
		if (ppa_datetime>d_max) {
			vprint(version_main+": ppa:"+ppa_datetime.to_string()+" > cache:"+d_max.to_string()+" : "+_("needs update"),2);
			rm(CACHE_KDIR);
			return false;
		}

		// skip the rest of the work if we already know it's a failed build
		if (is_invalid) return true;

		// scan for urls to .deb files
		foreach (string l in txt.split("\n")) {
			if (!rex_fileuri.match(l, 0, out mi)) continue;
			string file_uri = page_uri + mi.fetch(1);
			string file_name = Path.get_basename(file_uri);
			if (_url_list.has_key(file_name)) continue;

			_name = null;
			_vers = null;
			_flavor = null;
			if (rex_image.match(file_name, 0, out mi)) {
				// linux-image-*.deb also defines !is_invalid and flavor

				// TODO FIXME
				// some kernels have multiple builds
				// amd64/linux-image-unsigned-5.16.0-051600-generic_5.16.0-051600.202201091830_amd64.deb
				// amd64/linux-image-unsigned-5.16.0-051600-generic_5.16.0-051600.202201092355_amd64.deb
				// We are not handling that at all. We end up creating a single LinuxKernel
				// for "5.16" with a deb_url_list that has two full sets of files

				//  linux-image-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb
				// |                           |flavor-|                            |
				// |----------------name---------------|------------vers------------|
				//
				//  linux-image-unsigned-6.4.3-060403-generic-64k_6.4.3-060403.202307110536_arm64.deb
				// |                                 |--flavor---|                         |
				// |---------------------name--------------------|----------vers-----------|
				var x = file_name.split("_");
				_name = x[0];
				_vers = x[1];
				_flavor = mi.fetch(1);
				if (_flavor==null) _flavor = "generic"; // ensure !null but never actually happens
				if (_flavor=="generic") {
					name = _name;
					vers = _vers;
				}
				_flavors[_flavor] = _name;

			} else if (rex_image_extra.match(file_name, 0, out mi)) {
			} else if (rex_modules.match(file_name, 0, out mi)) {
			} else if (rex_header.match(file_name, 0, out mi)) {
			} else if (rex_header_all.match(file_name, 0, out mi)) {
			} else file_name = "";

			// if we matched a file of any kind, add it to the url list
			if (file_name.length>0) _url_list[file_name] = file_uri;

		}

		if (name.length<1) set_invalid(true);

		// create a new LinuxKernel for each detected flavor
		foreach (var flv in _flavors.keys) {
			LinuxKernel k;
			if (flv!="generic") {
				k = new LinuxKernel(version_main,flv);
				k.is_mainline = is_mainline;
				k.page_uri = page_uri;
				k.name = _flavors[flv];
				k.vers = vers;
			} else {
				k = this;
			}
			k.deb_url_list.clear();
			foreach (var f in _url_list.keys) {
				if (f.split("_")[0].has_suffix("-"+flv) || f.has_suffix("_all.deb")) k.deb_url_list[f] = _url_list[f];
			}
			if (k != this) k.kernel_list_add();
			//vprint(k.version_main+"\t"+k.name+"\t"+k.vers);
			//foreach (var f in k.deb_url_list.keys) vprint("  "+f);
		}

		return true;
	}

	// actions

	public static void print_list() {
		vprint("----------------------------------------------------------------");
		vprint(_("Available Kernels"));
		vprint("----------------------------------------------------------------");

		foreach(var k in kernel_list) {

			// apply filters, but don't hide any installed
			if (!k.is_installed) {
				if (k.is_invalid && App.hide_invalid) continue;
				if (k.is_unstable && App.hide_unstable) continue;
				if (k.flavor!="generic" && App.hide_flavors) continue;
			}

			vprint("%-12s %2s %-10s %s".printf(k.version_main, (k.is_locked)?"🔒":"", k.status, k.notes));
		}
	}

	public static Gee.ArrayList<LinuxKernel> vlist_to_klist(string list="") {
		vprint("vlist_to_klist("+list+")",3);
		var klist = new Gee.ArrayList<LinuxKernel>();
		var vlist = list.split_set(",;:| ");
		int i=vlist.length;
		foreach (var v in vlist) if (v.strip()=="") i-- ;
		if (i<1) return klist;
		bool e = false;
		foreach (var v in vlist) {
			e = false;
			if (v.strip()=="") continue;
			foreach (var k in kernel_list) if (k.version_main==v) { e = true; klist.add(k); break; }
			if (!e) vprint(_("Kernel")+" \""+v+"\" "+_("not found"));
		}
		return klist;
	}

	// dep: aria2c
	public bool download_packages() {
		vprint("download_packages("+version_main+")",3);
		bool r = true;
		int MB = 1024 * 1024;
		string[] flist = {};

		// if keep_debs, then only download if missing
		// if not keep_debs, then always download
		foreach (var f in deb_url_list.keys) if (!App.keep_debs || !exists(CACHE_KDIR+"/"+f)) flist += f;

		// CHECKSUMS
		if (flist.length>0) {
			deb_checksum_list.clear();
			if (App.verify_checksums) {
				vprint(_("checksums enabled"),2);

				// download the CHECKSUMS file
				if (!exists(CHECKSUMS_FILE)) {
					var dt = new DownloadTask();
					dt.add_to_queue(new DownloadItem(CHECKSUMS_URI,Path.get_dirname(CHECKSUMS_FILE),Path.get_basename(CHECKSUMS_FILE)));
					dt.execute();
					while (dt.is_running) Thread.usleep(100000);
				}
				if (!exists(CHECKSUMS_FILE)) return false;

				// parse the CHECKSUMS file
				// extract the sha256 hashes and save in aria2c format
				// 52e8d02b2975920e7cc9a9d57843fcb8049addf53f1894073afce02d0e7351b2  linux-image-unsigned-6.2.9-060209-generic_6.2.9-060209.202303301133_amd64.deb
				// deb_checksum_list[filename]="sha-256=hash"
				// deb_checksum_list["linux-image-unsigned-6.2.9-060209-generic_6.2.9-060209.202303301133_amd64.deb"]="sha-256=52e8d02b2975920e7cc9a9d57843fcb8049addf53f1894073afce02d0e7351b2"
				// aria2c -h#checksum  ;aria2c -v |grep "^Hash Algorithms:"
				// FIXME assumption: if 1st word is 64 bytes then it is a sha256 hash
				// FIXME assumption: there will always be exactly 2 spaces between hash & filename
				foreach (string l in fread(CHECKSUMS_FILE).split("\n")) {
					var w = l.split(" ");
					if (w.length==3 && w[0].length==64) deb_checksum_list[w[2]] = "sha-256="+w[0];
				}
			}

			var dt = new DownloadTask();
			foreach (var f in flist) dt.add_to_queue(new DownloadItem(deb_url_list[f],CACHE_KDIR,f,deb_checksum_list[f]));
			vprint(_("Downloading %s").printf(version_main));
			dt.execute();
			string[] stat = {"","",""};
			var t = deb_url_list.size.to_string();
			while (dt.is_running) {
				stat = dt.status_line.split_set(" /");
				if (stat[1]!=null && stat[2]!=null) pbar(int64.parse(stat[1])/MB,int64.parse(stat[2])/MB,"MB - file "+(dt.prg_count+1).to_string()+"/"+t);
				Thread.usleep(250000);
			}
			pbar(0,0);
		}

		foreach (string f in deb_url_list.keys) if (!exists(CACHE_KDIR+"/"+f)) r = false;
		return r;
	}

// ---------------------------------------------------------------------
// lock_vlist()
// lock_klist()
// download_vlist()
// download_klist()
// install_vlist()
// install_klist()
// uninstall_vlist()
// uninstall_klist()

	public static int lock_vlist(bool lck,string list="") {
		return lock_klist(lck,vlist_to_klist(list));
	}

	public static int lock_klist(bool lck,Gee.ArrayList<LinuxKernel> klist) {
		vprint("lock_klist("+lck.to_string()+")",3);
		if (klist.size<1) vprint(_("Lock/Unlock: no kernels specified"));
		int r = 0;
		string action = _("lock");
		if (!lck) action = _("unlock");
		string msg;
		foreach (var k in klist) {
			k.set_locked(lck);
			msg = action + " " + k.name + " ";
			if (k.is_locked==lck) msg += _("ok"); else { msg += _("failed"); r++; }
			vprint(msg);
		}
		return r;
	}

	public static int download_vlist(string list="") {
		return download_klist(vlist_to_klist(list));
	}

	public static int download_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("download_klist()",3);
		if (klist.size<1) vprint(_("Download: no downloadable kernels specified")); 
		int r = 0;
		foreach (var k in klist) if (!k.download_packages()) r++;
		return r;
	}

	public static int install_vlist(string list="") {
		return install_klist(vlist_to_klist(list));
	}

	// dep: dpkg
	public static int install_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("install_klist()",3);

		if (!App.try_ppa()) return 1;

		string[] flist = {};
		foreach (var k in klist) {
			var v = k.version_main;

			if (k.is_installed) {
				vprint(_("%s is already installed").printf(v),1,stderr);
				continue;
			}

			if (k.is_locked) {
				vprint(_("%s is locked").printf(v),1,stderr);
				continue;
			}

			if (k.is_invalid) {
				vprint(_("%s is invalid").printf(v),1,stderr);
				continue;
			}

			if (!k.download_packages()) {
				vprint(_("%s download failed").printf(v),1,stderr);
				continue;
			}

			vprint(_("Installing %s").printf(v));
			foreach (var f in k.deb_url_list.keys) flist += k.CACHE_KDIR+"/"+f;
		}

		if (flist.length==0) { vprint(_("Install: no installable kernels specified")); return 1; }

		string cmd = "";
		foreach (var f in flist) { cmd += " '"+f+"'"; }
		cmd = sanitize_cmd(App.auth_cmd).printf("dpkg --install "+cmd);
		vprint(cmd,2);
		if (!ask()) return 1;
		var r = Posix.system(cmd);
		if (!App.keep_debs) foreach (var f in flist) rm(f);
		return r;
	}

	public static int uninstall_vlist(string list="") {
		return uninstall_klist(vlist_to_klist(list));
	}

	// dep: dpkg
	public static int uninstall_klist(Gee.ArrayList<LinuxKernel> klist) {
		vprint("uninstall_klist()",3);

		string pnames = "";
		foreach (var k in klist) {
			var v = k.version_main;

			if (k.is_running) {
				vprint(_("%s is running").printf(v),1,stderr);
				continue;
			}

			if (k.is_locked) {
				vprint(_("%s is locked").printf(v),1,stderr);
				continue;
			}

			vprint(_("Uninstalling %s").printf(v));
			foreach (var p in k.pkg_list) {
				pnames += " '"+p+"'";
				vprint(_("found")+" : "+p,2);
			}
		}
		pnames = pnames.strip();
		if (pnames.length<1) { vprint(_("Uninstall: no uninstallable packages found"),1,stderr); return 1; }

		var cmd = sanitize_cmd(App.auth_cmd).printf("dpkg --purge "+pnames);
		vprint(cmd,2);
		if (!ask()) return 1;
		return Posix.system(cmd);
	}

// ---------------------------------------------------------------------
// kunin_old()
// kinst_latest()

	public static int kunin_old() {
		vprint("kunin_old()",3);

		var klist = new Gee.ArrayList<LinuxKernel>();
		bool found_running_kernel = false;

		foreach(var k in kernel_list) {
			if (!k.is_installed) continue;

			var v = k.version_main;

			if (k.is_running) {
				found_running_kernel = true;
				vprint(_("%s is running").printf(v),2);
				continue;
			}
			if (k.compare_to(kernel_latest_installed) >= 0) {
				vprint(_("%s is the highest installed version").printf(v),2);
				continue;
			}
			if (k.is_locked) {
				vprint(_("%s is locked").printf(v),2);
				continue;
			}

			klist.add(k);
		}

		if (!found_running_kernel) {
			vprint(_("Could not find running kernel in list"),1,stderr);
			return 2;
		}

		if (klist.size == 0){
			vprint(_("No old kernels to uninstall"));
			return 0;
		}

		return uninstall_klist(klist);
	}

	public static int kinst_latest(bool minor_only = false) {
		vprint("kinst_latest()",3);

		var k = kernel_update_minor;
		if (!minor_only && kernel_update_major!=null) k = kernel_update_major;

		if (k==null) { vprint(_("No updates")); return 1; }

		var klist = new Gee.ArrayList<LinuxKernel>();
		klist.add(k);
		return install_klist(klist);
	}

}
