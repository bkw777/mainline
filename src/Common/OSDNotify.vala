
/*
 * OSDNotify.vala
 *
 * Copyright 2016 Tony George <teejeetech@gmail.com>
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

using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.ProcessHelper;

public class OSDNotify : GLib.Object {

	private static DateTime dt_last_notification = null;
	public const int MIN_NOTIFICATION_INTERVAL = 3;

	// send a desktop notification
	// re-use the notification id for subsequent re-sends/updates
	public static int notify_send (string summary = "", string body = "", Gee.ArrayList<string> actions = new Gee.ArrayList<string>(), string close_action = ""){ 
		int retVal = 0;

		long seconds = 9999;
		if (dt_last_notification != null){
			DateTime dt_end = new DateTime.now_local();
			TimeSpan elapsed = dt_end.difference(dt_last_notification);
			seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
		}

		if (seconds > MIN_NOTIFICATION_INTERVAL){

			string s =
				APP_LIB_DIR+"/notify_send/notify-send.sh"
				+ " -R "+App.NOTIFICATION_ID_FILE
				+ " -u low"
				+ " -c info"
				+ " -a "+Constants.PROJECT_NAME
				+ " -i "+Constants.PROJECT_NAME
				+ " -t 0"
				+ " -f ";

			if (close_action != "") s += " -l \""+close_action+"\"";

			foreach (string a in actions) s += " -o \""+a+"\"";

				s += " \""+summary+"\""
				+ " \""+body+"\"";

			log_debug (s);
			exec_async (s);

			dt_last_notification = new DateTime.now_local();

		}

		return retVal;
	}

}
