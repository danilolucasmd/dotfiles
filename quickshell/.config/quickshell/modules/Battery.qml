import Quickshell.Services.UPower
import qs
import qs.components

// UPower's display device, rather than waybar's own sysfs polling.
//
// One deliberate change: the waybar config never declared `states`, so the
// .warning / .critical rules in style.css could never fire. The thresholds
// those rules clearly intended (30% / 15%) are wired up here.
BarItem {
	id: root

	readonly property var battery: UPower.displayDevice
	readonly property bool present: battery?.isLaptopBattery ?? false
	readonly property int percent: Math.round((battery?.percentage ?? 0) * 100)
	readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.FullyCharged

	readonly property var icons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

	active: present
	rightMargin: Theme.gap

	tooltip: {
		if (!present)
			return "";
		const left = battery.timeToEmpty;
		const full = battery.timeToFull;
		if (charging && full > 0)
			return `${percent}% — ${Math.floor(full / 3600)}h ${Math.round(full % 3600 / 60)}m to full`;
		if (!charging && left > 0)
			return `${percent}% — ${Math.floor(left / 3600)}h ${Math.round(left % 3600 / 60)}m remaining`;
		return `${percent}%`;
	}

	BarText {
		font.pixelSize: Theme.fontIcon

		text: {
			if (root.charging)
				return `󰂄 ${root.percent}%`;
			const i = Math.min(9, Math.max(0, Math.floor(root.percent / 10)));
			return `${root.icons[i]} ${root.percent}%`;
		}

		color: {
			if (root.charging)
				return Theme.green;
			if (root.percent <= 15)
				return Theme.red;
			if (root.percent <= 30)
				return Theme.yellow;
			return Theme.fg;
		}
	}
}
