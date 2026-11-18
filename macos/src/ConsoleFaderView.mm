#import "ConsoleFaderView.h"
#import "PandaTheme.h"

@interface ConsoleFaderView () {
    BOOL _isDragging;
    CGFloat _dragStartY;
    float _dragStartDb;
}
@end

@implementation ConsoleFaderView

- (instancetype)initWithFrame:(NSRect)frame
                  channelName:(NSString*)name
                  accentColor:(NSColor*)color
                      initialDb:(float)db {
    self = [super initWithFrame:frame];
    if (self) {
        _channelName = [name copy];
        _accentColor = color ? color : PandaTheme::Cyan();
        _volumeDb = db;
        _meterDb = -96.0f;
        _isMuted = NO;
        _isSoloed = NO;
        _isDragging = NO;
        self.wantsLayer = YES;
    }
    return self;
}

- (BOOL)isFlipped {
    return NO;
}

// Convert dB (-48 .. +6) to normalized position t (0.0 .. 1.0) with unity gain (0dB) at t = 0.75
- (CGFloat)normalizedPositionFromDb:(float)db {
    if (db <= -48.0f) return 0.0f;
    if (db >= 6.0f) return 1.0f;
    if (db <= 0.0f) {
        return 0.75f * (1.0f + db / 48.0f);
    } else {
        return 0.75f + 0.25f * (db / 6.0f);
    }
}

// Convert normalized position t (0.0 .. 1.0) to dB (-48 .. +6)
- (float)dbFromNormalizedPosition:(CGFloat)t {
    if (t <= 0.0f) return -48.0f;
    if (t >= 1.0f) return 6.0f;
    if (t <= 0.75f) {
        return -48.0f * (1.0f - (float)(t / 0.75f));
    } else {
        return 6.0f * (float)((t - 0.75f) / 0.25f);
    }
}

- (CGFloat)trackBottomY {
    return 86.0f;
}

- (CGFloat)trackTopY {
    return self.bounds.size.height - 52.0f;
}

- (CGFloat)trackHeight {
    return [self trackTopY] - [self trackBottomY];
}

- (NSRect)soloButtonRect {
    return NSMakeRect(12.0f, 50.0f, 44.0f, 22.0f);
}

- (NSRect)muteButtonRect {
    return NSMakeRect(62.0f, 50.0f, 44.0f, 22.0f);
}

- (void)updateMeterDb:(float)meterDb {
    _meterDb = meterDb;
    [self setNeedsDisplay:YES];
}

- (void)setVolumeDb:(float)volumeDb {
    _volumeDb = volumeDb;
    [self setNeedsDisplay:YES];
}

// ========================================================
// CUSTOM DRAWING: AUTHENTIC STUDIO HARDWARE CONSOLE STRIP
// ========================================================
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = self.bounds;
    const CGFloat trackBottom = [self trackBottomY];
    const CGFloat trackHeight = [self trackHeight];
    const CGFloat slotCenterX = 48.0f;
    const CGFloat meterX = 72.0f;
    const CGFloat meterWidth = 14.0f;

    // 1. Channel Chassis Background
    NSRect chassisRect = NSInsetRect(bounds, 1.5f, 1.5f);
    NSBezierPath* chassisPath = [NSBezierPath bezierPathWithRoundedRect:chassisRect xRadius:8.0f yRadius:8.0f];
    [[NSColor colorWithCalibratedRed:0.085f green:0.092f blue:0.105f alpha:1.0f] setFill];
    [chassisPath fill];
    [[NSColor colorWithCalibratedWhite:0.20f alpha:1.0f] setStroke];
    chassisPath.lineWidth = 1.0f;
    [chassisPath stroke];

    // 2. Channel Header Pill Badge
    NSRect headerRect = NSMakeRect(8.0f, bounds.size.height - 38.0f, bounds.size.width - 16.0f, 26.0f);
    NSBezierPath* headerPath = [NSBezierPath bezierPathWithRoundedRect:headerRect xRadius:5.0f yRadius:5.0f];
    [[NSColor colorWithCalibratedWhite:0.13f alpha:1.0f] setFill];
    [headerPath fill];
    [[self.accentColor colorWithAlphaComponent:0.65f] setStroke];
    headerPath.lineWidth = 1.5f;
    [headerPath stroke];

    NSMutableParagraphStyle* centerStyle = [[NSMutableParagraphStyle alloc] init];
    centerStyle.alignment = NSTextAlignmentCenter;
    NSDictionary* headerAttrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor whiteColor],
        NSParagraphStyleAttributeName: centerStyle
    };
    [self.channelName drawInRect:NSMakeRect(headerRect.origin.x, headerRect.origin.y + 4.0f, headerRect.size.width, 18.0f)
                 withAttributes:headerAttrs];

    // 3. Fader Slot (Deep Recessed Groove)
    NSRect slotRect = NSMakeRect(slotCenterX - 3.0f, trackBottom, 6.0f, trackHeight);
    NSBezierPath* slotPath = [NSBezierPath bezierPathWithRoundedRect:slotRect xRadius:3.0f yRadius:3.0f];
    [[NSColor colorWithCalibratedRed:0.03f green:0.035f blue:0.04f alpha:1.0f] setFill];
    [slotPath fill];
    [[NSColor colorWithCalibratedWhite:0.18f alpha:1.0f] setStroke];
    slotPath.lineWidth = 1.0f;
    [slotPath stroke];

    // Silver guide rail in slot center
    [[NSColor colorWithCalibratedWhite:0.45f alpha:0.40f] setStroke];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(slotCenterX, trackBottom + 4.0f)
                              toPoint:NSMakePoint(slotCenterX, trackBottom + trackHeight - 4.0f)];

    // 4. Calibration Tick Marks & dB Numbers
    NSDictionary* tickAttrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:8.0f weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.65f alpha:1.0f]
    };
    NSDictionary* unityAttrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:8.5f weight:NSFontWeightBold],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };

    struct ScaleMark { float db; const char* label; };
    const ScaleMark marks[] = {
        {  6.0f, "+6" },
        {  3.0f, "+3" },
        {  0.0f, "0"  },
        { -5.0f, "-5" },
        {-10.0f, "-10"},
        {-15.0f, "-15"},
        {-20.0f, "-20"},
        {-30.0f, "-30"},
        {-40.0f, "-40"},
        {-48.0f, "-∞" }
    };

    for (size_t i = 0; i < sizeof(marks) / sizeof(marks[0]); ++i) {
        CGFloat t = [self normalizedPositionFromDb:marks[i].db];
        CGFloat markY = trackBottom + t * trackHeight;

        if (marks[i].db == 0.0f) {
            // Bold Unity 0dB mark line across slot
            [[self.accentColor colorWithAlphaComponent:0.9f] setStroke];
            [NSBezierPath setDefaultLineWidth:1.5f];
            [NSBezierPath strokeLineFromPoint:NSMakePoint(26.0f, markY)
                                      toPoint:NSMakePoint(slotCenterX + 8.0f, markY)];
            NSString* str = [NSString stringWithUTF8String:marks[i].label];
            [str drawInRect:NSMakeRect(8.0f, markY - 5.5f, 16.0f, 12.0f) withAttributes:unityAttrs];
        } else {
            [[NSColor colorWithCalibratedWhite:0.35f alpha:1.0f] setStroke];
            [NSBezierPath setDefaultLineWidth:1.0f];
            [NSBezierPath strokeLineFromPoint:NSMakePoint(32.0f, markY)
                                      toPoint:NSMakePoint(39.0f, markY)];
            NSString* str = [NSString stringWithUTF8String:marks[i].label];
            [str drawInRect:NSMakeRect(6.0f, markY - 5.5f, 24.0f, 12.0f) withAttributes:tickAttrs];
        }
    }

    // 5. 24-Segment Hardware LED Meter
    NSRect meterCasing = NSMakeRect(meterX, trackBottom, meterWidth, trackHeight);
    NSBezierPath* casingPath = [NSBezierPath bezierPathWithRoundedRect:meterCasing xRadius:2.0f yRadius:2.0f];
    [[NSColor colorWithCalibratedRed:0.04f green:0.045f blue:0.055f alpha:1.0f] setFill];
    [casingPath fill];
    [[NSColor colorWithCalibratedWhite:0.18f alpha:1.0f] setStroke];
    casingPath.lineWidth = 1.0f;
    [casingPath stroke];

    const int totalSegments = 24;
    const CGFloat segGap = 1.5f;
    const CGFloat segHeight = (trackHeight - (totalSegments + 1) * segGap) / totalSegments;

    float normMeter = (self.meterDb + 60.0f) / 60.0f;
    if (normMeter < 0.0f) normMeter = 0.0f;
    if (normMeter > 1.0f) normMeter = 1.0f;
    int litCount = (int)(normMeter * totalSegments);

    for (int i = 0; i < totalSegments; ++i) {
        CGFloat sy = trackBottom + segGap + i * (segHeight + segGap);
        NSRect segRect = NSMakeRect(meterX + 2.0f, sy, meterWidth - 4.0f, segHeight);

        NSColor* baseColor;
        if (i >= 21) {
            baseColor = [NSColor colorWithCalibratedRed:1.0f green:0.15f blue:0.25f alpha:1.0f]; // Red (Peak)
        } else if (i >= 15) {
            baseColor = [NSColor colorWithCalibratedRed:1.0f green:0.65f blue:0.0f alpha:1.0f];  // Amber
        } else {
            baseColor = [NSColor colorWithCalibratedRed:0.0f green:0.90f blue:0.45f alpha:1.0f];  // Green
        }

        if (i < litCount) {
            [baseColor setFill];
        } else {
            [[baseColor colorWithAlphaComponent:0.12f] setFill]; // Unlit glass persistence
        }
        NSRectFill(segRect);
    }

    // 6. Sculpted 3D Console Fader Cap (The Knob)
    CGFloat currentT = [self normalizedPositionFromDb:self.volumeDb];
    CGFloat knobCenterY = trackBottom + currentT * trackHeight;
    const CGFloat knobW = 34.0f;
    const CGFloat knobH = 48.0f;
    NSRect knobRect = NSMakeRect(slotCenterX - knobW * 0.5f, knobCenterY - knobH * 0.5f, knobW, knobH);

    // Drop Shadow for Fader Cap
    [NSGraphicsContext saveGraphicsState];
    NSShadow* shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0f alpha:0.65f];
    shadow.shadowOffset = NSMakeSize(0.0f, -3.0f);
    shadow.shadowBlurRadius = 6.0f;
    [shadow set];

    NSBezierPath* knobPath = [NSBezierPath bezierPathWithRoundedRect:knobRect xRadius:4.0f yRadius:4.0f];
    NSGradient* bodyGrad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.26f alpha:1.0f]
                                                         endingColor:[NSColor colorWithCalibratedWhite:0.14f alpha:1.0f]];
    [bodyGrad drawInBezierPath:knobPath angle:-90.0f];
    [NSGraphicsContext restoreGraphicsState];

    // Knob Outer Bevel Stroke
    [[NSColor colorWithCalibratedWhite:0.45f alpha:0.8f] setStroke];
    knobPath.lineWidth = 1.0f;
    [knobPath stroke];

    // Metallic Grip Indents on Fader Cap
    [[NSColor colorWithCalibratedWhite:0.08f alpha:0.9f] setFill];
    CGFloat ribWidth = 22.0f;
    CGFloat ribX = slotCenterX - ribWidth * 0.5f;

    // 3 upper grip lines
    for (int r = 1; r <= 3; ++r) {
        NSRect rib = NSMakeRect(ribX, knobCenterY + r * 5.5f, ribWidth, 1.5f);
        NSRectFill(rib);
    }
    // 3 lower grip lines
    for (int r = 1; r <= 3; ++r) {
        NSRect rib = NSMakeRect(ribX, knobCenterY - r * 5.5f, ribWidth, 1.5f);
        NSRectFill(rib);
    }

    // Center Illuminated Position Indicator Stripe
    NSRect indicatorRect = NSMakeRect(knobRect.origin.x + 1.0f, knobCenterY - 1.5f, knobW - 2.0f, 3.0f);
    [self.accentColor setFill];
    NSRectFill(indicatorRect);

    // Bright core line
    [[NSColor whiteColor] setFill];
    NSRectFill(NSMakeRect(knobRect.origin.x + 4.0f, knobCenterY - 0.5f, knobW - 8.0f, 1.0f));

    // 7. SOLO & MUTE Backlit Buttons
    NSRect soloRect = [self soloButtonRect];
    NSBezierPath* soloPath = [NSBezierPath bezierPathWithRoundedRect:soloRect xRadius:4.0f yRadius:4.0f];
    if (self.isSoloed) {
        [[NSColor colorWithCalibratedRed:1.0f green:0.84f blue:0.0f alpha:1.0f] setFill];
        [soloPath fill];
        NSDictionary* sAttrs = @{
            NSFontAttributeName: [NSFont boldSystemFontOfSize:10],
            NSForegroundColorAttributeName: [NSColor blackColor],
            NSParagraphStyleAttributeName: centerStyle
        };
        [@"SOLO" drawInRect:NSMakeRect(soloRect.origin.x, soloRect.origin.y + 3.0f, soloRect.size.width, 16.0f) withAttributes:sAttrs];
    } else {
        [[NSColor colorWithCalibratedWhite:0.14f alpha:1.0f] setFill];
        [soloPath fill];
        [[NSColor colorWithCalibratedRed:1.0f green:0.84f blue:0.0f alpha:0.45f] setStroke];
        soloPath.lineWidth = 1.0f;
        [soloPath stroke];
        NSDictionary* sAttrs = @{
            NSFontAttributeName: [NSFont boldSystemFontOfSize:10],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:1.0f green:0.84f blue:0.0f alpha:0.75f],
            NSParagraphStyleAttributeName: centerStyle
        };
        [@"SOLO" drawInRect:NSMakeRect(soloRect.origin.x, soloRect.origin.y + 3.0f, soloRect.size.width, 16.0f) withAttributes:sAttrs];
    }

    NSRect muteRect = [self muteButtonRect];
    NSBezierPath* mutePath = [NSBezierPath bezierPathWithRoundedRect:muteRect xRadius:4.0f yRadius:4.0f];
    if (self.isMuted) {
        [[NSColor colorWithCalibratedRed:1.0f green:0.12f blue:0.25f alpha:1.0f] setFill];
        [mutePath fill];
        NSDictionary* mAttrs = @{
            NSFontAttributeName: [NSFont boldSystemFontOfSize:10],
            NSForegroundColorAttributeName: [NSColor whiteColor],
            NSParagraphStyleAttributeName: centerStyle
        };
        [@"MUTE" drawInRect:NSMakeRect(muteRect.origin.x, muteRect.origin.y + 3.0f, muteRect.size.width, 16.0f) withAttributes:mAttrs];
    } else {
        [[NSColor colorWithCalibratedWhite:0.14f alpha:1.0f] setFill];
        [mutePath fill];
        [[NSColor colorWithCalibratedRed:1.0f green:0.2f blue:0.3f alpha:0.40f] setStroke];
        mutePath.lineWidth = 1.0f;
        [mutePath stroke];
        NSDictionary* mAttrs = @{
            NSFontAttributeName: [NSFont boldSystemFontOfSize:10],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:1.0f green:0.4f blue:0.4f alpha:0.75f],
            NSParagraphStyleAttributeName: centerStyle
        };
        [@"MUTE" drawInRect:NSMakeRect(muteRect.origin.x, muteRect.origin.y + 3.0f, muteRect.size.width, 16.0f) withAttributes:mAttrs];
    }

    // 8. Live Numeric dB Readout Display at Bottom
    NSRect dbRect = NSMakeRect(12.0f, 14.0f, bounds.size.width - 24.0f, 24.0f);
    NSBezierPath* dbPath = [NSBezierPath bezierPathWithRoundedRect:dbRect xRadius:4.0f yRadius:4.0f];
    [[NSColor colorWithCalibratedRed:0.04f green:0.045f blue:0.055f alpha:1.0f] setFill];
    [dbPath fill];
    [[NSColor colorWithCalibratedWhite:0.22f alpha:1.0f] setStroke];
    dbPath.lineWidth = 1.0f;
    [dbPath stroke];

    NSString* dbString;
    if (self.volumeDb <= -47.0f) {
        dbString = @"-∞ dB";
    } else {
        dbString = [NSString stringWithFormat:@"%+.1f dB", self.volumeDb];
    }

    NSDictionary* dbAttrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:10.5f weight:NSFontWeightBold],
        NSForegroundColorAttributeName: self.accentColor,
        NSParagraphStyleAttributeName: centerStyle
    };
    [dbString drawInRect:NSMakeRect(dbRect.origin.x, dbRect.origin.y + 4.0f, dbRect.size.width, 16.0f)
          withAttributes:dbAttrs];
}

// ========================================================
// MOUSE EVENT HANDLING (PRECISE DRAGGING & DOUBLE-CLICK)
// ========================================================
- (void)mouseDown:(NSEvent *)event {
    NSPoint loc = [self convertPoint:event.locationInWindow fromView:nil];

    // Check SOLO Button
    if (NSPointInRect(loc, [self soloButtonRect])) {
        self.isSoloed = !self.isSoloed;
        if (self.onSoloChanged) self.onSoloChanged(self.isSoloed);
        [self setNeedsDisplay:YES];
        return;
    }

    // Check MUTE Button
    if (NSPointInRect(loc, [self muteButtonRect])) {
        self.isMuted = !self.isMuted;
        if (self.onMuteChanged) self.onMuteChanged(self.isMuted);
        [self setNeedsDisplay:YES];
        return;
    }

    // Double-click resets directly to 0.0 dB (Unity Gain)
    if (event.clickCount == 2) {
        self.volumeDb = 0.0f;
        if (self.onVolumeChanged) self.onVolumeChanged(self.volumeDb);
        [self setNeedsDisplay:YES];
        return;
    }

    // Begin Dragging Fader
    _isDragging = YES;
    _dragStartY = loc.y;
    _dragStartDb = self.volumeDb;

    [self updateFaderWithMouseY:loc.y isFineTune:([event modifierFlags] & NSEventModifierFlagShift) != 0];
}

- (void)mouseDragged:(NSEvent *)event {
    if (!_isDragging) return;
    NSPoint loc = [self convertPoint:event.locationInWindow fromView:nil];
    [self updateFaderWithMouseY:loc.y isFineTune:([event modifierFlags] & NSEventModifierFlagShift) != 0];
}

- (void)mouseUp:(NSEvent *)event {
    _isDragging = NO;
    (void)event;
}

- (void)updateFaderWithMouseY:(CGFloat)y isFineTune:(BOOL)fineTune {
    CGFloat bottom = [self trackBottomY];
    CGFloat height = [self trackHeight];
    if (height <= 0.0f) return;

    CGFloat t = (y - bottom) / height;
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;

    float newDb = [self dbFromNormalizedPosition:t];

    if (fineTune) {
        // Shift key pressed: Fine tuning (10x slower delta)
        float delta = (newDb - _dragStartDb) * 0.1f;
        newDb = _dragStartDb + delta;
        if (newDb < -48.0f) newDb = -48.0f;
        if (newDb > 6.0f) newDb = 6.0f;
    }

    // Snap to 0.0 dB within small threshold (+/- 0.3 dB)
    if (fabsf(newDb) < 0.35f) {
        newDb = 0.0f;
    }

    self.volumeDb = newDb;
    if (self.onVolumeChanged) {
        self.onVolumeChanged(self.volumeDb);
    }
    [self setNeedsDisplay:YES];
}

@end
