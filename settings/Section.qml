// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// Small uppercase heading that groups a few settings on a page.
StyledText {
    Layout.fillWidth: true
    Layout.topMargin: Theme.space.s
    font.pixelSize: Theme.font.small
    font.weight: Font.DemiBold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.6
    color: Theme.fgMuted
}
