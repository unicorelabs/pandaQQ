#import "MainWindowController.h"
#import "PandaTheme.h"
#import "ConsoleFaderView.h"

// Flipped coordinate container for predictable, rock-solid top-to-bottom layout
@interface RightMixerPaneView : NSView
@property (nonatomic, copy) void (^onLayoutSubviews)(NSRect bounds);
@end

@implementation RightMixerPaneView
- (BOOL)isFlipped {
    return YES;
}
- (void)layout {
    [super layout];
    if (self.onLayoutSubviews) {
        self.onLayoutSubviews(self.bounds);
    }
}
@end

@interface MainWindowController () {
    std::shared_ptr<OnLive::DSP::AudioEngine> _engine;
    CoreAudioHALManager* _halManager;

    WKWebView* _webView;
    NSTextField* _searchField;
    NSTextField* _keyLabel;
    int _currentKey;

    // Right Pane Flipped Container
    RightMixerPaneView* _rightPane;

    // Preset & FX Buttons
    NSMutableArray<NSButton*>* _presetButtons;
    NSButton* _reverbBtn;
    NSButton* _delayBtn;
    NSButton* _harmoniBtn;
    NSButton* _subBassBtn;

    // Real Hardware Style Console Channel Strips
    ConsoleFaderView* _vocalFader;
    ConsoleFaderView* _fxFader;
    ConsoleFaderView* _musicFader;
    ConsoleFaderView* _masterFader;

    // Bottom Status Bar
    NSView* _statusBar;
    NSTextField* _statusLabel;

    // Audio Setup States
    NSString* _selectedInputDevice;
    NSString* _selectedOutputDevice;
    int _selectedBufferSize;
    BOOL _antiFeedbackEnabled;

    NSTimer* _meterTimer;
}
@end

@implementation MainWindowController

- (instancetype)initWithAudioEngine:(std::shared_ptr<OnLive::DSP::AudioEngine>)engine
                         halManager:(CoreAudioHALManager*)halManager {
    NSRect frame = NSMakeRect(80, 80, 1320, 820);
    NSWindow* window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable |
                                                              NSWindowStyleMaskResizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        _engine = engine;
        _halManager = halManager;
        _currentKey = 0;
        _presetButtons = [NSMutableArray array];
        _selectedInputDevice = @"Built-in Microphone / USB Soundcard";
        _selectedOutputDevice = @"External Headphones / Jack 3.5mm";
        _selectedBufferSize = 128;
        _antiFeedbackEnabled = YES;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    NSWindow* window = self.window;
    window.title = @"Panda QQ - Live Karaoke Desktop DAW & Studio Console (macOS)";
    window.backgroundColor = PandaTheme::Background();
    window.minSize = NSMakeSize(1080, 700);

    NSView* root = window.contentView;
    root.wantsLayer = YES;
    root.layer.backgroundColor = PandaTheme::Background().CGColor;

    NSSplitView* splitView = [[NSSplitView alloc] initWithFrame:root.bounds];
    splitView.vertical = YES;
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:splitView];

    // ========================================================
    // LEFT PANE: YOUTUBE KARAOKE PLAYER (Widescreen 16:9 View)
    // ========================================================
    NSView* leftPane = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 760, 820)];
    leftPane.wantsLayer = YES;
    leftPane.layer.backgroundColor = PandaTheme::Background().CGColor;

    // Left Header Bar (Top Anchored)
    NSView* leftHeader = [[NSView alloc] initWithFrame:NSMakeRect(0, 762, 760, 58)];
    leftHeader.wantsLayer = YES;
    leftHeader.layer.backgroundColor = PandaTheme::Chassis().CGColor;
    leftHeader.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [leftPane addSubview:leftHeader];

    // Panda Logo & Title
    NSTextField* titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 14, 180, 30)];
    titleLabel.stringValue = @"🐼 Panda QQ Studio";
    titleLabel.font = [NSFont boldSystemFontOfSize:16];
    titleLabel.textColor = [NSColor whiteColor];
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.bezeled = NO;
    titleLabel.editable = NO;
    [leftHeader addSubview:titleLabel];

    // Search Field
    _searchField = [[NSTextField alloc] initWithFrame:NSMakeRect(205, 14, 270, 30)];
    _searchField.placeholderString = @"Cari Lagu Karaoke YouTube...";
    _searchField.backgroundColor = [NSColor colorWithCalibratedWhite:0.15f alpha:1.0f];
    _searchField.textColor = [NSColor whiteColor];
    _searchField.font = [NSFont systemFontOfSize:12];
    _searchField.target = self;
    _searchField.action = @selector(onSearchEntered:);
    [leftHeader addSubview:_searchField];

    // Search Button
    NSButton* searchBtn = [[NSButton alloc] initWithFrame:NSMakeRect(483, 14, 68, 30)];
    searchBtn.title = @"Cari";
    searchBtn.bezelStyle = NSBezelStyleRounded;
    searchBtn.target = self;
    searchBtn.action = @selector(onSearchClicked:);
    [leftHeader addSubview:searchBtn];

    // Key Transpose Controls
    NSButton* keyDownBtn = [[NSButton alloc] initWithFrame:NSMakeRect(565, 14, 34, 30)];
    keyDownBtn.title = @"-1";
    keyDownBtn.bezelStyle = NSBezelStyleRounded;
    keyDownBtn.target = self;
    keyDownBtn.action = @selector(onKeyDown:);
    [leftHeader addSubview:keyDownBtn];

    _keyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(603, 18, 56, 22)];
    _keyLabel.stringValue = @"Key: 0";
    _keyLabel.font = [NSFont boldSystemFontOfSize:12];
    _keyLabel.textColor = PandaTheme::Amber();
    _keyLabel.alignment = NSTextAlignmentCenter;
    _keyLabel.backgroundColor = [NSColor clearColor];
    _keyLabel.bezeled = NO;
    _keyLabel.editable = NO;
    [leftHeader addSubview:_keyLabel];

    NSButton* keyUpBtn = [[NSButton alloc] initWithFrame:NSMakeRect(663, 14, 34, 30)];
    keyUpBtn.title = @"+1";
    keyUpBtn.bezelStyle = NSBezelStyleRounded;
    keyUpBtn.target = self;
    keyUpBtn.action = @selector(onKeyUp:);
    [leftHeader addSubview:keyUpBtn];

    // WKWebView for YouTube
    WKWebViewConfiguration* webConfig = [[WKWebViewConfiguration alloc] init];
    _webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 760, 762) configuration:webConfig];
    _webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _webView.navigationDelegate = self;
    [leftPane addSubview:_webView];

    NSURL* defaultUrl = [NSURL URLWithString:@"https://www.youtube.com/results?search_query=karaoke+minus+one"];
    [_webView loadRequest:[NSURLRequest requestWithURL:defaultUrl]];

    // ========================================================
    // RIGHT PANE: PRO HARDWARE MIXING CONSOLE (Flipped Top-Down)
    // ========================================================
    _rightPane = [[RightMixerPaneView alloc] initWithFrame:NSMakeRect(760, 0, 560, 820)];
    _rightPane.wantsLayer = YES;
    _rightPane.layer.backgroundColor = PandaTheme::Chassis().CGColor;

    // 1. TOP HEADER TOOLBAR (y = 8 .. 48)
    NSView* headerBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, 48)];
    headerBar.wantsLayer = YES;
    headerBar.layer.backgroundColor = PandaTheme::Background().CGColor;
    [_rightPane addSubview:headerBar];

    NSTextField* mixerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 12, 160, 24)];
    mixerTitle.stringValue = @"PRO AUDIO MIXER";
    mixerTitle.font = [NSFont boldSystemFontOfSize:13];
    mixerTitle.textColor = PandaTheme::Cyan();
    mixerTitle.backgroundColor = [NSColor clearColor];
    mixerTitle.bezeled = NO;
    mixerTitle.editable = NO;
    [headerBar addSubview:mixerTitle];

    // ⚙️ Audio Setup Button
    NSButton* audioSetupBtn = [[NSButton alloc] initWithFrame:NSMakeRect(180, 10, 115, 28)];
    audioSetupBtn.title = @"⚙️ AUDIO SETUP";
    audioSetupBtn.bezelStyle = NSBezelStyleRounded;
    audioSetupBtn.font = [NSFont systemFontOfSize:10.5f weight:NSFontWeightMedium];
    audioSetupBtn.target = self;
    audioSetupBtn.action = @selector(showAudioSetupModal:);
    [headerBar addSubview:audioSetupBtn];

    // 🎛️ Studio FX Rack Button
    NSButton* fxRackBtn = [[NSButton alloc] initWithFrame:NSMakeRect(302, 10, 100, 28)];
    fxRackBtn.title = @"🎛️ FX RACK";
    fxRackBtn.bezelStyle = NSBezelStyleRounded;
    fxRackBtn.font = [NSFont systemFontOfSize:10.5f weight:NSFontWeightMedium];
    fxRackBtn.target = self;
    fxRackBtn.action = @selector(showFxRackModal:);
    [headerBar addSubview:fxRackBtn];

    // 💖 Donation Button
    NSButton* donateBtn = [[NSButton alloc] initWithFrame:NSMakeRect(410, 10, 136, 28)];
    donateBtn.title = @"💖 DONASI E-WALLET";
    donateBtn.bezelStyle = NSBezelStyleRounded;
    donateBtn.font = [NSFont systemFontOfSize:10 weight:NSFontWeightBold];
    donateBtn.target = self;
    donateBtn.action = @selector(showDonationAlert:);
    [headerBar addSubview:donateBtn];

    // 2. 1-TAP PRESET STRIP (y = 52 .. 94)
    NSTextField* presetTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 52, 220, 16)];
    presetTitle.stringValue = @"FACTORY PRESETS (1-TAP):";
    presetTitle.font = [NSFont boldSystemFontOfSize:9.5f];
    presetTitle.textColor = PandaTheme::TextMuted();
    presetTitle.bezeled = NO;
    presetTitle.editable = NO;
    presetTitle.backgroundColor = [NSColor clearColor];
    [_rightPane addSubview:presetTitle];

    NSArray* presets = @[@"🎤 SAPA", @"✨ POP", @"🎸 AKUSTIK", @"💃 DANGDUT", @"🔥 RNB"];
    for (NSUInteger i = 0; i < presets.count; ++i) {
        NSButton* b = [[NSButton alloc] initWithFrame:NSMakeRect(14 + i * 106, 70, 100, 28)];
        b.title = presets[i];
        b.tag = i;
        b.bezelStyle = NSBezelStyleRounded;
        b.font = [NSFont boldSystemFontOfSize:10];
        b.target = self;
        b.action = @selector(onPresetSelected:);
        [_presetButtons addObject:b];
        [_rightPane addSubview:b];
    }
    // Default preset selected is POP
    [self updatePresetHighlight:1];

    // 3. QUICK FX STOMPBOX STRIP (y = 104 .. 148)
    NSTextField* stompTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 104, 250, 16)];
    stompTitle.stringValue = @"QUICK SEND FX STOMPBOXES:";
    stompTitle.font = [NSFont boldSystemFontOfSize:9.5f];
    stompTitle.textColor = PandaTheme::TextMuted();
    stompTitle.bezeled = NO;
    stompTitle.editable = NO;
    stompTitle.backgroundColor = [NSColor clearColor];
    [_rightPane addSubview:stompTitle];

    _reverbBtn  = [self createStompbox:@"✨ REVERB" frame:NSMakeRect(14, 122, 126, 28) action:@selector(toggleReverb:)];
    _delayBtn   = [self createStompbox:@"🔁 DELAY" frame:NSMakeRect(148, 122, 126, 28) action:@selector(toggleDelay:)];
    _harmoniBtn = [self createStompbox:@"👥 HARMONI" frame:NSMakeRect(282, 122, 126, 28) action:@selector(toggleHarmoni:)];
    _subBassBtn = [self createStompbox:@"🔊 SUB BASS" frame:NSMakeRect(416, 122, 126, 28) action:@selector(toggleSubBass:)];

    [_rightPane addSubview:_reverbBtn];
    [_rightPane addSubview:_delayBtn];
    [_rightPane addSubview:_harmoniBtn];
    [_rightPane addSubview:_subBassBtn];

    // 4. 4 CONSOLE MIXER CHANNEL STRIPS (y = 158 .. height - 34)
    std::shared_ptr<OnLive::DSP::AudioEngine> engine = _engine;

    // Vokal
    _vocalFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(14, 158, 126, 620)
                                             channelName:@"VOKAL"
                                             accentColor:PandaTheme::Cyan()
                                               initialDb:0.0f];
    _vocalFader.onVolumeChanged = ^(float db) {
        if (engine) engine->getVocalChannel().setVolumeDb(db);
    };
    _vocalFader.onMuteChanged = ^(BOOL muted) {
        if (engine) engine->getVocalChannel().setMute(muted);
    };
    _vocalFader.onSoloChanged = ^(BOOL soloed) {
        if (engine) engine->getVocalChannel().setSolo(soloed);
    };
    [_rightPane addSubview:_vocalFader];

    // Efek
    _fxFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(148, 158, 126, 620)
                                          channelName:@"EFEK"
                                          accentColor:PandaTheme::Purple()
                                            initialDb:0.0f];
    _fxFader.onVolumeChanged = ^(float db) {
        if (engine) engine->getFxChannel().setVolumeDb(db);
    };
    _fxFader.onMuteChanged = ^(BOOL muted) {
        if (engine) engine->getFxChannel().setMute(muted);
    };
    _fxFader.onSoloChanged = ^(BOOL soloed) {
        if (engine) engine->getFxChannel().setSolo(soloed);
    };
    [_rightPane addSubview:_fxFader];

    // Musik
    _musicFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(282, 158, 126, 620)
                                             channelName:@"MUSIK"
                                             accentColor:PandaTheme::Amber()
                                               initialDb:0.0f];
    _musicFader.onVolumeChanged = ^(float db) {
        if (engine) engine->getMusicChannel().setVolumeDb(db);
    };
    _musicFader.onMuteChanged = ^(BOOL muted) {
        if (engine) engine->getMusicChannel().setMute(muted);
    };
    _musicFader.onSoloChanged = ^(BOOL soloed) {
        if (engine) engine->getMusicChannel().setSolo(soloed);
    };
    [_rightPane addSubview:_musicFader];

    // Master
    _masterFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(416, 158, 126, 620)
                                              channelName:@"MASTER"
                                              accentColor:PandaTheme::Red()
                                                initialDb:0.0f];
    _masterFader.onVolumeChanged = ^(float db) {
        if (engine) engine->getMasterChannel().setVolumeDb(db);
    };
    _masterFader.onMuteChanged = ^(BOOL muted) {
        if (engine) engine->getMasterChannel().setMute(muted);
    };
    _masterFader.onSoloChanged = ^(BOOL soloed) {
        if (engine) engine->getMasterChannel().setSolo(soloed);
    };
    [_rightPane addSubview:_masterFader];

    // 5. BOTTOM STATUS BAR
    _statusBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 786, 560, 34)];
    _statusBar.wantsLayer = YES;
    _statusBar.layer.backgroundColor = PandaTheme::Background().CGColor;
    [_rightPane addSubview:_statusBar];

    _statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 6, 532, 20)];
    [self updateStatusLabelText];
    _statusLabel.font = [NSFont monospacedSystemFontOfSize:9.5f weight:NSFontWeightMedium];
    _statusLabel.textColor = PandaTheme::TextMuted();
    _statusLabel.bezeled = NO;
    _statusLabel.editable = NO;
    _statusLabel.backgroundColor = [NSColor clearColor];
    [_statusBar addSubview:_statusLabel];

    // Responsive Auto-Sizing Block for Faders and Status Bar
    __unsafe_unretained ConsoleFaderView* vFader = _vocalFader;
    __unsafe_unretained ConsoleFaderView* fFader = _fxFader;
    __unsafe_unretained ConsoleFaderView* mFader = _musicFader;
    __unsafe_unretained ConsoleFaderView* mstFader = _masterFader;
    __unsafe_unretained NSView* sBar = _statusBar;

    _rightPane.onLayoutSubviews = ^(NSRect bounds) {
        CGFloat totalH = bounds.size.height;
        CGFloat faderTop = 158.0f;
        CGFloat statusH = 32.0f;
        CGFloat faderH = totalH - faderTop - statusH;
        if (faderH < 300.0f) faderH = 300.0f;

        CGFloat faderW = 126.0f;
        vFader.frame = NSMakeRect(14, faderTop, faderW, faderH);
        fFader.frame = NSMakeRect(148, faderTop, faderW, faderH);
        mFader.frame = NSMakeRect(282, faderTop, faderW, faderH);
        mstFader.frame = NSMakeRect(416, faderTop, faderW, faderH);

        sBar.frame = NSMakeRect(0, totalH - statusH, bounds.size.width, statusH);
    };

    [splitView addSubview:leftPane];
    [splitView addSubview:_rightPane];

    // Setup Timer to poll audio meters at 30 FPS
    _meterTimer = [NSTimer scheduledTimerWithTimeInterval:0.033f
                                                   target:self
                                                 selector:@selector(updateMeters)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (NSButton*)createStompbox:(NSString*)title frame:(NSRect)frame action:(SEL)action {
    NSButton* btn = [[NSButton alloc] initWithFrame:frame];
    btn.title = title;
    btn.bezelStyle = NSBezelStyleRounded;
    [btn setButtonType:NSButtonTypePushOnPushOff];
    btn.state = NSControlStateValueOn;
    btn.font = [NSFont boldSystemFontOfSize:10.5f];
    btn.target = self;
    btn.action = action;
    return btn;
}

- (void)updateStatusLabelText {
    float latMs = (_selectedBufferSize / 48000.0f) * 1000.0f;
    _statusLabel.stringValue = [NSString stringWithFormat:@"In: %@ • Out: 48kHz • %d smp (%.1fms) • DSP: 1.2%%",
                                _selectedInputDevice, _selectedBufferSize, latMs];
}

- (void)updatePresetHighlight:(NSInteger)selectedIndex {
    for (NSUInteger i = 0; i < _presetButtons.count; ++i) {
        NSButton* b = _presetButtons[i];
        if ((NSInteger)i == selectedIndex) {
            b.state = NSControlStateValueOn;
            b.contentTintColor = PandaTheme::Cyan();
        } else {
            b.state = NSControlStateValueOff;
            b.contentTintColor = [NSColor whiteColor];
        }
    }
}

- (void)toggleReverb:(NSButton*)sender {
    if (_engine) _engine->setReverbEnabled(sender.state == NSControlStateValueOn);
}

- (void)toggleDelay:(NSButton*)sender {
    if (_engine) _engine->setDelayEnabled(sender.state == NSControlStateValueOn);
}

- (void)toggleHarmoni:(NSButton*)sender {
    if (_engine) _engine->setHarmonizerEnabled(sender.state == NSControlStateValueOn);
}

- (void)toggleSubBass:(NSButton*)sender {
    if (_engine) _engine->setSubBoosterEnabled(sender.state == NSControlStateValueOn);
}

- (void)onPresetSelected:(NSButton*)sender {
    if (!_engine) return;
    [self updatePresetHighlight:sender.tag];

    switch (sender.tag) {
        case 0:
            _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::TalkChitChat);
            _reverbBtn.state = NSControlStateValueOff;
            _delayBtn.state = NSControlStateValueOff;
            _harmoniBtn.state = NSControlStateValueOff;
            _subBassBtn.state = NSControlStateValueOff;
            break;
        case 1:
            _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::PopStudio);
            _reverbBtn.state = NSControlStateValueOn;
            _delayBtn.state = NSControlStateValueOn;
            _harmoniBtn.state = NSControlStateValueOff;
            _subBassBtn.state = NSControlStateValueOn;
            break;
        case 2:
            _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::AcousticWarm);
            _reverbBtn.state = NSControlStateValueOn;
            _delayBtn.state = NSControlStateValueOff;
            _harmoniBtn.state = NSControlStateValueOff;
            _subBassBtn.state = NSControlStateValueOff;
            break;
        case 3:
            _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::DangdutMelayu);
            _reverbBtn.state = NSControlStateValueOn;
            _delayBtn.state = NSControlStateValueOn;
            _harmoniBtn.state = NSControlStateValueOff;
            _subBassBtn.state = NSControlStateValueOn;
            break;
        case 4:
            _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::ModernRnB);
            _reverbBtn.state = NSControlStateValueOn;
            _delayBtn.state = NSControlStateValueOn;
            _harmoniBtn.state = NSControlStateValueOn;
            _subBassBtn.state = NSControlStateValueOn;
            break;
    }

    _vocalFader.volumeDb = _engine->getVocalChannel().getVolumeDb();
    _fxFader.volumeDb = _engine->getFxChannel().getVolumeDb();
    _musicFader.volumeDb = _engine->getMusicChannel().getVolumeDb();
    _masterFader.volumeDb = _engine->getMasterChannel().getVolumeDb();
}

// ========================================================
// ⚙️ AUDIO SETUP MODAL (HARDWARE & NO-HARDWARE SETUP)
// ========================================================
- (void)showAudioSetupModal:(id)sender {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = @"⚙️ Pengaturan Hardware Audio & Latensi";
    alert.informativeText = @"Pilih sumber mikrofon, output headphone, dan ukuran buffer audio:";

    NSView* container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 460, 200)];

    // Input Device Popup
    NSTextField* inLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 168, 140, 20)];
    inLabel.stringValue = @"Input Vokal (Mic):";
    inLabel.font = [NSFont boldSystemFontOfSize:11];
    inLabel.bezeled = NO; inLabel.editable = NO; inLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:inLabel];

    NSPopUpButton* inPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(145, 164, 305, 26)];
    [inPopup addItemsWithTitles:@[
        @"🎙️ Auto: Built-in Mic / USB Interface",
        @"🎙️ Focusrite / Behringer / USB Soundcard",
        @"🎙️ Built-in Microphone (MacBook)",
        @"🎙️ Line-In External Mic"
    ]];
    [container addSubview:inPopup];

    // Output Device Popup
    NSTextField* outLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 128, 140, 20)];
    outLabel.stringValue = @"Output Monitor:";
    outLabel.font = [NSFont boldSystemFontOfSize:11];
    outLabel.bezeled = NO; outLabel.editable = NO; outLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:outLabel];

    NSPopUpButton* outPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(145, 124, 305, 26)];
    [outPopup addItemsWithTitles:@[
        @"🎧 Headphones / Earphones (Jack 3.5mm)",
        @"💻 MacBook Internal Speakers (Anti-Feedback)",
        @"🌐 Panda QQ Virtual Broadcast Loopback (OBS/TikTok)"
    ]];
    [container addSubview:outPopup];

    // Buffer Size Popup
    NSTextField* bufLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 88, 140, 20)];
    bufLabel.stringValue = @"Buffer & Latensi:";
    bufLabel.font = [NSFont boldSystemFontOfSize:11];
    bufLabel.bezeled = NO; bufLabel.editable = NO; bufLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:bufLabel];

    NSPopUpButton* bufPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(145, 84, 305, 26)];
    [bufPopup addItemsWithTitles:@[
        @"⚡ 64 samples  (1.3 ms - Ultra Low Latency)",
        @"🎯 128 samples (2.7 ms - Standar Studio Live)",
        @"🛡️ 256 samples (5.3 ms - Aman & Stabil)"
    ]];
    [bufPopup selectItemAtIndex:1];
    [container addSubview:bufPopup];

    // Anti-Feedback Shield Checkbox
    NSButton* shieldCheck = [[NSButton alloc] initWithFrame:NSMakeRect(0, 42, 450, 22)];
    shieldCheck.title = @"🛡️ Aktifkan Acoustic Anti-Feedback Shield (Cegah Denging Speaker)";
    [shieldCheck setButtonType:NSButtonTypeSwitch];
    shieldCheck.state = _antiFeedbackEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [container addSubview:shieldCheck];

    // Broadcast Cable note
    NSTextField* noteLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 4, 450, 32)];
    noteLabel.stringValue = @"💡 Tanpa Soundcard: Anda bisa langsung menyanyi dengan Mic & Earphone laptop. Musik & vokal otomatis tersinkronisasi.";
    noteLabel.font = [NSFont systemFontOfSize:10];
    noteLabel.textColor = PandaTheme::TextMuted();
    noteLabel.bezeled = NO; noteLabel.editable = NO; noteLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:noteLabel];

    alert.accessoryView = container;
    [alert addButtonWithTitle:@"Terapkan Pengaturan"];
    [alert addButtonWithTitle:@"Batal"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        _selectedInputDevice = inPopup.selectedItem.title;
        _selectedOutputDevice = outPopup.selectedItem.title;
        _antiFeedbackEnabled = (shieldCheck.state == NSControlStateValueOn);
        if (bufPopup.indexOfSelectedItem == 0) _selectedBufferSize = 64;
        else if (bufPopup.indexOfSelectedItem == 1) _selectedBufferSize = 128;
        else _selectedBufferSize = 256;

        [self updateStatusLabelText];
    }
}

// ========================================================
// 🎛️ STUDIO FX RACK & PARAMETER MODAL
// ========================================================
- (void)showFxRackModal:(id)sender {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = @"🎛️ Studio FX Rack & Parameter DSP Vokal";
    alert.informativeText = @"Sesuaikan karakter efek studio vokal dan instrumen secara mendalam:";

    NSView* container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 480, 280)];

    // 1. Reverb Decay Time Slider
    NSTextField* revLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 248, 200, 18)];
    revLabel.stringValue = @"✨ Reverb Decay (Panjang Gema):";
    revLabel.font = [NSFont boldSystemFontOfSize:11];
    revLabel.bezeled = NO; revLabel.editable = NO; revLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:revLabel];

    NSSlider* revSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(210, 244, 200, 24)];
    revSlider.minValue = 0.5f; revSlider.maxValue = 5.0f; revSlider.floatValue = 2.4f;
    [container addSubview:revSlider];

    NSTextField* revVal = [[NSTextField alloc] initWithFrame:NSMakeRect(415, 248, 60, 18)];
    revVal.stringValue = @"2.4 s";
    revVal.font = [NSFont systemFontOfSize:11];
    revVal.bezeled = NO; revVal.editable = NO; revVal.backgroundColor = [NSColor clearColor];
    [container addSubview:revVal];

    // 2. Delay Feedback Slider
    NSTextField* delLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 206, 200, 18)];
    delLabel.stringValue = @"🔁 Delay Feedback (Pantulan):";
    delLabel.font = [NSFont boldSystemFontOfSize:11];
    delLabel.bezeled = NO; delLabel.editable = NO; delLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:delLabel];

    NSSlider* delSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(210, 202, 200, 24)];
    delSlider.minValue = 0.0f; delSlider.maxValue = 80.0f; delSlider.floatValue = 35.0f;
    [container addSubview:delSlider];

    NSTextField* delVal = [[NSTextField alloc] initWithFrame:NSMakeRect(415, 206, 60, 18)];
    delVal.stringValue = @"35 %";
    delVal.font = [NSFont systemFontOfSize:11];
    delVal.bezeled = NO; delVal.editable = NO; delVal.backgroundColor = [NSColor clearColor];
    [container addSubview:delVal];

    // 3. Harmonizer Voice Popup
    NSTextField* harmLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 164, 200, 18)];
    harmLabel.stringValue = @"👥 Harmoni Interval:";
    harmLabel.font = [NSFont boldSystemFontOfSize:11];
    harmLabel.bezeled = NO; harmLabel.editable = NO; harmLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:harmLabel];

    NSPopUpButton* harmPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(210, 160, 200, 26)];
    [harmPopup addItemsWithTitles:@[
        @"+3rd (Terst Mayor - Suara 2)",
        @"+5th (Kuint - Suara Tinggi)",
        @"-Octave (Oktaf Bawah)"
    ]];
    [container addSubview:harmPopup];

    // 4. Sub-Bass Drive Slider
    NSTextField* subLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 122, 200, 18)];
    subLabel.stringValue = @"🔊 Sub-Bass Drive (Bobot Vokal):";
    subLabel.font = [NSFont boldSystemFontOfSize:11];
    subLabel.bezeled = NO; subLabel.editable = NO; subLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:subLabel];

    NSSlider* subSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(210, 118, 200, 24)];
    subSlider.minValue = 0.0f; subSlider.maxValue = 12.0f; subSlider.floatValue = 4.5f;
    [container addSubview:subSlider];

    NSTextField* subVal = [[NSTextField alloc] initWithFrame:NSMakeRect(415, 122, 60, 18)];
    subVal.stringValue = @"+4.5 dB";
    subVal.font = [NSFont systemFontOfSize:11];
    subVal.bezeled = NO; subVal.editable = NO; subVal.backgroundColor = [NSColor clearColor];
    [container addSubview:subVal];

    // 5. Noise Gate Threshold
    NSTextField* gateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 80, 200, 18)];
    gateLabel.stringValue = @"🚪 Noise Gate Threshold:";
    gateLabel.font = [NSFont boldSystemFontOfSize:11];
    gateLabel.bezeled = NO; gateLabel.editable = NO; gateLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:gateLabel];

    NSSlider* gateSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(210, 76, 200, 24)];
    gateSlider.minValue = -60.0f; gateSlider.maxValue = -20.0f; gateSlider.floatValue = -45.0f;
    [container addSubview:gateSlider];

    NSTextField* gateVal = [[NSTextField alloc] initWithFrame:NSMakeRect(415, 80, 60, 18)];
    gateVal.stringValue = @"-45 dB";
    gateVal.font = [NSFont systemFontOfSize:11];
    gateVal.bezeled = NO; gateVal.editable = NO; gateVal.backgroundColor = [NSColor clearColor];
    [container addSubview:gateVal];

    // 6. Auto-Carve Checkbox
    NSButton* carveCheck = [[NSButton alloc] initWithFrame:NSMakeRect(0, 36, 460, 22)];
    carveCheck.title = @"✨ Auto-Carve: Otomatis melubangi musik YouTube saat vokal bernyanyi";
    [carveCheck setButtonType:NSButtonTypeSwitch];
    carveCheck.state = NSControlStateValueOn;
    [container addSubview:carveCheck];

    alert.accessoryView = container;
    [alert addButtonWithTitle:@"Simpan Parameter"];
    [alert addButtonWithTitle:@"Batal"];

    if ([alert runModal] == NSAlertFirstButtonReturn && _engine) {
        float sr = _engine->getSampleRate();
        _engine->getReverb().setParameters(revSlider.floatValue, 30.0f, 0.4f, 120.0f, 6500.0f, sr);
        _engine->getDelay().setParameters(OnLive::DSP::DelayMode::PingPong, 300.0f, delSlider.floatValue / 100.0f, 0.5f, 3500.0f, sr);
        _engine->getSubHarmonic().setParameters(90.0f, subSlider.floatValue / 12.0f, sr);
        _engine->getNoiseGate().setParameters(gateSlider.floatValue, 6.0f, 2.0f, 50.0f, sr);
        _engine->setAutoCarveEnabled(carveCheck.state == NSControlStateValueOn);

        OnLive::DSP::HarmonyInterval interval = OnLive::DSP::HarmonyInterval::ThirdAbove;
        if (harmPopup.indexOfSelectedItem == 1) interval = OnLive::DSP::HarmonyInterval::FifthAbove;
        else if (harmPopup.indexOfSelectedItem == 2) interval = OnLive::DSP::HarmonyInterval::OctaveDown;
        _engine->getHarmonizer().setParameters(interval, 0.0f, sr);
    }
}

- (void)onSearchEntered:(NSTextField*)sender {
    [self performSearch];
}

- (void)onSearchClicked:(id)sender {
    [self performSearch];
}

- (void)performSearch {
    NSString* query = [_searchField.stringValue stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (query.length > 0) {
        NSString* urlStr = [NSString stringWithFormat:@"https://www.youtube.com/results?search_query=%@+karaoke", query];
        [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]]];
    }
}

- (void)onKeyDown:(id)sender {
    _currentKey--;
    _keyLabel.stringValue = [NSString stringWithFormat:@"Key: %d", _currentKey];
}

- (void)onKeyUp:(id)sender {
    _currentKey++;
    _keyLabel.stringValue = [NSString stringWithFormat:@"Key: %d", _currentKey];
}

- (void)updateMeters {
    if (!_engine) return;
    [_vocalFader updateMeterDb:_engine->getVocalChannel().getPeakMeterDb()];
    [_fxFader updateMeterDb:_engine->getFxChannel().getPeakMeterDb()];
    [_musicFader updateMeterDb:_engine->getMusicChannel().getPeakMeterDb()];
    [_masterFader updateMeterDb:_engine->getMasterChannel().getPeakMeterDb()];
}

- (void)showDonationAlert:(id)sender {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = @"💖 Dukung Pengembangan Panda QQ";
    alert.informativeText = @"Panda QQ 100% gratis & bebas iklan.\n\n"
                            @"Nomor E-Wallet (DANA / GoPay / OVO):\n"
                            @"082116929992 (a/n Panda QQ Support)\n\n"
                            @"Salin nomor atau konfirmasi donasi via WhatsApp:";
    [alert addButtonWithTitle:@"📋 Salin Nomor 082116929992"];
    [alert addButtonWithTitle:@"💬 WhatsApp"];
    [alert addButtonWithTitle:@"Tutup"];

    NSModalResponse resp = [alert runModal];
    if (resp == NSAlertFirstButtonReturn) {
        NSPasteboard* pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb setString:@"082116929992" forType:NSPasteboardTypeString];
    } else if (resp == NSAlertSecondButtonReturn) {
        NSURL* waUrl = [NSURL URLWithString:@"https://wa.me/6282116929992?text=Halo%20Admin%20Panda%20QQ%2C%20saya%20sudah%20mengirimkan%20donasi%20dukungan."];
        [[NSWorkspace sharedWorkspace] openURL:waUrl];
    }
}

@end
