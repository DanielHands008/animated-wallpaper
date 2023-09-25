//
//  Copyright (C) 2016-2017 Abraham Masri
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

using Playable;
namespace Wallpaper {
bool debug = false;
bool randomOrder = false;
int currentPos = 0;
unowned string playlist = "";
bool useStaticBackground = false;
unowned string staticLocation = "/tmp";
bool generateStaticBackgrounds = true;
bool forceGenerateStaticBackgrounds = false;
BackgroundWindow[] backgroundWindows;
double volume = 0;
unowned string ffmpegSeek = "00:00:00";
int interval = 600000;
bool onlyGenerateStaticBackgrounds = false;

private static bool checkValue(string [] args, int position, string valueType) {
	if (args.length > position) {
		if (valueType == "string")
			return true;
		else if (valueType == "int" || valueType == "double") {
			int valueTmp = int.parse(args[position + 1]);
			if(valueTmp.to_string() == args[position + 1])
				return true;
			if (valueType == "double" && double.try_parse (args[position + 1]))
				return true;
		}
		else if (valueType == "folder") {
			if (GLib.FileUtils.test(args[position + 1], GLib.FileTest.IS_DIR))
				return true;
			else {
				print ("Error: folder does not exist: " + args[position + 1] + "\n");
			}
		}
	}
	print ("Error: invalid value for " + args[position] + "\n");
	Process.exit(0);
	return false;
}
private static bool checkFileExists(string path) {
	File file = File.new_for_path (path);
	if (file.query_exists())
		return true;
	else {
		print("Error: file does not exist: " + path + "\n");
		return false;
	}
}

public static void main (string [] args) {

	int[] monitors = new int[0];

	if (args.length < 2)
		showHelp();

	string tmpPlaylist = "";

	bool invalidVideoFile = false;

	for (int i = 1; i < args.length; i++) {
		if (args[i][0] == '-' && args[i].length == 2) {
			switch (args[i][1])
			{
			case 'd':
				debug = true;
				break;
			case 'm':
				if (checkValue(args, i, "string")) {
					if (args[i + 1] == "all")
						break;
					string[] tmp = args[i + 1].split(",");
					monitors.resize(tmp.length);
					for(int o = 0; o < tmp.length; o++)
						monitors[o] = int.parse(tmp[o]);
					i++;
				}
				break;
			case 'v':
				if (checkValue(args, i, "double")) {
					volume = double.parse(args[i + 1]);
					i++;
				}
				break;
			case 's':
				useStaticBackground = true;
				break;
			case 't':
				if (checkValue(args, i, "string")) {
					ffmpegSeek = args[i + 1];
					i++;
				}
				break;
			case 'i':
				if (checkValue(args, i, "int")) {
					interval = int.parse(args[i + 1]) * 1000;
					i++;
				}
				break;
			case 'r':
				randomOrder = true;
				break;
			case 'l':
				if (checkValue(args, i, "folder")) {
					staticLocation = args[i + 1];
					i++;
				}
				break;
			case 'g':
				onlyGenerateStaticBackgrounds = true;
				useStaticBackground = true;
				break;
			case 'f':
				forceGenerateStaticBackgrounds = true;
				break;
			case 'h':
			default:
				showHelp();
				break;
			}
		}
		else {
			if (checkFileExists(args[i]))
				tmpPlaylist = tmpPlaylist + args[i].to_string() + "\n";
			else
				invalidVideoFile = true;
		}

	}

	if(invalidVideoFile)
		Process.exit(0);

	while (tmpPlaylist[tmpPlaylist.length - 1] == '\n' || tmpPlaylist[tmpPlaylist.length - 1] == ' ') {
		tmpPlaylist = tmpPlaylist.substring(0, tmpPlaylist.length - 1);
	}
	playlist = tmpPlaylist;

	if (playlist.length == 0) {
		print("Error: no video files. \n");
		Process.exit(0);
	}


	string[] playlistArray = playlist.split("\n");

	if (useStaticBackground) {
		if(debug) print("Use static\n");
		for(int i = 0; i < playlistArray.length; i++) {
			string[] fileParts = playlistArray[i].split("/");
			File file = File.new_for_path (staticLocation + "/" + fileParts[fileParts.length - 1] + ".png");
			bool exists = file.query_exists ();

			if(debug) print("File: " + file.get_path() + "\n");
			if(debug) print("Exists: " + exists.to_string() + "\n");

			if(!exists || forceGenerateStaticBackgrounds) {
				if (i == 0)
					print("Generating static backgrounds.");
				else
					print(".");
				makeStaticBackgrounds(playlistArray[i], ffmpegSeek);
				if (i == playlistArray.length - 1)
					print("\n");
			}
		}

	}

	if(onlyGenerateStaticBackgrounds)
		Process.exit(0);

	GtkClutter.init (ref args);
	Gtk.init (ref args);
	Gst.init (ref args);

	var screen = Gdk.Screen.get_default ();
	int monitorCount = screen.get_n_monitors();

	string firstVideo = "";

	if (playlistArray.length == 1 || !randomOrder)
		firstVideo = playlistArray[0];
	else
		firstVideo = playlistArray[Random.int_range(0, playlistArray.length)];

	if (monitors.length == 0) {
		backgroundWindows = new BackgroundWindow[monitorCount];
		for (int i = 0; i < monitorCount; ++i) {
			double monitorVolume = 0;
			if (i == 0) monitorVolume = volume;
			backgroundWindows[i] = new BackgroundWindow(i, firstVideo, monitorVolume);
		}
	}

	else {
		backgroundWindows = new BackgroundWindow[monitors.length];
		for(int i = 0; i < monitors.length; i++) {
			double monitorVolume = 0;
			if (i == 0) monitorVolume = volume;
			backgroundWindows[monitors[i]] = new BackgroundWindow(monitors[i], firstVideo, monitorVolume);
		}
	}



	var mainSettings = Gtk.Settings.get_default ();
	mainSettings.set("gtk-xft-antialias", 1, null);
	mainSettings.set("gtk-xft-rgba", "none", null);
	mainSettings.set("gtk-xft-hintstyle", "slight", null);

	for (int i = 0; i < backgroundWindows.length; ++i)
		backgroundWindows[i].show_all();

	uint timerID;
	if (playlistArray.length > 1)
		timerID = Timeout.add (interval, changeWallpaper);

	if (useStaticBackground) {
		setStaticBackground(firstVideo);	
	}

	Clutter.main();


}

public bool changeWallpaper () {
	string[] playlistArray = playlist.split("\n");
	if (playlistArray.length < 2)
		return true;

	if (!randomOrder) {
		currentPos++;
	}
	else {
		int oldPos = currentPos;
		while (oldPos == currentPos)
		{
			currentPos = Random.int_range(0, playlistArray.length);
		}
	}
	if (currentPos >= playlistArray.length)
		currentPos = 0;

	if(debug) print ("Set background: " + currentPos.to_string() + "\n");

	if(backgroundWindows.length > 0)
		backgroundWindows[0].setVideoWallpaper(playlistArray[currentPos], volume);
	for (int i = 1; i < backgroundWindows.length; i++)
		backgroundWindows[i].setVideoWallpaper(playlistArray[currentPos], 0);
	if (useStaticBackground) {
		setStaticBackground(playlistArray[currentPos]);
	}

	return true;
}

public static void makeStaticBackgrounds(string fileName, string ffmpegSeek) {
	string[] fileParts = fileName.split("/");
	string ls_stdout;
	string ls_stderr;
	int ls_status;
	try {
		string ffmpegCommand = "ffmpeg -y -i \"" + fileName + "\" -ss " + ffmpegSeek + " -frames:v 1 \"" + staticLocation + "/" + fileParts[fileParts.length - 1] + ".png\"";
		if(debug) print(ffmpegCommand + "\n");
		Process.spawn_command_line_sync (ffmpegCommand, out ls_stdout, out ls_stderr, out ls_status);

		if(debug) print ("stdout:\n");
		if(debug) print (ls_stdout);
		if(debug) print ("stderr:\n");
		if(debug) print (ls_stderr);
		if(debug) print ("Status: %d\n", ls_status);

	} catch (SpawnError e) {
		print ("Error: %s\n", e.message);
	}
}

public static void setStaticBackground(string fileName) {
	if(debug) print ("Setting static background.");
	string[] fileParts = fileName.split("/");
	string ls_stdout;
	string ls_stderr;
	int ls_status;
	try {
		string setBackgroundCommandA = "gsettings set org.gnome.desktop.background picture-uri file://" + staticLocation + "/" + fileParts[fileParts.length - 1] + ".png";
		if(debug) print(setBackgroundCommandA + "\n");
		Process.spawn_command_line_sync (setBackgroundCommandA, out ls_stdout, out ls_stderr, out ls_status);
		string setBackgroundCommandB = "gsettings set org.gnome.desktop.background picture-uri-dark file://" + staticLocation + "/" + fileParts[fileParts.length - 1] + ".png";
		if(debug) print(setBackgroundCommandB + "\n");
		Process.spawn_command_line_sync (setBackgroundCommandB, out ls_stdout, out ls_stderr, out ls_status);
		if(debug) print ("stdout:\n");
		if(debug) print (ls_stdout);
		if(debug) print ("stderr:\n");
		if(debug) print (ls_stderr);
		if(debug) print ("Status: %d\n", ls_status);
	} catch (SpawnError e) {
		print ("Error: %s\n", e.message);
	}
}

public static void showHelp() {
	print("Usage:\n\tanimated-wallpaper options [FILE] [FILE] [File]\n");
	print("Options:\n");
	print(" -d\tEnable debug mode.\n");
	print(" -m\tSelect monitors. (eg. -n 0,2) Default: all\n");
	print(" -v\tSet volume. (eg. -v 0.2) Default: 0\n");
	print(" -s\tSet the static background to a frame from the video. (Requires ffmpeg)\n");
	print(" -t\tTime in the video the static background is taken from. (eg. -t 00:00:05) Default: 00:00:00\n");
	print(" -i\tInterval in seconds between backgrounds. (eg. -i 900) Default: 600\n");
	print(" -r\tShow backgrounds in a random order.\n");
	print(" -l\tSet the location for static backgrounds. (eg. -l /tmp/animated-backgrounds) default: /tmp\n");
	print(" -g\tOnly generate static backgrounds.\n");
	print(" -f\tGenerate static backgrounds even if file exists.\n");

	Process.exit(0);
}
}
