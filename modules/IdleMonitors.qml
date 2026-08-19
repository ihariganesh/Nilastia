pragma ComponentBehavior: Bound

import "lock"
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Nilastia.Config
import Nilastia.Services
import qs.services

Scope {
    id: root

    required property Lock lock
    readonly property bool hasPlayer: Players.list.some(p => p.isPlaying) || (Audio.streams && Audio.streams.some(s => s.ready && !s.audio?.muted))
    readonly property bool isCharging: !UPower.onBattery
    readonly property bool isGaming: GameMode.enabled || (function() {
        const top = Hypr.activeToplevel;
        const cls = (top?.lastIpcObject?.class || "").toLowerCase();
        const title = (top?.title || "").toLowerCase();

        // Direct check on active window class or title
        if (cls.includes("bottles") || cls.includes("wine") || cls.includes("steam") ||
            cls.includes("lutris") || cls.includes("heroic") || cls.includes("f1") ||
            cls.includes(".exe") || cls.includes("proton") || cls.includes("gamescope") ||
            title.includes(".exe") || title.includes("f1") || title.includes("formula 1") ||
            title.includes("bottles") || title.includes("wine") || title.includes("steam") ||
            title.includes("lutris") || title.includes("heroic")) {
            return true;
        }

        // Check all open windows across workspaces for active Wine/Bottles/games
        if (Hypr.toplevels && Hypr.toplevels.values) {
            for (let i = 0; i < Hypr.toplevels.values.length; i++) {
                const win = Hypr.toplevels.values[i];
                const wCls = (win?.lastIpcObject?.class || "").toLowerCase();
                const wTitle = (win?.title || "").toLowerCase();
                if (wCls.includes("bottles") || wCls.includes("wine") || wCls.includes("gamescope") ||
                    wCls.includes(".exe") || wTitle.includes(".exe") || wTitle.includes("f1 22") ||
                    wTitle.includes("f1 2022") || wTitle.includes("formula 1")) {
                    return true;
                }
            }
        }

        return false;
    })()

    readonly property bool enabled: {
        if (GlobalConfig.general.idle.inhibitWhenAudio && hasPlayer)
            return false;
        if (GlobalConfig.general.idle.inhibitWhenCharging && isCharging)
            return false;
        if (GlobalConfig.general.idle.inhibitWhenGaming && isGaming)
            return false;
        if (isGaming)
            return false; // Always inhibit idle when gaming is detected
        return true;
    }

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock") {
            lock.lock.locked = true;
        } else if (action === "unlock") {
            lock.lock.locked = false;
        } else if (action === "dpms off") {
            if (Hypr.niriAvailable) {
                Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
            } else {
                Quickshell.execDetached(["hyprctl", "dispatch", "dpms", "off"]);
            }
        } else if (action === "dpms on") {
            if (Hypr.niriAvailable) {
                Quickshell.execDetached(["niri", "msg", "action", "power-on-monitors"]);
            } else {
                Quickshell.execDetached(["hyprctl", "dispatch", "dpms", "on"]);
            }
        } else if (typeof action === "string") {
            Hypr.dispatch(Hypr.usingLua && ["dpms off", "dpms on"].includes(action) ? `hl.dsp.dpms({ action = "${action === "dpms off" ? "disable" : "enable"}" })` : action);
        } else if (!SessionManager.exec(action)) {
            Quickshell.execDetached(action);
        }
    }

    Connections {
        function onAboutToSleep(): void {
            if (GlobalConfig.general.idle.lockBeforeSleep)
                root.lock.lock.locked = true;
        }

        function onLockRequested(): void {
            root.lock.lock.locked = true;
        }

        function onUnlockRequested(): void {
            root.lock.lock.unlock();
        }

        target: SessionManager
    }

    Variants {
        model: GlobalConfig.general.idle.timeouts

        IdleMonitor {
            required property var modelData

            enabled: {
                if (!root.enabled || !(modelData.enabled ?? true) || (modelData.timeout === 0))
                    return false;
                if (modelData.inhibitWhenAudio && root.hasPlayer)
                    return false;
                if (modelData.inhibitWhenCharging && root.isCharging)
                    return false;
                if (modelData.inhibitWhenGaming && root.isGaming)
                    return false;
                return true;
            }
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
