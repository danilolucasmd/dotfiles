import QtQuick
import QtQuick.Layouts
import qs

// Hairline marking where the folded-away modules end and the ones that are
// always on screen begin.
Rectangle {
	Layout.alignment: Qt.AlignVCenter

	implicitWidth: 1
	implicitHeight: 14
	color: Theme.line
}
