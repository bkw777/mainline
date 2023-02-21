using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JsonHelper;
using TeeJee.ProcessHelper;
using TeeJee.System;
using TeeJee.Misc;

public class LinuxKernel : GLib.Object, Gee.Comparable<LinuxKernel> {
	
	public string kname = "";
	public string kver = "";
	public string version_main = "";
	public string version_package = "";
	public string page_uri = "";

	public int version_maj = -1;
	public int version_min = -1;
	public int version_point = -1;
	public int version_rc = -1;

	public Gee.HashMap<string,string> deb_list = new Gee.HashMap<string,string>();
	public Gee.HashMap<string,string> apt_pkg_list = new Gee.HashMap<string,string>();

	public static Gee.HashMap<string,Package> pkg_list_installed;
	
	public bool is_installed = false;
	public bool is_running = false;
	public bool is_mainline = false;

	public string deb_header = "";
	public string deb_header_all = "";
	public string deb_image = "";
	public string deb_image_extra = "";
	public string deb_modules = "";
	
	// static
	
	[CCode(cname="URI_KERNEL_UBUNTU_MAINLINE")]
	public extern const string URI_KERNEL_UBUNTU_MAINLINE;

	public static string CACHE_DIR;
	public static string NATIVE_ARCH;
	public static string LINUX_DISTRO;
	public static string RUNNING_KERNEL;
	public static string CURRENT_USER;
	public static string CURRENT_USER_HOME;
	
	public static LinuxKernel kernel_active;
	public static LinuxKernel kernel_update_major;
	public static LinuxKernel kernel_update_minor;
	public static LinuxKernel kernel_latest_available;
	public static LinuxKernel kernel_latest_installed;

	public static Gee.ArrayList<LinuxKernel> kernel_list = new Gee.ArrayList<LinuxKernel>();

	public static Regex rex_header = null;
	public static Regex rex_header_all = null;
	public static Regex rex_image = null;
	public static Regex rex_image_extra = null;
	public static Regex rex_modules = null;
		
	// global progress  ------------
	public static string status_line;
	public static int64 progress_total;
	public static int64 progress_count;
	public static bool cancelled;
	public static int highest_maj;

	// class initialize

	public static void initialize(){
		new LinuxKernel("", false); // instance must be created before setting static members

		LINUX_DISTRO = check_distribution();
		NATIVE_ARCH = check_package_architecture();
		RUNNING_KERNEL = check_running_kernel().replace("-generic","");
		initialize_regex();
	}

	// dep: lsb_release
	public static string check_distribution(){
		string dist = "";

		string std_out, std_err;
		int status = exec_sync("lsb_release -sd", out std_out, out std_err);
		if ((status == 0) && (std_out != null)){
			dist = std_out.strip();
			log_msg(_("Distribution") + ": %s".printf(dist));
		}
		
		return dist;
	}

	// dep: dpkg
	public static string check_package_architecture(){
		string arch = "";

		string std_out, std_err;
		int status = exec_sync("dpkg --print-architecture", out std_out, out std_err);
		if ((status == 0) && (std_out != null)){
			arch = std_out.strip();
			log_msg(_("Architecture") + ": %s".printf(arch));
		}

		return arch;
	}

	// dep: uname
	public static string check_running_kernel(){
		string ver = "";
		
		string std_out;
		exec_sync("uname -r", out std_out, null);
		log_debug(std_out);
		
		ver = std_out.strip().replace("\n","");
		log_msg("Running kernel" + ": %s".printf(ver));

		return ver;
	}

	public static void initialize_regex(){
		try{
			//linux-headers-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_header = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-[a-zA-Z0-9.\-_]*-generic_[a-zA-Z0-9.\-]*_""" + NATIVE_ARCH + ".deb");

			//linux-headers-3.4.75-030475_3.4.75-030475.201312201255_all.deb
			rex_header_all = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-headers-[a-zA-Z0-9.\-_]*_all.deb""");

			//linux-image-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-[a-zA-Z0-9.\-_]*-generic_([a-zA-Z0-9.\-]*)_""" + NATIVE_ARCH + ".deb");

			//linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_image_extra = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-image-extra-[a-zA-Z0-9.\-_]*-generic_[a-zA-Z0-9.\-]*_""" + NATIVE_ARCH + ".deb");

			//linux-image-extra-3.4.75-030475-generic_3.4.75-030475.201312201255_amd64.deb
			rex_modules = new Regex("(?:" + NATIVE_ARCH + """/|>)?linux-modules-[a-zA-Z0-9.\-_]*-generic_[a-zA-Z0-9.\-]*_""" + NATIVE_ARCH + ".deb");
		}
		catch (Error e) {
			log_error (e.message);
		}
	}

	public static bool check_if_initialized(){
		bool ok = (NATIVE_ARCH.length > 0);
		if (!ok){
			log_error("LinuxKernel: Class should be initialized before use!");
			exit(1);
		}
		return ok;
	}

	public static void clean_cache(){
		//log_debug("clean_cache() deleting: \"%s\"".printf(CACHE_DIR));
		if (dir_exists(CACHE_DIR)){
			bool ok = dir_delete(CACHE_DIR);
			if (ok) log_msg("Removed cached files in '%s'".printf(CACHE_DIR));
		}
	}

	// constructor
	public LinuxKernel(string _name, bool _is_mainline){
		// _name, kname includes the leading "v" and everything after the version number
		// same as what's in the urls on the kernel ppa index.html

		// strip off the trailing "/"
		if (_name.has_suffix("/")) this.kname = _name[0: _name.length - 1];
		else this.kname = _name;

		// extract version numbers from the name
		kver = this.kname;
		split_version_string(kver, out version_main);

		// set page URI -----------
		page_uri = "%s%s".printf(URI_KERNEL_UBUNTU_MAINLINE, _name);

		// override is_mainline from split_version_string()
		is_mainline = _is_mainline;
	}

	public LinuxKernel.from_version(string _version){
		kver = _version;
		split_version_string(kver, out version_main);
		page_uri = "";
	}

	// static

	public delegate void Notifier(GLib.Timer timer, ref long count, bool last = false);

	public static void query(bool wait, owned Notifier? notifier = null){

		check_if_initialized();

		try {
			cancelled = false;
			var worker = new Thread<void>.try(null, () => {
				try {
					query_thread((owned) notifier);
				} catch (Error e) {
					log_error (e.message);
				}
			});
		
			if (wait)
				worker.join();
		} catch (Error e) {
			log_error (e.message);
		}
	}

	private static void query_thread(owned Notifier? notifier) throws Error {
		App.progress_total = 1;
		App.progress_count = 0;

		var timer = timer_start();
		long count = 0;

		log_debug("query_thread() App.show_prev_majors: %d".printf(App.show_prev_majors));
		log_debug("query_thread() App.hide_unstable: "+App.hide_unstable.to_string());

		//DownloadManager.reset_counter();

		// download main index.html if stale
		bool refresh = false;
		var one_hour_before = (new DateTime.now_local()).add_hours(-1);
		if (last_refreshed_date.compare(one_hour_before) < 0) refresh = true;
		bool is_connected = Main.can_reach_mainline_ppa();
		if (refresh) download_index();

		// read main index.html
		load_index();

		// TODO: Implement locking for multiple download threads

		// download per-kernel index.html and CHANGES

		// init the progress display
		status_line = "";
		progress_total = 0;
		progress_count = 0;

		// By default, display all kernels belonging to the oldest major version installed and up
		highest_maj = find_lowest_major_version_installed();

		// determine the size of the job for the percent-done display
		foreach(var k in kernel_list){
			if(!k.is_installed){
				if (k.version_maj < highest_maj-App.show_prev_majors) continue;
				if (App.hide_unstable && k.is_unstable) continue;
			}
			if (k.is_valid && !k.cached_page_exists) progress_total += 1;
			if (notifier != null) notifier(timer, ref count);
		}

		// list of kernels - 1 LinuxKernel object per kernel to update
		var kernels_to_update = new Gee.ArrayList<LinuxKernel>();
		// list of files - 1 DownloadItem object per individual file to download
		var downloads = new Gee.ArrayList<DownloadItem>();

		// add files to download list, and add kernels to kernel list
		foreach(var k in kernel_list){
			if (cancelled) break;

			// skip some kernels for various reasons
			if (k.cached_page_exists){
				// load the index.html files we already had in cache
				k.load_cached_page();
				continue;
			}
			if (!k.is_valid) continue;

			if (!k.is_installed) {
				if (k.version_maj < highest_maj-App.show_prev_majors) continue;
				if (App.hide_unstable && k.is_unstable) continue;
			}

			// add index.html to download list
			var item = new DownloadItem(k.cached_page_uri, file_parent(k.cached_page), file_basename(k.cached_page));
			downloads.add(item);

			// add kernel to kernel list
			kernels_to_update.add(k);
			if (notifier != null) notifier(timer, ref count);
		}

		// process the download list
		if ((downloads.size > 0) && is_connected){
			var mgr = new DownloadTask();

			// add download list to queue
			foreach(var item in downloads) mgr.add_to_queue(item);

			mgr.status_in_kb = true;
			mgr.prg_count_total = progress_total;

			// start downloading
			mgr.execute();

			print_progress_bar_start(_("Fetching index..."));

			// while downloading
			while (mgr.is_running()){
				progress_count = mgr.prg_count;
				print_progress_bar((progress_count * 1.0) / progress_total);
				sleep(300);
			}

			// done downloading
			print_progress_bar_finish();

			// load the index.html files we just added to cache
			foreach(var k in kernels_to_update) k.load_cached_page();
			if (notifier != null) notifier(timer, ref count);
		}

		check_installed();

		//check_updates("query_thread()");
		check_updates();

		timer_elapsed(timer, true);
		if (notifier != null) notifier(timer, ref count, true);
	}

	// download the main index.html listing all mainline kernels
	private static void download_index() throws Error {
		check_if_initialized();

		dir_create(file_parent(index_page));

		var msg = _("Fetching index from kernel.ubuntu.com...");
		log_msg(msg);
		status_line = msg.strip();

		FileDownloader.synchronous(URI_KERNEL_UBUNTU_MAINLINE, CACHE_DIR + "/index.html");
	}

	// read the main index.html listing all kernels
	// https://kernel.ubuntu.com/~kernel-ppa/mainline/
	private static void load_index(){
		if (!file_exists(index_page)) return;

		var list = new Gee.ArrayList<LinuxKernel>();
		string txt = file_read(index_page);

		try{
			// <a href="v3.0.16-oneiric/">v3.0.16-oneiric/</a>
			var rex = new Regex("""<a href="([a-zA-Z0-9\-._\/]+)">([a-zA-Z0-9\-._]+)[\/]*<\/a>""");

			MatchInfo match;

			// for each line in the file...
			foreach(string line in txt.split("\n")){
				// find only the lines with a link
				if (rex.match(line, 0, out match)){
					// ignore the links that don't start with "v"
					if (!match.fetch(2).has_prefix("v")) continue;
					//  
					var k = new LinuxKernel(match.fetch(1), true);
					list.add(k);
				}
			}

			list.sort((a,b)=>{
				return a.compare_to(b) * -1;
			});
		}
		catch (Error e) {
			log_error (e.message);
		}

		kernel_list = list;
	}

	public static void check_installed(){

		log_debug("check_installed()");

		log_msg(string.nfill(70, '-'));

//		foreach(var k in kernel_list){
//			k.is_installed = false;
//			k.is_running = false;
//		}

		pkg_list_installed = Package.query_installed_packages();

		var pkg_versions = new Gee.ArrayList<string>();

		foreach(var pkg in pkg_list_installed.values){
			if (pkg.pname.contains("linux-image")){
				if (!pkg_versions.contains(pkg.version_installed)){

					pkg_versions.add(pkg.version_installed);

					log_msg("Found installed" + ": %s".printf(pkg.version_installed));

					string pkern_name = pkg.version_installed;
					var pkern = new LinuxKernel(pkern_name, false);
					pkern.is_installed = true;
					pkern.set_apt_pkg_list();

					bool found = false;
					foreach(var k in kernel_list){
						if (k.version_main == pkern.version_main){
							found = true;
							k.apt_pkg_list = pkern.apt_pkg_list;
							break;
						}
					}

					if (!found) kernel_list.add(pkern);
				}
			}
		}

		foreach (string pkg_version in pkg_versions){
			foreach(var k in kernel_list){
				if (k.version_package == pkg_version) k.is_installed = true;
			}
		}

		// Find and tag the running kernel in list ------------------
		
		// Running: 4.2.7-040207-generic
		// Package: 4.2.7-040207.201512091533

		// Running: 4.4.0-28-generic
		// Package: 4.4.0-28.47

		var kern_running = new LinuxKernel.from_version(RUNNING_KERNEL);
		kernel_active = null;

		// scan mainline kernels
		foreach(var k in kernel_list){
			if (!k.is_valid) continue;
			if (!k.is_mainline) continue;

			if (k.version_package.length > 0) {
				string ver_pkg_short = k.version_package[0 : k.version_package.last_index_of(".")];
				if (ver_pkg_short == RUNNING_KERNEL){
					k.is_running = true;
					k.is_installed = true;
					kernel_active = k;
					break;
				}
			}
		}

		// scan ubuntu kernels
		if (kernel_active == null){
			foreach(var k in kernel_list){
				if (!k.is_valid) continue;
				if (k.is_mainline) continue;

				if (kern_running.version_main == k.version_main){
					k.is_running = true;
					k.is_installed = true;
					kernel_active = k;
					break;
				}
			}
		}

		kernel_list.sort((a,b)=>{
			return a.compare_to(b) * -1;
		});

		log_msg(string.nfill(70, '-'));

		// find the highest installed version ----------------------
		kernel_latest_installed = new LinuxKernel.from_version("0");
		foreach(var k in kernel_list){
			if (k.is_installed) {
				kernel_latest_installed = k;
				break;
			}
		}
		log_msg(string.nfill(70, '-'));
	}

	// scan kernel_list for versions newer than latest installed
	//public static void check_updates(string from = ""){
	public static void check_updates(){
		//log_debug("check_updates("+from+")");
		log_debug("check_updates()");
		kernel_update_major = null;
		kernel_update_minor = null;
		kernel_latest_available = null;

		foreach(var k in LinuxKernel.kernel_list){
			if (!k.is_valid) continue;
			if ((App.hide_unstable && k.is_unstable) && (!k.is_installed)) continue;
			if (kernel_latest_available == null) kernel_latest_available = k;
			if (k.is_installed) continue;

			bool major_available = false;
			bool minor_available = false;
			//string msg = "\n|tvm:"+k.version_main+"|tvr:%d".printf(k.version_rc)+"|";

			//if(kernel_latest_installed!=null) msg += "i:"+kernel_latest_installed.version_main+"|";

			//msg += "\n|"
			//+ "i.M:%d|".printf(kernel_latest_installed.version_maj)
			//+ "i.m:%d|".printf(kernel_latest_installed.version_min)
			//+ "i.p:%d|".printf(kernel_latest_installed.version_point)
			//+ "i.r:%d|".printf(kernel_latest_installed.version_rc)
			//+ "\n|"
			//+ "k.M:%d|".printf(k.version_maj)
			//+ "k.m:%d|".printf(k.version_min)
			//+ "k.p:%d|".printf(k.version_point)
			//+ "k.r:%d|".printf(k.version_rc);
			if (k.version_maj > kernel_latest_installed.version_maj) {
				//msg += "u:M(M)|";
				major_available = true;
			}
			else if (k.version_maj == kernel_latest_installed.version_maj) {
				if (k.version_min > kernel_latest_installed.version_min) {
					//msg += "u:M(m)|";
					major_available = true;
				}
				else if (k.version_min == kernel_latest_installed.version_min) {
					if (k.version_point > kernel_latest_installed.version_point) {
						//msg += "u:m(p)|";
						minor_available = true;
					}
					else if (k.version_point == kernel_latest_installed.version_point) {
						if (k.version_rc > kernel_latest_installed.version_rc) {
							//msg += "u:m(r)|";
							minor_available = true;
						}
					}
				}
			}

			//msg += "\n|";

			if (major_available && (kernel_update_major == null)) {
				kernel_update_major = k;
				//msg += "kuM:"+k.version_main+"|";
			}

			if (minor_available && (kernel_update_minor == null)) {
				kernel_update_minor = k;
				//msg += "kum:"+k.version_main+"|";
			}

			//if(kernel_latest_available!=null) msg += "a:"+kernel_latest_available.version_main+"|";

			//log_debug(msg);
			// stop if we have everything possible
			if ((kernel_update_major != null) && (kernel_update_minor != null) && (kernel_latest_available != null)) break;
		}
	}

	public static void kunin_old(bool confirm){

		check_installed();

		var list = new Gee.ArrayList<LinuxKernel>();

		var kern_running = new LinuxKernel.from_version(RUNNING_KERNEL);

		bool found_running_kernel = false;
		
		foreach(var k in LinuxKernel.kernel_list){
			if (!k.is_valid) continue;
			if (!k.is_installed) continue;
			if (k.version_main == kern_running.version_main){
				found_running_kernel = true;
				continue;
			}
			if (k.compare_to(kern_running) > 0) continue; // FIXME, compare kernel_latest_installed
			list.add(k);
		}

		if (!found_running_kernel){
			log_error(_("Could not find running kernel in list!"));
			log_msg(string.nfill(70, '-'));
			return;
		}

		if (list.size == 0){
			log_msg(_("Could not find any kernels to uninstall"));
			log_msg(string.nfill(70, '-'));
			return;
		}

		// confirm -------------------------------

		if (confirm){
			
			var message = "\n%s:\n".printf(_("The following kernels will be uninstalled:"));

			foreach(var kern in list){

				message += " ▰ %s\n".printf(kern.version_main);
			}

			message += "\n%s (y/n): ".printf(_("Continue ?"));

			stdout.printf(message);
			stdout.flush();
			
			int ch = stdin.getc();

			if (ch != 'y'){ return; }
		}

		// uninstall --------------------------------
		kunin_list(list);
	}

	public static void kinst_latest(bool point_update, bool confirm){

		query(true);

		// already done in query() -> query_thread() ?
		//check_updates("kinst_latest()");
		//check_updates();

		var kern_major = LinuxKernel.kernel_update_major;
		
		if ((kern_major != null) && !point_update){
			
			var message = "%s: %s".printf(_("Latest update"), kern_major.version_main);
			log_msg(message);
			
			kinst_update(kern_major, confirm);
			return;
		}

		var kern_minor = LinuxKernel.kernel_update_minor;

		if (kern_minor != null){
			
			var message = "%s: %s".printf(_("Latest point update"), kern_minor.version_main);
			log_msg(message);

			kinst_update(kern_minor, confirm);
			return;
		}

		if ((kern_major == null) && (kern_minor == null)){
			log_msg(_("No updates found"));
		}

		log_msg(string.nfill(70, '-'));
	}

	public static void kinst_update(LinuxKernel kern, bool confirm){

		if (confirm){
			
			var message = "\n" + _("Install Kernel Version %s ? (y/n): ").printf(kern.version_main);
			stdout.printf(message);
			stdout.flush();
			
			int ch = stdin.getc();

			if (ch != 'y'){ return; }
		}

		kern.kinst();
	}

	// helpers

	public static int find_lowest_major_version_installed(){
		pkg_list_installed = Package.query_installed_packages();

		int? major_version = null;
		foreach(var pkg in pkg_list_installed.values){
			if (!pkg.pname.contains("linux-image") || !pkg.is_installed){
				continue;
			}

			bool is_mainline = false;  // Not important here, just set whatever
			var candidate = new LinuxKernel(pkg.version_installed, is_mainline);
			if (major_version == null || candidate.version_maj < major_version){
				major_version = candidate.version_maj;
			}
		}

		if (major_version == null){
			major_version = new LinuxKernel.from_version(RUNNING_KERNEL).version_maj;
		}

		return major_version;
	}

	public void split_version_string(string _version_string, out string ver_main){
		ver_main = "";
		version_maj = 0;
		version_min = 0;
		version_point = 0;
		version_rc = -1;

		if (_version_string.length == 0) return;

		var version_string = _version_string.split("~")[0];
		var match = regex_match("""[v]*([0-9]+|r+c+)""", version_string);
		int index = -1;
		string version_extra = "";
		bool saw_rc = false;
		
		while (match != null){
			string? num = match.fetch(1);

			if (num != null){
				index++;

				if (saw_rc) {
					saw_rc = false;
					version_rc = int.parse(num);
				} else if (num == "rc") {
					saw_rc = true;
				} else {
					switch(index){
					case 0:
						version_maj = int.parse(num);
						break;
					case 1:
						version_min = int.parse(num);
						break;
					case 2:
						version_point = int.parse(num);
						break;
					case 3:
						if ((version_rc<0) && (num.length<3)) version_extra += "."+num;
						break;
					case 4:
						if ((version_rc<0) && (num.length<3)) version_extra += "."+num;
						break;
					}
					if (num.length >= 12) is_mainline = true;
				}
			}

			if (version_rc>-1) version_extra = "-rc%d".printf(version_rc);
			ver_main = "%d.%d.%d%s".printf(version_maj,version_min,version_point,version_extra);

			try{
				if (!match.next()){
					break;
				}
			}
			catch(Error e){
				break;
			}
		}

	}

	public int compare_to(LinuxKernel b){
		LinuxKernel a = this;
		string[] arr_a = a.version_main.split_set (".-_");
		string[] arr_b = b.version_main.split_set (".-_");

		int i = 0;
		int x, y;

		// while both arrays have an element
		while ((i < arr_a.length) && (i < arr_b.length)){

			// continue if equal
			if (arr_a[i] == arr_b[i]){
				i++;
				continue;
			}
			
			// check if number
			x = int.parse(arr_a[i]);
			y = int.parse(arr_b[i]);
			if ((x > 0) && (y > 0)){
				// both are numbers
				return (x - y);
			}
			else if ((x == 0) && (y == 0)){
				// BKW - this is one place where "-rc3" gets compared to "-rc4"
				// both are strings
				//log_debug("strcmp("+arr_a[i]+","+arr_b[i]+")");
				return strcmp(arr_a[i], arr_b[i]);
			}
			else{
				if (x > 0){
					return 1;
				}
				else{
					return -1;
				}
			}
		}

		// one array has less parts than the other and all corresponding parts are equal

		if (i < arr_a.length){
			x = int.parse(arr_a[i]);
			if (x > 0){
				return 1;
			}
			else{
				return -1;
			}
		}

		if (i < arr_b.length){
			y = int.parse(arr_b[i]);
			if (y > 0){
				return -1;
			}
			else{
				return 1;
			}
		}

		return (arr_a.length - arr_b.length) * -1; // smaller array is larger version
	}

	public void mark_invalid(){
		string f = cache_subdir+"/invalid";
		if (!file_exists(f)){
			file_write(f, "");
		}
	}

	public void set_apt_pkg_list(){
		foreach(var pkg in pkg_list_installed.values){
			if (!pkg.pname.has_prefix("linux-")){
				continue;
			}
			if (pkg.version_installed == kver){
				apt_pkg_list[pkg.pname] = pkg.pname;
				log_debug("Package: %s".printf(pkg.pname));
			}
		}
	}
	
	// properties

	public bool is_unstable{
		get {
			return kver.contains("-rc") || kver.contains("-unstable");
		}
	}

	public bool is_valid {
		get {
			string invalid_file_path = "%s/invalid".printf(cache_subdir);
			return !file_exists(invalid_file_path);
		}
	}
	
	public static string index_page{
		owned get {
			return "%s/index.html".printf(CACHE_DIR);
		}
	}

	public static DateTime last_refreshed_date{
		owned get{
			if (file_get_size(index_page) < 300000){
				return (new DateTime.now_local()).add_years(-1);
			}
			else{
				return file_get_modified_date(index_page);
			}
		}
	}

	public string cache_subdir{
		owned get {
			return "%s/%s".printf(CACHE_DIR,version_main);
		}
	}

	public string cached_page{
		owned get {
			return "%s/index.html".printf(cache_subdir);
		}
	}

	public string cached_page_uri{
		owned get {
			return page_uri;
		}
	}

	public string changes_file{
		owned get {
			return "%s/CHANGES".printf(cache_subdir);
		}
	}

	public string changes_file_uri{
		owned get {
			return "%s%s".printf(page_uri, "CHANGES");
		}
	}
	
	public bool cached_page_exists{
		get {
			return file_exists(cached_page);
		}
	}

	public string tooltip_text(){
		string txt = "";

		string list = "";
		foreach(string deb in deb_list.keys){
			list += "\n%s".printf(deb);
		}

		if (list.length > 0){
			txt += "<b>%s</b>\n%s".printf(_("Packages Available"), list);
		}

		list = "";
		foreach(string deb in apt_pkg_list.keys){
			list += "\n%s".printf(deb);
		}
		if (list.length > 0){
			txt += "\n\n<b>%s</b>\n%s".printf(_("Packages Installed"), list);
		}
		
		return txt;
	}
	
	// load
	
	private void load_cached_page(){
			
		var list = new Gee.HashMap<string,string>();

		if (!file_exists(cached_page)){
			//log_error("load_cached_page: " + _("File not found") + ": %s".printf(cached_page));
			return;
		}

		string txt = file_read(cached_page);
		
		// parse index.html --------------------------

		try{
			//<a href="linux-headers-4.6.0-040600rc1-generic_4.6.0-040600rc1.201603261930_amd64.deb">//same deb name//</a>
			var rex = new Regex("""<a href="([a-zA-Z0-9\-._/]+)">([a-zA-Z0-9\-._/]+)<\/a>""");
			MatchInfo match;

			foreach(string line in txt.split("\n")){
				if (rex.match(line, 0, out match)){
					string file_name = match.fetch(2);
					string file_uri = "%s%s".printf(page_uri, match.fetch(1));
					bool add = false;

					if (rex_header.match(file_name, 0, out match)){
						deb_header = file_name;
						add = true;
					}

					if (rex_header_all.match(file_name, 0, out match)){
						deb_header_all = file_name;
						add = true;
					}

					if (rex_image.match(file_name, 0, out match)){
						deb_image = file_name;
						version_package = match.fetch(1);
						add = true;
					}

					if (rex_image_extra.match(file_name, 0, out match)){
						deb_image_extra = file_name;
						add = true;
					}

					if (rex_modules.match(file_name, 0, out match)){
						deb_modules = file_name;
						add = true;
					}

					if (add){
						list[file_name] = file_uri; // add to list
					}
				}
			}

			// if ((deb_header.length == 0) || (deb_header_all.length == 0) || (deb_image.length == 0))
			if (deb_image.length == 0) mark_invalid();
		}
		catch (Error e) {
			log_error (e.message);
		}
		
		
		deb_list = list;
	}

	// actions

	public static void print_list(){
		log_msg("");
		log_draw_line();
		log_msg(_("Available Kernels"));
		log_draw_line();

		foreach(var k in kernel_list){
			if (!k.is_valid) continue;

			// check running/installed state before checking for hidden
			var desc = k.is_running ? _("Running") : (k.is_installed ? _("Installed") : "");

			// hide hidden, but don't hide any installed
			if (!k.is_installed) {
				if (App.hide_unstable && k.is_unstable) continue;
				if (k.version_maj < highest_maj-App.show_prev_majors) continue;
			}

			// kern.kname "v5.6.11" -> cache download dir names, needed for --install, --remove
			// kern.kver or kern.version_main "5.6.11" -> most displays & references
			//log_msg("%-32s %-32s %s".printf(kern.kname, kern.version_main, desc));
			log_msg("%-32s %s".printf(k.version_main, desc));
		}
	}

	public static bool download_kernels(Gee.ArrayList<LinuxKernel> selected_kernels){
		foreach(var kern in selected_kernels) kern.download_packages();
		return true;
	}
	
	// dep: aria2c
	public bool download_packages(){
		bool ok = true;

		check_if_initialized();

		foreach(string file_name in deb_list.keys){

			string dl_dir = cache_subdir;
			string file_path = "%s/%s".printf(dl_dir, file_name);

			if (file_exists(file_path) && !file_exists(file_path + ".aria2c")){
				continue;
			}

			dir_create(dl_dir);

			stdout.printf("\n" + _("Downloading") + ": '%s'... \n".printf(file_name));
			stdout.flush();

			var item = new DownloadItem(deb_list[file_name], file_parent(file_path), file_basename(file_path));

			var mgr = new DownloadTask();
			mgr.add_to_queue(item);
			mgr.status_in_kb = true;
			mgr.execute();

			while (mgr.is_running()){
				
				sleep(200);

				stdout.printf("\r%-60s".printf(mgr.status_line.replace("\n","")));
				stdout.flush();
			}

			if (file_exists(file_path)){				
				stdout.printf("\r%-70s\n".printf(_("OK")));
				stdout.flush();

			}
			else{
				stdout.printf("\r%-70s\n".printf(_("ERROR")));
				stdout.flush();
				ok = false;
			}
		}
		
		return ok;
	}

	// dep: dpkg
	public bool kinst(){

		// check if installed
		if (is_installed){
			log_error(_("This kernel is already installed."));
			return false;
		}

		bool ok = download_packages();
		int status = -1;

		if (ok){

			log_msg("Preparing to install '%s'".printf(version_main));

			var flist = "";

			// full paths instead of env -C
			// https://github.com/bkw777/mainline/issues/128
			foreach(string file_name in deb_list.keys){
				flist += " '%s/%s'".printf(cache_subdir,file_name);
				log_msg("kinst() flist += %s/%s".printf(cache_subdir,file_name));
			}

			string cmd = "pkexec env DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY} dpkg --install "+flist;

			status = Posix.system(cmd);
			ok = (status == 0);

			if (ok) {
				log_msg(_("Installation completed. A reboot is required to use the new kernel."));
			}
			else {
				log_error(_("Installation completed with errors"));
			}

			foreach(string file_name in deb_list.keys){
				flist = "%s/%s".printf(cache_subdir,file_name);
				file_delete(flist);
			}

		}

		return ok;
	}

	// dep: dpkg
	public static bool kunin_list(Gee.ArrayList<LinuxKernel> selected_kernels){
		bool ok = true;
		int status = -1;

		// check if running
		foreach(var k in selected_kernels){
			if (k.is_running){
				log_error(_("Selected kernel is currently running and cannot be un-installed.\n Install another kernel before un-installing this one."));
				return false;
			}
		}

		log_msg(_("Preparing to uninstall selected kernels"));

		string cmd = "pkexec env DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY} dpkg --purge";

		foreach(var kern in selected_kernels){
			
			if (kern.apt_pkg_list.size > 0){
				foreach(var pkg_name in kern.apt_pkg_list.values){
					if (!pkg_name.has_prefix("linux-tools")
						&& !pkg_name.has_prefix("linux-libc")){
							
						cmd += " '%s'".printf(pkg_name);
					}
				}
			}
			else if (kern.deb_list.size > 0){
				// get package names from deb file names
				foreach(string file_name in kern.deb_list.keys){
					cmd += " '%s'".printf(file_name.split("_")[0]);
				}
			}
			else{
				log_error("Could not find the packages to un-install!");
				return false;
			}
		}

		status = Posix.system(cmd);
		ok = (status == 0);

		if (ok){
			log_msg(_("Un-install completed"));
		}
		else{
			log_error(_("Un-install completed with errors"));
		}

		return ok;
	}

	// dep: dpkg
	public bool kunin(){
		bool ok = true;
		int status = -1;

		// check if running
		if (is_running){
			log_error(_("This kernel is currently running and cannot be un-installed.\n Install another kernel before un-installing this one."));
			return false;
		}

		log_msg("Preparing to un-install '%s'".printf(version_main));

		string cmd = "pkexec env DISPLAY=${DISPLAY} XAUTHORITY=${XAUTHORITY} dpkg --purge";

		if (apt_pkg_list.size > 0){
			foreach(var pkg_name in apt_pkg_list.values){
				if (!pkg_name.has_prefix("linux-tools")
					&& !pkg_name.has_prefix("linux-libc")){
					cmd += " '%s'".printf(pkg_name);
				}
			}
		}
		else if (deb_list.size > 0){
			// get package names from deb file names
			foreach(string file_name in deb_list.keys){
				cmd += " '%s'".printf(file_name.split("_")[0]);
			}
		}
		else{
			log_error("Could not find the packages to un-install!");
			return false;
		}

		status = Posix.system(cmd);
		ok = (status == 0);

		if (ok){
			log_msg(_("Un-install completed"));
		}
		else{
			log_error(_("Un-install completed with errors"));
		}

		return ok;
	}
}
