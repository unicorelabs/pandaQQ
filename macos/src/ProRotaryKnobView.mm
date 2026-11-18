#import "ProRotaryKnobView.h"
#include <cmath>
#include <algorithm>

@interface ProRotaryKnobView () {
    NSPoint _lastMousePoint;
    BOOL _isDragging;
}
@end

@implementation ProRotaryKnobView

- (instancetype)initWithFrame:(NSRect)frame
                        label:(NSString*)label
                        isPan:(BOOL)isPan
                 initialValue:(float)val {
    self = [super initWithFrame:frame];
    if (self) {
        _label = [label copy];
        _isPan = isPan;
        _value = val;
        _isDragging = NO;
        [self updateDisplayString];
    }
    return self;
}

- (BOOL)isFlipped {
    return NO;
}

- (void)updateDisplayString {
    if (_isPan) {
        int panInt = (int)std::round(_value * 100.0f);
        if (panInt == 0) {
            _valueDisplayString = @"0";
        } else if (panInt < 0) {
            _valueDisplayString = [NSString stringWithFormat:@"L%d", -panInt];
        } else {
            _valueDisplayString = [NSString stringWithFormat:@"R%d", panInt];
        }
    } else {
        if (_value <= 0.02f) {
            _valueDisplayString = @"mati";
        } else {
            if ([_label containsString:@"HPF"]) {
                float hz = 20.0f + _value * 380.0f; // 20Hz - 400Hz
                _valueDisplayString = [NSString stringWithFormat:@"%.0fHz", hz];
            } else {
                float khz = 20.0f - (1.0f - _value) * 16.0f; // 4kHz - 20kHz
                _valueDisplayString = [NSString stringWithFormat:@"%.1fk", khz];
            }
        }
    }
}

- (void)setValue:(float)value {
    if (_isPan) {
        _value = std::clamp(value, -1.0f, 1.0f);
    } else {
        _value = std::clamp(value, 0.0f, 1.0f);
    }
    [self updateDisplayString];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = self.bounds;
    const CGFloat centerX = bounds.size.width * 0.5f;
    const CGFloat centerY = bounds.size.height * 0.5f;
    const CGFloat knobRadius = 12.0f;
    const CGFloat arcRadius = 15.0f;

    // 1. Label above
    NSMutableParagraphStyle* pStyle = [[NSMutableParagraphStyle alloc] init];
    pStyle.alignment = NSTextAlignmentCenter;
    NSDictionary* labelAttrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:8.0f],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.65f alpha:1.0f],
        NSParagraphStyleAttributeName: pStyle
    };
    [self.label drawInRect:NSMakeRect(0, bounds.size.height - 12.0f, bounds.size.width, 12.0f) withAttributes:labelAttrs];

    // 2. Background Arc Track (270 degrees total: -135 to +135 deg)
    // Angles in AppKit: 0 = 3 o'clock, 90 = 12 o'clock, 180 = 9 o'clock, 270 = 6 o'clock
    const CGFloat startAngle = 225.0f;
    const CGFloat endAngle = -45.0f;

    NSBezierPath* trackPath = [NSBezierPath bezierPath];
    [trackPath appendBezierPathWithArcWithCenter:NSMakePoint(centerX, centerY)
                                          radius:arcRadius
                                      startAngle:startAngle
                                        endAngle:endAngle
                                       clockwise:YES];
    [[NSColor colorWithCalibratedWhite:0.20f alpha:1.0f] setStroke];
    trackPath.lineWidth = 2.0f;
    [trackPath stroke];

    // 3. Active Colored Arc
    if (_isPan) {
        // Pan arc from 90 degrees (12 o'clock)
        CGFloat currentAngle = 90.0f - (_value * 135.0f);
        if (std::abs(_value) > 0.02f) {
            NSBezierPath* activeArc = [NSBezierPath bezierPath];
            [activeArc appendBezierPathWithArcWithCenter:NSMakePoint(centerX, centerY)
                                                  radius:arcRadius
                                              startAngle:90.0f
                                                endAngle:currentAngle
                                               clockwise:(_value > 0)];
            [[NSColor colorWithCalibratedRed:0.0f green:0.85f blue:0.45f alpha:1.0f] setStroke];
            activeArc.lineWidth = 2.5f;
            [activeArc stroke];
        }
    } else {
        if (_value > 0.02f) {
            CGFloat currentAngle = 225.0f - (_value * 270.0f);
            NSBezierPath* activeArc = [NSBezierPath bezierPath];
            [activeArc appendBezierPathWithArcWithCenter:NSMakePoint(centerX, centerY)
                                                  radius:arcRadius
                                              startAngle:startAngle
                                                endAngle:currentAngle
                                               clockwise:YES];
            [[NSColor colorWithCalibratedRed:0.0f green:0.82f blue:0.95f alpha:1.0f] setStroke];
            activeArc.lineWidth = 2.0f;
            [activeArc stroke];
        }
    }

    // 4. Metallic Knob Body
    NSRect knobRect = NSMakeRect(centerX - knobRadius, centerY - knobRadius, knobRadius * 2.0f, knobRadius * 2.0f);
    NSBezierPath* knobPath = [NSBezierPath bezierPathWithOvalInRect:knobRect];
    NSGradient* knobGrad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.28f alpha:1.0f]
                                                         endingColor:[NSColor colorWithCalibratedWhite:0.12f alpha:1.0f]];
    [knobGrad drawInBezierPath:knobPath angle:-45.0f];
    [[NSColor colorWithCalibratedWhite:0.35f alpha:1.0f] setStroke];
    knobPath.lineWidth = 1.0f;
    [knobPath stroke];

    // 5. White Indicator Notch Line
    CGFloat angleDeg;
    if (_isPan) {
        angleDeg = 90.0f - (_value * 135.0f);
    } else {
        angleDeg = 225.0f - (_value * 270.0f);
    }
    CGFloat angleRad = angleDeg * (M_PI / 180.0f);

    NSPoint pInner = NSMakePoint(centerX + std::cos(angleRad) * 4.0f, centerY + std::sin(angleRad) * 4.0f);
    NSPoint pOuter = NSMakePoint(centerX + std::cos(angleRad) * (knobRadius - 1.5f), centerY + std::sin(angleRad) * (knobRadius - 1.5f));

    [[NSColor whiteColor] setStroke];
    [NSBezierPath setDefaultLineWidth:1.5f];
    [NSBezierPath strokeLineFromPoint:pInner toPoint:pOuter];

    // 6. Value Readout Text Below
    NSDictionary* valAttrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:7.5f weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: (_isPan && std::abs(_value) > 0.02f) ? [NSColor colorWithCalibratedRed:0.0f green:0.85f blue:0.45f alpha:1.0f] : [NSColor colorWithCalibratedWhite:0.55f alpha:1.0f],
        NSParagraphStyleAttributeName: pStyle
    };
    [self.valueDisplayString drawInRect:NSMakeRect(0, 0, bounds.size.width, 11.0f) withAttributes:valAttrs];
}

- (void)mouseDown:(NSEvent *)event {
    if (event.clickCount == 2) {
        self.value = 0.0f;
        if (self.onValueChanged) self.onValueChanged(self.value);
        return;
    }
    _isDragging = YES;
    _lastMousePoint = [self convertPoint:event.locationInWindow fromView:nil];
}

- (void)mouseDragged:(NSEvent *)event {
    if (!_isDragging) return;
    NSPoint current = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat deltaY = current.y - _lastMousePoint.y;
    _lastMousePoint = current;

    CGFloat step = (([event modifierFlags] & NSEventModifierFlagShift) != 0) ? 0.002f : 0.015f;
    float newVal = self.value + deltaY * step;
    self.value = newVal;

    if (self.onValueChanged) {
        self.onValueChanged(self.value);
    }
}

- (void)mouseUp:(NSEvent *)event {
    _isDragging = NO;
    (void)event;
}

@end
