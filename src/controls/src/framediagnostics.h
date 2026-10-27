/*
 * Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef FRAMEDIAGNOSTICS_H
#define FRAMEDIAGNOSTICS_H

#include <QObject>

/*
 * Why does this screen draw? A debugging aid for "no frame on a static
 * screen" and "no frame over 16.7 ms", off unless its logging category is
 * enabled:
 *   QT_LOGGING_RULES="asteroid.frames.debug=true" <application>
 * (for the launcher: a systemd user drop-in with that Environment= line).
 *
 * For every frame of every Qt Quick window of the process it logs one line:
 *   frame <n> +<ms since the previous frame> gui <ms> sync <ms> render <ms>
 *     dirty <count>: <class>#<qml id>@<file>:<line> [<what changed>] ...
 * "gui" is the user interface thread's work for the frame (animations,
 * bindings, layout: from the end of the animation step to the start of the
 * sync), "sync" the copy into the scene graph, "render" until the frame is
 * handed to the display. The dirty items are what asked for the frame; a
 * frame with no dirty item comes from a running animation or an explicit
 * update(). Only the first 10 items are named.
 * The cost is a few clock reads per frame and walking the dirty list.
 */
class FrameDiagnostics : public QObject
{
    Q_OBJECT
public:
    /* Installs itself on the application when its category is enabled */
    static void install();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    explicit FrameDiagnostics(QObject *parent);
};

#endif // FRAMEDIAGNOSTICS_H
