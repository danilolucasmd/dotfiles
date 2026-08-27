pragma Singleton

import Quickshell

Singleton {
	readonly property string home: Quickshell.env("HOME")
	readonly property string config: `${home}/.config/quickshell`
	readonly property string scripts: `${config}/scripts`
	// Images the shell draws that no icon theme has: a vendor's own mark, which
	// is not a symbolic icon and does not belong in one.
	readonly property string assets: `${config}/assets`
	// Generated data the shell reads but does not produce at runtime: the emoji
	// picker's Unicode dataset, rebuilt by scripts/gen-emoji-data.py.
	readonly property string dataDir: `${config}/data`
	readonly property string state: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
	readonly property string cache: Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`
}
