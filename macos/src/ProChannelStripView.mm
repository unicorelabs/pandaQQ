#import "ProChannelStripView.h"
#import "PandaTheme.h"

// Custom Dark Bezel Helper
static NSButton* MakeDarkMiniButton(NSString* title, NSRect frame) {
    NSButton* btn = [[NSButton alloc] initWithFrame:frame];
    btn.title = title;
    btn.bezelStyle = NSBezelStyleInline;
    btn.bordered = YES;
    btn.font = [NSFont boldSystemFontOfSize:9.0f];
    btn.wantsLayer = YES;
    btn.layer.cornerRadius = 3.0f;
    btn.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.18f green:0.20f blue:0.23f alpha:1.0f].CGColor;
    return btn;
}

static NSPopUpButton* MakeDarkPopUp(NSRect frame, NSArray<NSString*>* items) {
    NSPopUpButton* pop = [[NSPopUpButton alloc] initWithFrame:frame pullsDown:NO];
    pop.bezelStyle = NSBezelStyleRounded;
    pop.font = [NSFont systemFontOfSize:9.5f];
    [pop removeAllItems];
    for (NSString* it in items) {
        [pop addItemWithTitle:it];
    }
    return pop;
}

static NSTextField* MakeSectionHeader(NSString* title, NSRect frame) {
    NSTextField* tf = [[NSTextField alloc] initWithFrame:frame];
    tf.stringValue = title;
    tf.font = [NSFont boldSystemFontOfSize:8.5f];
    tf.textColor = [NSColor colorWithCalibratedRed:0.55f green:0.60f blue:0.68f alpha:1.0f];
    tf.alignment = NSTextAlignmentCenter;
    tf.bezeled = NO;
    tf.editable = NO;
    tf.drawsBackground = NO;
    return tf;
}

@implementation ProChannelStripView {
    NSView* _highlightBorderView;
    NSTextField* _nameLabel;
    NSTextField* _iconLabel;
    NSButton* _invBtn;
    BOOL _invertedPhase;
}

- (BOOL)isFlipped {
    return YES;
}

- (instancetype)initWithFrame:(NSRect)frame
                  channelType:(ProChannelStripType)type
                  channelName:(NSString*)name
                  accentColor:(NSColor*)accentColor
                         icon:(NSString*)icon {
    self = [super initWithFrame:frame];
    if (self) {
        _channelType = type;
        _channelName = [name copy];
        _accentColor = accentColor ?: PandaTheme::Cyan();
        _channelIcon = [icon copy] ?: @"🎛️";
        _isSelected = NO;
        _insertPopups = [NSMutableArray array];
        _invertedPhase = NO;

        self.wantsLayer = YES;
        self.layer.cornerRadius = 6.0f;
        self.layer.masksToBounds = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.14f green:0.155f blue:0.175f alpha:1.0f].CGColor;
        self.layer.borderColor = [NSColor colorWithCalibratedRed:0.22f green:0.24f blue:0.28f alpha:1.0f].CGColor;
        self.layer.borderWidth = 1.0f;

        [self setupComponents];
    }
    return self;
}

- (void)setIsSelected:(BOOL)isSelected {
    _isSelected = isSelected;
    if (_isSelected) {
        self.layer.borderColor = [NSColor colorWithCalibratedRed:0.22f green:0.74f blue:0.97f alpha:1.0f].CGColor; // Cyan Glow
        self.layer.borderWidth = 2.0f;
    } else {
        self.layer.borderColor = [NSColor colorWithCalibratedRed:0.22f green:0.24f blue:0.28f alpha:1.0f].CGColor;
        self.layer.borderWidth = 1.0f;
    }
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event {
    [super mouseDown:event];
    self.isSelected = YES;
    if (self.onChannelClicked) {
        self.onChannelClicked();
    }
}

- (void)setupComponents {
    CGFloat w = self.bounds.size.width;
    CGFloat pad = 6.0f;
    CGFloat innerW = w - (pad * 2);
    CGFloat curY = 6.0f;

    // ========================================================
    // 1. PRESET SECTION (y ~ 6 .. 54)
    // ========================================================
    [self addSubview:MakeSectionHeader(@"PRESET", NSMakeRect(pad, curY, innerW, 14))];
    curY += 15.0f;

    // Preset Selector Row: [<] [Preset Popup] [>]
    NSButton* prevPreset = MakeDarkMiniButton(@"<", NSMakeRect(pad, curY, 16, 20));
    [prevPreset setTarget:self];
    [prevPreset setAction:@selector(onPrevPreset:)];
    [self addSubview:prevPreset];

    _presetPopup = MakeDarkPopUp(NSMakeRect(pad + 18, curY, innerW - 36, 20), @[
        @"Default", @"Vocal Pop", @"Vocal Warm", @"Akustik", @"Dangdut Pro", @"Broadcast", @"Crisp Air"
    ]);
    [_presetPopup setTarget:self];
    [_presetPopup setAction:@selector(onPresetPopupChanged:)];
    [self addSubview:_presetPopup];

    NSButton* nextPreset = MakeDarkMiniButton(@">", NSMakeRect(pad + innerW - 16, curY, 16, 20));
    [nextPreset setTarget:self];
    [nextPreset setAction:@selector(onNextPreset:)];
    [self addSubview:nextPreset];
    curY += 23.0f;

    // Quick preset buttons: C (Copy), P (Paste), S (Save), R (Reset)
    CGFloat btnW = (innerW - 9) / 4.0f;
    NSArray* cpsLabels = @[@"C", @"P", @"S", @"R"];
    for (int i = 0; i < 4; ++i) {
        NSButton* b = MakeDarkMiniButton(cpsLabels[i], NSMakeRect(pad + i * (btnW + 3), curY, btnW, 18));
        b.tag = i;
        [b setTarget:self];
        [b setAction:@selector(onCpsrClicked:)];
        [self addSubview:b];
    }
    curY += 24.0f;

    // Divider
    [self addDividerAtY:curY width:w];
    curY += 6.0f;

    // ========================================================
    // 2. INPUT / BUS SECTION (y ~ 60 .. 110)
    // ========================================================
    if (_channelType == ProChannelTypeMaster) {
        // Master Main Mix Banner
        NSTextField* masterTag = MakeSectionHeader(@"MASTER", NSMakeRect(pad, curY, innerW, 14));
        [self addSubview:masterTag];
        curY += 16.0f;
        NSButton* mainMixBadge = MakeDarkMiniButton(@"MAIN MIX", NSMakeRect(pad, curY, innerW, 22));
        mainMixBadge.font = [NSFont boldSystemFontOfSize:10.0f];
        [self addSubview:mainMixBadge];
        curY += 26.0f;
    } else {
        // Channel Input with Phase Invert, Scanned Input Popup & Stereo toggle
        [self addSubview:MakeSectionHeader(@"INPUT", NSMakeRect(pad + 18, curY, innerW - 36, 14))];

        _invBtn = MakeDarkMiniButton(@"INV", NSMakeRect(pad + innerW - 24, curY - 1, 24, 16));
        [_invBtn setTarget:self];
        [_invBtn setAction:@selector(togglePhaseInvert:)];
        [self addSubview:_invBtn];
        curY += 16.0f;

        // Scanned Input Device Popup
        _inputPopup = MakeDarkPopUp(NSMakeRect(pad, curY, innerW - 22, 20), @[
            @"In 1: Maono ProStudio 2x2",
            @"In 2: Maono ProStudio 2x2",
            @"Built-in Microphone",
            @"TTLiveStudio 1-2",
            @"VB-Cable 1-2",
            @"- No Input -"
        ]);
        [_inputPopup setTarget:self];
        [_inputPopup setAction:@selector(onInputPopupChanged:)];
        [self addSubview:_inputPopup];

        NSButton* soloInput = MakeDarkMiniButton(@"S", NSMakeRect(pad + innerW - 18, curY, 18, 20));
        [self addSubview:soloInput];
        curY += 24.0f;
    }

    // Divider
    [self addDividerAtY:curY width:w];
    curY += 6.0f;

    // ========================================================
    // 3. FILTER SECTION (HPF & LPF Rotary Knobs) (y ~ 116 .. 180)
    // ========================================================
    [self addSubview:MakeSectionHeader(@"FILTER", NSMakeRect(pad, curY, innerW, 14))];
    curY += 15.0f;

    CGFloat knobSize = 34.0f;
    CGFloat knobSpacing = (innerW - (knobSize * 2)) / 3.0f;

    // HPF Knob
    CGFloat hpfX = pad + knobSpacing;
    _hpfKnob = [[ProRotaryKnobView alloc] initWithFrame:NSMakeRect(hpfX, curY, knobSize, knobSize + 18)
                                                  label:@"HPF"
                                                  isPan:NO
                                           initialValue:0.0f];
    _hpfKnob.valueDisplayString = @"mati";
    __weak typeof(self) weakSelf = self;
    _hpfKnob.onValueChanged = ^(float val) {
        float hz = 20.0f + (val * 480.0f); // 20Hz .. 500Hz
        if (val < 0.02f) {
            weakSelf.hpfKnob.valueDisplayString = @"mati";
        } else {
            weakSelf.hpfKnob.valueDisplayString = [NSString stringWithFormat:@"%.0fHz", hz];
        }
        if (weakSelf.onHpfChanged) weakSelf.onHpfChanged(val < 0.02f ? 0.0f : hz);
    };
    [self addSubview:_hpfKnob];

    // LPF Knob
    CGFloat lpfX = hpfX + knobSize + knobSpacing;
    _lpfKnob = [[ProRotaryKnobView alloc] initWithFrame:NSMakeRect(lpfX, curY, knobSize, knobSize + 18)
                                                  label:@"LPF"
                                                  isPan:NO
                                           initialValue:1.0f];
    _lpfKnob.valueDisplayString = @"mati";
    _lpfKnob.onValueChanged = ^(float val) {
        float khz = 2.0f + (val * 18.0f); // 2kHz .. 20kHz
        if (val > 0.98f) {
            weakSelf.lpfKnob.valueDisplayString = @"mati";
        } else {
            weakSelf.lpfKnob.valueDisplayString = [NSString stringWithFormat:@"%.1fkHz", khz];
        }
        if (weakSelf.onLpfChanged) weakSelf.onLpfChanged(val > 0.98f ? 20000.0f : khz * 1000.0f);
    };
    [self addSubview:_lpfKnob];
    curY += knobSize + 22.0f;

    // Divider
    [self addDividerAtY:curY width:w];
    curY += 6.0f;

    // ========================================================
    // 4. INSERT RACK SECTION (4 Slots) (y ~ 186 .. 280)
    // ========================================================
    [self addSubview:MakeSectionHeader(@"INSERT", NSMakeRect(pad, curY, innerW, 14))];
    curY += 15.0f;

    NSArray* effectList = @[
        @"- Kosong -",
        @"Studio EQ (6-Band)",
        @"Plate Reverb",
        @"Vocal Compressor",
        @"De-Esser Pro",
        @"Sub Bass Booster",
        @"Smart Ducking",
        @"Stereo Chorus",
        @"Analog Tape Delay",
        @"Pitch Harmonizer",
        @"Peak Limiter"
    ];

    // Pre-populate with realistic defaults based on channel type
    NSArray* defaultInserts = @[@"- Kosong -", @"- Kosong -", @"- Kosong -", @"- Kosong -"];
    if (_channelType == ProChannelTypeVocal) {
        defaultInserts = @[@"Studio EQ (6-Band)", @"Plate Reverb", @"Vocal Compressor", @"De-Esser Pro"];
    } else if (_channelType == ProChannelTypeFX) {
        defaultInserts = @[@"Plate Reverb", @"Analog Tape Delay", @"Pitch Harmonizer", @"- Kosong -"];
    } else if (_channelType == ProChannelTypeMusic) {
        defaultInserts = @[@"Studio EQ (6-Band)", @"Sub Bass Booster", @"Smart Ducking", @"- Kosong -"];
    } else if (_channelType == ProChannelTypeMaster) {
        defaultInserts = @[@"Studio EQ (6-Band)", @"Peak Limiter", @"- Kosong -", @"- Kosong -"];
    }

    for (int slot = 0; slot < 4; ++slot) {
        NSPopUpButton* insPop = MakeDarkPopUp(NSMakeRect(pad, curY, innerW, 20), effectList);
        [insPop selectItemWithTitle:defaultInserts[slot]];
        insPop.tag = slot;
        [insPop setTarget:self];
        [insPop setAction:@selector(onInsertPopupChanged:)];
        [_insertPopups addObject:insPop];
        [self addSubview:insPop];
        curY += 21.0f;
    }
    curY += 4.0f;

    // Divider
    [self addDividerAtY:curY width:w];
    curY += 6.0f;

    // ========================================================
    // 5. SENDS SECTION (y ~ 290 .. 330)
    // ========================================================
    [self addSubview:MakeSectionHeader(@"SENDS", NSMakeRect(pad, curY, innerW, 14))];
    curY += 15.0f;

    _sendsPopup = MakeDarkPopUp(NSMakeRect(pad, curY, innerW, 20), @[
        @"- None -",
        @"Aux 1: Reverb Bus",
        @"Aux 2: Delay Bus",
        @"Aux 3: Sidechain Duck"
    ]);
    [self addSubview:_sendsPopup];
    curY += 23.0f;

    // Divider
    [self addDividerAtY:curY width:w];
    curY += 6.0f;

    // ========================================================
    // 6. OUTPUT ROUTING SECTION (y ~ 336 .. 380)
    // ========================================================
    [self addSubview:MakeSectionHeader(@"OUTPUT", NSMakeRect(pad, curY, innerW - 20, 14))];
    NSButton* sOutput = MakeDarkMiniButton(@"S", NSMakeRect(pad + innerW - 18, curY - 1, 18, 16));
    [self addSubview:sOutput];
    curY += 16.0f;

    _outputPopup = MakeDarkPopUp(NSMakeRect(pad, curY, innerW, 20), @[
        @"Master (Main Mix)",
        @"Analogue 1-2: Maono 2x2",
        @"TTLiveStudioVirtualSoundCard",
        @"VB-Cable 1-2",
        @"Built-in Output",
        @"Group 1 Bus"
    ]);
    [_outputPopup setTarget:self];
    [_outputPopup setAction:@selector(onOutputPopupChanged:)];
    [self addSubview:_outputPopup];
    curY += 24.0f;

    // Divider
    [self addDividerAtY:curY width:w];
    curY += 6.0f;

    // ========================================================
    // 7. PAN ROTARY KNOB SECTION (y ~ 386 .. 446)
    // ========================================================
    [self addSubview:MakeSectionHeader(@"PAN", NSMakeRect(pad, curY, innerW, 14))];
    curY += 15.0f;

    CGFloat panKnobSize = 38.0f;
    CGFloat panX = (w - panKnobSize) / 2.0f;
    _panKnob = [[ProRotaryKnobView alloc] initWithFrame:NSMakeRect(panX, curY, panKnobSize, panKnobSize + 18)
                                                  label:@""
                                                  isPan:YES
                                           initialValue:0.0f];
    _panKnob.valueDisplayString = @"0";
    _panKnob.onValueChanged = ^(float val) {
        if (fabs(val) < 0.05f) {
            weakSelf.panKnob.valueDisplayString = @"0";
        } else if (val < 0) {
            weakSelf.panKnob.valueDisplayString = [NSString stringWithFormat:@"L%.0f", fabs(val) * 100.0f];
        } else {
            weakSelf.panKnob.valueDisplayString = [NSString stringWithFormat:@"R%.0f", val * 100.0f];
        }
        if (weakSelf.onPanChanged) weakSelf.onPanChanged(val);
    };
    [self addSubview:_panKnob];
    curY += panKnobSize + 22.0f;

    // Divider
    [self addDividerAtY:curY width:w];
    curY += 6.0f;

    // ========================================================
    // 8. CHANNEL BADGE ICON & NAME (y ~ 452 .. 480)
    // ========================================================
    _iconLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, curY, innerW, 20)];
    _iconLabel.stringValue = [NSString stringWithFormat:@"%@  %@", _channelIcon, _channelName];
    _iconLabel.font = [NSFont boldSystemFontOfSize:11.0f];
    _iconLabel.textColor = _accentColor;
    _iconLabel.alignment = NSTextAlignmentCenter;
    _iconLabel.bezeled = NO;
    _iconLabel.editable = NO;
    _iconLabel.drawsBackground = NO;
    [self addSubview:_iconLabel];
    curY += 24.0f;

    // ========================================================
    // 9. CONSOLE FADER & 24-LED METER (y ~ 482 .. remaining)
    // ========================================================
    CGFloat remainingH = self.bounds.size.height - curY - 6.0f;
    if (remainingH < 220.0f) remainingH = 220.0f;

    _faderView = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(pad, curY, innerW, remainingH)
                                             channelName:_channelName
                                             accentColor:_accentColor
                                               initialDb:0.0f];
    _faderView.onVolumeChanged = ^(float db) {
        if (weakSelf.onVolumeChanged) weakSelf.onVolumeChanged(db);
    };
    _faderView.onMuteChanged = ^(BOOL muted) {
        if (weakSelf.onMuteChanged) weakSelf.onMuteChanged(muted);
    };
    _faderView.onSoloChanged = ^(BOOL soloed) {
        if (weakSelf.onSoloChanged) weakSelf.onSoloChanged(soloed);
    };
    [self addSubview:_faderView];
}

- (void)addDividerAtY:(CGFloat)y width:(CGFloat)w {
    NSBox* div = [[NSBox alloc] initWithFrame:NSMakeRect(6, y, w - 12, 1)];
    div.boxType = NSBoxSeparator;
    [self addSubview:div];
}

- (void)togglePhaseInvert:(NSButton*)sender {
    _invertedPhase = !_invertedPhase;
    if (_invertedPhase) {
        sender.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.95f green:0.40f blue:0.15f alpha:1.0f].CGColor;
    } else {
        sender.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.18f green:0.20f blue:0.23f alpha:1.0f].CGColor;
    }
}

- (void)onPrevPreset:(id)sender {
    NSInteger cur = _presetPopup.indexOfSelectedItem;
    if (cur > 0) {
        [_presetPopup selectItemAtIndex:cur - 1];
        [self onPresetPopupChanged:_presetPopup];
    }
}

- (void)onNextPreset:(id)sender {
    NSInteger cur = _presetPopup.indexOfSelectedItem;
    if (cur < _presetPopup.numberOfItems - 1) {
        [_presetPopup selectItemAtIndex:cur + 1];
        [self onPresetPopupChanged:_presetPopup];
    }
}

- (void)onPresetPopupChanged:(NSPopUpButton*)sender {
    if (self.onPresetSelected) {
        self.onPresetSelected(sender.titleOfSelectedItem);
    }
}

- (void)onCpsrClicked:(NSButton*)sender {
    // C, P, S, R actions
    NSLog(@"[ProChannelStrip] %@ clicked CPSR: tag %ld", _channelName, (long)sender.tag);
}

- (void)onInputPopupChanged:(NSPopUpButton*)sender {
    if (self.onInputChanged) {
        self.onInputChanged(sender.titleOfSelectedItem);
    }
}

- (void)onOutputPopupChanged:(NSPopUpButton*)sender {
    if (self.onOutputChanged) {
        self.onOutputChanged(sender.titleOfSelectedItem);
    }
}

- (void)onInsertPopupChanged:(NSPopUpButton*)sender {
    if (self.onInsertChanged) {
        self.onInsertChanged(sender.tag, sender.titleOfSelectedItem);
    }
}

- (void)updateAvailableInputs:(NSArray<NSString*>*)inputs {
    if (!inputs || inputs.count == 0) return;
    NSString* prevSelected = _inputPopup.titleOfSelectedItem;
    [_inputPopup removeAllItems];
    for (NSString* inName in inputs) {
        [_inputPopup addItemWithTitle:inName];
    }
    if (prevSelected && [_inputPopup itemWithTitle:prevSelected]) {
        [_inputPopup selectItemWithTitle:prevSelected];
    }
}

- (void)updateAvailableOutputs:(NSArray<NSString*>*)outputs {
    if (!outputs || outputs.count == 0) return;
    NSString* prevSelected = _outputPopup.titleOfSelectedItem;
    [_outputPopup removeAllItems];
    for (NSString* outName in outputs) {
        [_outputPopup addItemWithTitle:outName];
    }
    if (prevSelected && [_outputPopup itemWithTitle:prevSelected]) {
        [_outputPopup selectItemWithTitle:prevSelected];
    }
}

- (void)setMeterLevelDb:(float)peakDb rms:(float)rmsDb {
    (void)rmsDb;
    [_faderView updateMeterDb:peakDb];
}

@end
