pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

// What the machine is doing: processor, graphics, memory, disk.
//
// A singleton for the reason the other panels have one — the panel is a window
// of its own rather than a child of the bar module, and super+shift+P can
// summon it without the bar being involved at all.
//
// Everything comes from one script (scripts/system-stats.sh) rather than from
// a service: there is no D-Bus daemon that knows all four of these, and the
// files that do know are in /proc and /sys, which a shell reads faster than
// anything else could.
//
// Rates and percentages are worked out here rather than in the script.
// /proc/stat and /proc/diskstats are cumulative since boot, so "23% busy" is a
// difference between two readings; holding the previous sample and dividing
// costs nothing, where measuring in the script would mean sleeping a second
// inside every poll.
Singleton {
	id: root

	property bool panelOpen: false

	readonly property var stats: statsScript.data

	// ------------------------------------------------------------------
	// Thresholds
	//
	// Two numbers per subsystem: where it goes amber, and where it goes red.
	// Temperatures are the interesting ones. This i5-9600K reports high at
	// 84°C and critical at 100°C, and Ampere begins pulling clocks back around
	// 83°C, so amber lands a little below each and red at the point where the
	// chip is already defending itself.
	// ------------------------------------------------------------------

	readonly property int cpuTempWarm: 80
	readonly property int cpuTempHot: 90
	readonly property int gpuTempWarm: 75
	readonly property int gpuTempHot: 85
	// A filesystem is not in trouble at 80% — it is in trouble when what is
	// left stops being enough for an update or a large build.
	readonly property int diskWarm: 90
	readonly property int diskHot: 97
	readonly property int memWarm: 85
	readonly property int memHot: 95
	// Saturation, not business. A pegged core is what a compile looks like and
	// is never red; it earns amber only so that a glance at the bar can tell a
	// busy machine from an idle one.
	readonly property int loadWarm: 95

	// ------------------------------------------------------------------
	// Derived from two samples
	// ------------------------------------------------------------------

	property var lastSample: null

	// 0..100. Zero until a second reading has arrived, which is one interval
	// after the shell starts and not again.
	property real cpuUsage: 0
	property var coreUsage: []
	property real diskRead: 0
	property real diskWrite: 0
	// The share of the interval the drive's queue was not empty. Different
	// from throughput: a drive can be pinned at 100% busy serving a trickle of
	// small random reads.
	property real diskBusy: 0

	// ------------------------------------------------------------------
	// Straight readings
	// ------------------------------------------------------------------

	readonly property var cpu: stats.cpu ?? ({})
	readonly property var gpu: stats.gpu ?? null
	readonly property var mem: stats.mem ?? ({})
	readonly property var disk: stats.disk ?? ({})

	readonly property bool available: stats.cpu !== undefined
	readonly property bool gpuPresent: gpu !== null && gpu !== undefined

	// The marketing name without the marketing: "Intel(R) Core(TM) i5-9600K
	// CPU @ 3.70GHz" is the whole card wide, and the clock in it is the base
	// one, which is the least interesting number on this panel. AMD spells the
	// same padding differently ("... 8-Core Processor"), and the core count it
	// tacks on is already a bar per core on the strip.
	readonly property string cpuName: (cpu.model ?? "").replace(/\((R|TM)\)/g, "").replace(/ (CPU )?@.*$/, "").replace(/ \d+-Core Processor$/, "").replace(/\s+/g, " ").trim()

	// Used is total minus *available*, not minus free: on a machine with 11 GiB
	// of page cache, free says 15 GiB and available says 26, and only one of
	// those is what a new allocation could actually have.
	readonly property real memUsed: (mem.total ?? 0) - (mem.available ?? 0)
	readonly property real memPercent: mem.total > 0 ? memUsed / mem.total * 100 : 0
	readonly property real swapUsed: (mem.swapTotal ?? 0) - (mem.swapFree ?? 0)

	readonly property real diskPercent: disk.size > 0 ? disk.used / disk.size * 100 : 0

	readonly property real gpuMemPercent: gpu?.memTotal > 0 ? gpu.memUsed / gpu.memTotal * 100 : 0

	// ------------------------------------------------------------------
	// Pressure
	//
	// What the bar glyph colours on. Deliberately not the same thing as the
	// panel's meters: a meter is asking "how much of this is in use", and this
	// is asking "is anything wrong". Heat and a filesystem running out are
	// wrong; a busy processor is a processor doing its job, so load can raise
	// this to amber but never to red.
	// ------------------------------------------------------------------

	readonly property int pressure: Math.max(cpuPressure, gpuPressure, memPressure, diskPressure)

	readonly property int cpuPressure: Math.max(level(cpu.temp ?? 0, cpuTempWarm, cpuTempHot), cpuUsage >= loadWarm ? 1 : 0)
	readonly property int gpuPressure: gpuPresent ? Math.max(level(gpu.temp ?? 0, gpuTempWarm, gpuTempHot), (gpu.util ?? 0) >= loadWarm ? 1 : 0) : 0
	readonly property int memPressure: level(memPercent, memWarm, memHot)
	readonly property int diskPressure: level(diskPercent, diskWarm, diskHot)

	function level(value: real, warm: real, hot: real): int {
		if (value >= hot)
			return 2;
		if (value >= warm)
			return 1;
		return 0;
	}

	function toggle(): void {
		panelOpen = !panelOpen;
		if (panelOpen)
			statsScript.refresh();
	}

	function close(): void {
		panelOpen = false;
		// A run left behind a closed panel would keep the drive busy for
		// several more seconds with nothing on screen to read it.
		stopDiskTest();
	}

	function refresh(): void {
		statsScript.refresh();
	}

	// ------------------------------------------------------------------
	// Disk speed test
	//
	// The one figure on this panel that cannot be watched. The read and write
	// rates above are what the machine happens to be doing, which on an idle
	// desktop is nothing whatever the drive is worth, and `busy` is a share of
	// an interval rather than a speed. Finding out how fast the drive is means
	// making it go as fast as it can — so this is a measurement someone asks
	// for, on `d`, and never a poll: a run writes two gigabytes and reads them
	// back, which is the drive's whole attention for a few seconds and real
	// wear on it.
	//
	// The script prints a line per pass and each line is the whole reading, so
	// the newest one replaces the state rather than being merged into it.
	// ------------------------------------------------------------------

	property var diskTestResult: ({})
	property bool diskTestRunning: false

	// Which of prepare / write / read is being measured, "done" once the script
	// has printed its last line, and "" before the first run.
	readonly property string diskTestPhase: diskTestResult.phase ?? ""
	// How far through that phase the script has got, 0..1. Passes done rather
	// than a clock: the phases are bounded by how much they move, not by how
	// long they take, so on a fast drive the bar is simply over sooner.
	readonly property real diskTestProgress: diskTestResult.progress ?? 0
	readonly property real diskTestRead: diskTestResult.read ?? 0
	readonly property real diskTestWrite: diskTestResult.write ?? 0
	// What each phase moves. Printed before a run is asked for, because it is
	// the whole decision on a drive with a write budget worth thinking about.
	readonly property real diskTestBytes: diskTestResult.bytes ?? 0
	// The drive the test actually landed on, and where it is mounted. Worth
	// printing: the test writes into the cache directory, which on a machine
	// with a separate home is not the drive metered above.
	readonly property string diskTestDevice: diskTestResult.device ?? ""
	readonly property string diskTestMount: diskTestResult.mount ?? ""
	readonly property string diskTestError: diskTestResult.error ?? ""

	function startDiskTest(): void {
		if (diskTestRunning)
			return;
		// Last run's numbers go with it: they were measured on whatever the
		// drive was doing then, and leaving them up while the new run works
		// would read as progress that has not happened.
		diskTestResult = {};
		diskTestRunning = true;
		diskTestProcess.running = true;
	}

	function stopDiskTest(): void {
		if (diskTestRunning)
			diskTestProcess.running = false;
	}

	function toggleDiskTest(): void {
		if (diskTestRunning)
			stopDiskTest();
		else
			startDiskTest();
	}

	// ------------------------------------------------------------------
	// Sampling
	// ------------------------------------------------------------------

	function sample(d: var): void {
		if (!d || !d.cpu)
			return;

		const prev = lastSample;
		// A reading older than the one held, or one taken across a counter
		// reset, is not something to divide by.
		if (prev && d.t > prev.t) {
			const dt = d.t - prev.t;

			cpuUsage = busy(prev.cpu.total, d.cpu.total);

			const n = Math.min(prev.cpu.cores.length, d.cpu.cores.length);
			const per = [];
			for (let i = 0; i < n; i++)
				per.push(busy(prev.cpu.cores[i], d.cpu.cores[i]));
			coreUsage = per;

			const a = prev.disk?.counters;
			const b = d.disk?.counters;
			// Counters only ever climb; a drop means the device was renamed or
			// the machine resumed onto different hardware, and the difference
			// would be nonsense.
			if (a && b && b.read >= a.read && b.written >= a.written && b.ioMs >= a.ioMs) {
				diskRead = (b.read - a.read) / dt;
				diskWrite = (b.written - a.written) / dt;
				// ioMs is milliseconds against an interval in seconds. Clamped:
				// a drive serving several requests at once can accumulate more
				// busy time than wall time.
				diskBusy = Math.min(100, (b.ioMs - a.ioMs) / (dt * 1000) * 100);
			}
		}
		lastSample = d;
	}

	// The share of a jiffy window that was not idle, as 0..100.
	function busy(a: var, b: var): real {
		const total = b.total - a.total;
		const idle = b.idle - a.idle;
		if (!(total > 0))
			return 0;
		return Math.max(0, Math.min(100, (total - idle) / total * 100));
	}

	// ------------------------------------------------------------------
	// Formatting
	// ------------------------------------------------------------------

	// Binary units with the labels that actually mean them. The network panel
	// next door says "GB" for the same 1024-based figure, which is the older
	// convention; this panel prints capacities a manufacturer and a BIOS both
	// quote in GiB, so it spells them that way rather than being wrong in a
	// familiar direction.
	function formatBytes(bytes: real, decimals: int): string {
		if (!(bytes > 0))
			return "0 B";
		const units = ["B", "KiB", "MiB", "GiB", "TiB"];
		let i = 0;
		let n = bytes;
		while (n >= 1024 && i < units.length - 1) {
			n /= 1024;
			i++;
		}
		return `${n.toFixed(i === 0 ? 0 : decimals)} ${units[i]}`;
	}

	function formatRate(bytesPerSecond: real): string {
		return `${formatBytes(bytesPerSecond, 1)}/s`;
	}

	// The speed test's figures, in decimal megabytes, which is the unit a drive
	// is sold in — the box says 2100 MB/s and means 2.1e9. Everything else on
	// this panel is binary because it is describing capacity, where GiB is what
	// the BIOS and the filesystem both say; this one line is describing a
	// throughput that has a number on a box to be compared against, and
	// printing it in MiB/s would be quietly 5% short of it.
	//
	// MB/s the whole way up rather than rolling over to GB/s past a thousand,
	// because every disk benchmark there is — CrystalDiskMark, KDiskMark,
	// gnome-disks — prints four figures of MB/s and so does the box. "1790 MB/s"
	// is the number a drive gets compared against; "1.79 GB/s" is the same
	// measurement in a unit nobody quotes it in.
	function formatDiskSpeed(bytesPerSecond: real): string {
		if (!(bytesPerSecond > 0))
			return "—";
		return `${Math.round(bytesPerSecond / 1000000)} MB/s`;
	}

	// MHz in, "3.60 GHz" or "800 MHz" out. Under a gigahertz is a parked core,
	// and printing that as "0.80 GHz" hides the leading digit that says so.
	function formatFreq(mhz: real): string {
		if (!(mhz > 0))
			return "";
		return mhz >= 1000 ? `${(mhz / 1000).toFixed(2)} GHz` : `${Math.round(mhz)} MHz`;
	}

	function formatTemp(celsius: real): string {
		return celsius > 0 ? `${Math.round(celsius)}°C` : "";
	}

	// "3d 14h", "14h 22m", "22m". Two units is as much as the header line has
	// room for, and the third would be noise on any of them.
	function formatUptime(seconds: int): string {
		if (!(seconds > 0))
			return "";
		const d = Math.floor(seconds / 86400);
		const h = Math.floor(seconds % 86400 / 3600);
		const m = Math.floor(seconds % 3600 / 60);
		if (d > 0)
			return `${d}d ${h}h`;
		if (h > 0)
			return `${h}h ${m}m`;
		return `${m}m`;
	}

	// Not a JsonScript: that one collects the whole output and parses it once
	// at exit, and this script's point is the lines it prints on the way — a
	// blank panel for the length of a run is indistinguishable from a hang.
	Process {
		id: diskTestProcess

		command: [`${Paths.scripts}/disktest.sh`]

		stdout: SplitParser {
			onRead: line => {
				try {
					root.diskTestResult = JSON.parse(line);
				} catch (e) {
					// A half-written line is not worth blanking the panel over;
					// the next one carries the same state again.
				}
			}
		}

		// Covers the cancelled run as well as the finished one: stopping the
		// process is what `d` and closing the panel both do.
		onExited: root.diskTestRunning = false
	}

	JsonScript {
		id: statsScript

		command: [`${Paths.scripts}/system-stats.sh`]
		// The bar glyph needs a reading whether the panel is up or not, so this
		// never stops — it just slows down to a rate suited to watching for
		// something going wrong rather than to watching a graph move.
		intervalMs: root.panelOpen ? 1000 : 5000

		onDataChanged: root.sample(data)
	}
}
