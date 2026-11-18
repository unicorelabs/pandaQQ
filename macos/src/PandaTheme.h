#pragma once
#import <Cocoa/Cocoa.h>

namespace PandaTheme {

inline NSColor* Background() {
    return [NSColor colorWithCalibratedRed:0.071f green:0.075f blue:0.086f alpha:1.0f]; // #121316
}

inline NSColor* Chassis() {
    return [NSColor colorWithCalibratedRed:0.102f green:0.110f blue:0.133f alpha:1.0f]; // #1A1C22
}

inline NSColor* CardBorder() {
    return [NSColor colorWithCalibratedRed:0.176f green:0.188f blue:0.227f alpha:1.0f]; // #2D303A
}

inline NSColor* Cyan() {
    return [NSColor colorWithCalibratedRed:0.000f green:0.824f blue:1.000f alpha:1.0f]; // #00D2FF
}

inline NSColor* Amber() {
    return [NSColor colorWithCalibratedRed:1.000f green:0.600f blue:0.000f alpha:1.0f]; // #FF9900
}

inline NSColor* Purple() {
    return [NSColor colorWithCalibratedRed:0.616f green:0.000f blue:1.000f alpha:1.0f]; // #9D00FF
}

inline NSColor* Red() {
    return [NSColor colorWithCalibratedRed:1.000f green:0.090f blue:0.267f alpha:1.0f]; // #FF1744
}

inline NSColor* Green() {
    return [NSColor colorWithCalibratedRed:0.000f green:0.902f blue:0.463f alpha:1.0f]; // #00E676
}

inline NSColor* Pink() {
    return [NSColor colorWithCalibratedRed:1.000f green:0.251f blue:0.506f alpha:1.0f]; // #FF4081
}

inline NSColor* TextMuted() {
    return [NSColor colorWithCalibratedRed:0.557f green:0.580f blue:0.627f alpha:1.0f]; // #8E94A0
}

} // namespace PandaTheme

