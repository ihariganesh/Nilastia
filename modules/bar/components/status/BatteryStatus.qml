import QtQuick
import Quickshell.Services.UPower
import Nilastia.Services
import qs.components
import qs.services
import qs.utils

MaterialIcon {
    required property color colour

    animate: true
    text: {
        if (!BatteryService.isLaptopBattery) {
            if (PowerProfiles.profile === PowerProfile.PowerSaver)
                return "energy_savings_leaf";
            if (PowerProfiles.profile === PowerProfile.Performance)
                return "rocket_launch";
            return "balance";
        }
        return Icons.getBatteryIcon(BatteryService.normalizedPercentage, BatteryService.isCharging);
    }
    color: BatteryService.isCharging || BatteryService.normalizedPercentage > 0.2 ? colour : Colours.palette.m3error
    fill: 1
}
