pragma Singleton

import Quickshell

Singleton {
	readonly property string home: Quickshell.env("HOME")
	readonly property string config: `${home}/.config/quickshell`
	readonly property string scripts: `${config}/scripts`
	readonly property string state: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
	readonly property string cache: Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`
}
