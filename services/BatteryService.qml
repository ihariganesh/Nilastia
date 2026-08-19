pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    property int percentage: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)
    property string status: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice?.state) ? "Charging" : "Discharging"
    property bool isCharging: status === "Charging" || status === "Full"
    property bool isLaptopBattery: UPower.displayDevice?.isLaptopBattery ?? true

    readonly property real normalizedPercentage: percentage / 100.0

    // High-precision zero-latency sysfs monitoring timer (polls every 3 seconds)
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batCapFile.reload();
            batStatusFile.reload();
        }
    }

    FileView {
        id: batCapFile
        path: "/sys/class/power_supply/BAT1/capacity"
        printErrors: false
        onLoaded: {
            const cap = parseInt(text().trim());
            if (!isNaN(cap)) {
                root.percentage = cap;
            }
        }
    }

    FileView {
        id: batCapFile0
        path: "/sys/class/power_supply/BAT0/capacity"
        printErrors: false
        onLoaded: {
            const cap = parseInt(text().trim());
            if (!isNaN(cap)) {
                root.percentage = cap;
            }
        }
    }

    FileView {
        id: batStatusFile
        path: "/sys/class/power_supply/BAT1/status"
        printErrors: false
        onLoaded: {
            const st = text().trim();
            if (st) {
                root.status = st;
                root.isCharging = (st === "Charging" || st === "Full");
            }
        }
    }

    FileView {
        id: batStatusFile0
        path: "/sys/class/power_supply/BAT0/status"
        printErrors: false
        onLoaded: {
            const st = text().trim();
            if (st) {
                root.status = st;
                root.isCharging = (st === "Charging" || st === "Full");
            }
        }
    }
}
