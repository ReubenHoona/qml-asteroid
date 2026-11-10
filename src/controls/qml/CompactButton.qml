/*
 * Copyright (C) 2026 Reuben Horner
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 2.1 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import org.asteroid.controls

/*!
    \qmltype CompactButton
    \inqmlmodule org.asteroid.controls

    \brief The Wear OS compact button: a 32 dp pill in a 48 dp touch area.

    Stock (CompactButtonTokens.java:9-10, E04): container 32 dp tall
    (CornerLarge, so a pill), 12 dp side padding, label labelMedium, icon
    20 dp; with an icon and no label it is 52 dp wide with a 24 dp icon. The
    touch area is 48 dp tall. Colours follow \c variant as \l Button
    (filled by default).
*/
Button {
    id: compact

    readonly property bool _iconOnly: text === "" && iconName !== ""

    containerHeight: Theme.dp(32)
    minimumHeight: Theme.size.touchMin
    horizontalPadding: _iconOnly ? 0 : Theme.space.l
    verticalPadding: 0
    iconSize: _iconOnly ? Theme.size.iconSmall : Theme.dp(20)
    centered: true
    maximumLineCount: 1
    implicitHeight: Theme.size.touchMin
    implicitWidth: _iconOnly ? Theme.dp(52) : Math.max(Theme.dp(52), label.implicitWidth + 2 * horizontalPadding
                                                       + (iconName !== "" ? iconSize + iconSpacing : 0))
}
