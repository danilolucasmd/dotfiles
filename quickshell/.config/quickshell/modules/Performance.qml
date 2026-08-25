import qs
import qs.components

// Whether the machine is in trouble.
//
// One glyph and no numbers, the way Network and Battery ended up: a percentage
// in the always-visible cluster is a number you have to read, and the whole
// point of this seat in the bar is that you should not have to read anything
// unless it has changed colour. The figures are one click away.
//
// What it colours on is pressure rather than usage -- see PerformanceState.
// A compile pinning all six cores turns this amber, because a saturated
// machine is worth knowing about; only heat and a filesystem running out turn
// it red, because those are the two that do not resolve themselves.
BarItem {
	id: root

	rightMargin: Theme.gap

	tooltip: {
		if (!PerformanceState.available)
			return "No reading yet";

		const s = PerformanceState;
		const lines = [];

		const cpuTemp = s.formatTemp(s.cpu.temp ?? 0);
		lines.push(`CPU  ${Math.round(s.cpuUsage)}%${cpuTemp ? ` · ${cpuTemp}` : ""} · ${s.formatFreq(s.cpu.freq ?? 0)}`);

		if (s.gpuPresent) {
			const gpuTemp = s.formatTemp(s.gpu.temp ?? 0);
			lines.push(`GPU  ${Math.round(s.gpu.util ?? 0)}%${gpuTemp ? ` · ${gpuTemp}` : ""}`);
		}

		lines.push(`RAM  ${Math.round(s.memPercent)}% · ${s.formatBytes(s.memUsed, 1)} of ${s.formatBytes(s.mem.total ?? 0, 1)}`);
		lines.push(`Disk ${Math.round(s.diskPercent)}% · ${s.formatBytes((s.disk.size ?? 0) - (s.disk.used ?? 0), 0)} free`);

		return lines.join("\n");
	}

	onClicked: PerformanceState.toggle()

	BarText {
		text: "󰍛"
		color: PerformanceState.pressure >= 2 ? Theme.red : PerformanceState.pressure >= 1 ? Theme.yellow : Theme.fg
		// md-memory sits small on its em box, so it reads a step under the
		// other bar icons at the shared 16px. Nudged up locally rather than
		// moving Theme.fontIcon, which every other module rides on.
		font.pixelSize: Theme.fontIcon + 2
	}
}
