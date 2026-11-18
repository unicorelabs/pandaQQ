#import "MainWindowController.h"
#import "PandaTheme.h"
#import "ConsoleFaderView.h"
#import "ProRotaryKnobView.h"
#import "ProChannelStripView.h"
#import "CoreAudioHALManager.h"

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

    // Top Pro DAW Menu Bar
    NSView* _dawMenuBar;
    NSPopUpButton* _profilePopup;

    // Channel Strip Rack
    NSScrollView* _rackScrollView;
    RightMixerPaneView* _rackContentView;
    NSMutableArray<ProChannelStripView*>* _channelStrips;
    ProChannelStripView* _vocalStrip;
    ProChannelStripView* _fxStrip;
    ProChannelStripView* _musicStrip;
    ProChannelStripView* _masterStrip;

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
@property (nonatomic, strong) ProChannelStripView* vocalStrip;
@property (nonatomic, strong) ProChannelStripView* fxStrip;
@property (nonatomic, strong) ProChannelStripView* musicStrip;
@property (nonatomic, strong) ProChannelStripView* masterStrip;
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

    // ========================================================
    // RIGHT PANE: PRO HARDWARE MIXING CONSOLE RACK (DAW Matrix)
    // ========================================================
    _rightPane = [[RightMixerPaneView alloc] initWithFrame:NSMakeRect(760, 0, 560, 820)];
    _rightPane.wantsLayer = YES;
    _rightPane.layer.backgroundColor = PandaTheme::Chassis().CGColor;

    // 1. TOP PRO DAW MENU & TOOLBAR (y = 0 .. 32)
    _dawMenuBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, 32)];
    _dawMenuBar.wantsLayer = YES;
    _dawMenuBar.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.12f green:0.13f blue:0.15f alpha:1.0f].CGColor;
    [_rightPane addSubview:_dawMenuBar];

    // Left Menu Labels: File, Edit, View, Setup, Help, About
    NSArray* menuItems = @[@"File", @"Edit", @"View", @"Setup", @"Help", @"About"];
    CGFloat mX = 8.0f;
    for (NSString* m in menuItems) {
        NSButton* mb = [[NSButton alloc] initWithFrame:NSMakeRect(mX, 4, 38, 22)];
        mb.title = m;
        mb.bezelStyle = NSBezelStyleInline;
        mb.bordered = NO;
        mb.font = [NSFont systemFontOfSize:10.5f weight:NSFontWeightMedium];
        mb.contentTintColor = [NSColor colorWithCalibratedWhite:0.82f alpha:1.0f];
        mb.target = self;
        if ([m isEqualToString:@"Setup"]) {
            mb.action = @selector(showAudioSetupModal:);
        } else if ([m isEqualToString:@"About"]) {
            mb.action = @selector(showDonationAlert:);
        }
        [_dawMenuBar addSubview:mb];
        mX += 40.0f;
    }

    // Divider
    NSBox* d1 = [[NSBox alloc] initWithFrame:NSMakeRect(mX + 2, 6, 1, 18)];
    d1.boxType = NSBoxSeparator;
    [_dawMenuBar addSubview:d1];
    mX += 8.0f;

    // Undo / Redo buttons: ↶ ↷
    NSButton* undoBtn = [[NSButton alloc] initWithFrame:NSMakeRect(mX, 4, 22, 22)];
    undoBtn.title = @"↶";
    undoBtn.font = [NSFont systemFontOfSize:12.0f];
    undoBtn.bezelStyle = NSBezelStyleInline;
    [_dawMenuBar addSubview:undoBtn];
    mX += 24.0f;

    NSButton* redoBtn = [[NSButton alloc] initWithFrame:NSMakeRect(mX, 4, 22, 22)];
    redoBtn.title = @"↷";
    redoBtn.font = [NSFont systemFontOfSize:12.0f];
    redoBtn.bezelStyle = NSBezelStyleInline;
    [_dawMenuBar addSubview:redoBtn];
    mX += 28.0f;

    // Del & Add buttons
    NSButton* delBtn = [[NSButton alloc] initWithFrame:NSMakeRect(mX, 5, 30, 20)];
    delBtn.title = @"Del";
    delBtn.font = [NSFont systemFontOfSize:9.5f weight:NSFontWeightMedium];
    delBtn.bezelStyle = NSBezelStyleInline;
    [_dawMenuBar addSubview:delBtn];
    mX += 32.0f;

    NSButton* addBtn = [[NSButton alloc] initWithFrame:NSMakeRect(mX, 5, 32, 20)];
    addBtn.title = @"Add";
    addBtn.font = [NSFont systemFontOfSize:9.5f weight:NSFontWeightMedium];
    addBtn.bezelStyle = NSBezelStyleInline;
    [_dawMenuBar addSubview:addBtn];
    mX += 38.0f;

    // Profile Dropdown: < Streaming Setup ▾ >
    _profilePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(mX, 4, 136, 22) pullsDown:NO];
    _profilePopup.bezelStyle = NSBezelStyleRounded;
    _profilePopup.font = [NSFont boldSystemFontOfSize:10.0f];
    [_profilePopup addItemsWithTitles:@[
        @"< Streaming Setup >",
        @"< Live Stage Pro >",
        @"< Studio Recording >",
        @"< Podcast / Talk >",
        @"< TikTok Live Studio >"
    ]];
    [_dawMenuBar addSubview:_profilePopup];
    mX += 142.0f;

    // Store & New Actions
    NSButton* storeBtn = [[NSButton alloc] initWithFrame:NSMakeRect(mX, 5, 42, 20)];
    storeBtn.title = @"Store";
    storeBtn.font = [NSFont systemFontOfSize:9.5f weight:NSFontWeightMedium];
    storeBtn.bezelStyle = NSBezelStyleInline;
    [_dawMenuBar addSubview:storeBtn];
    mX += 45.0f;

    NSButton* newBtn = [[NSButton alloc] initWithFrame:NSMakeRect(mX, 5, 36, 20)];
    newBtn.title = @"New";
    newBtn.font = [NSFont systemFontOfSize:9.5f weight:NSFontWeightMedium];
    newBtn.bezelStyle = NSBezelStyleInline;
    [_dawMenuBar addSubview:newBtn];
    mX += 40.0f;

    // Hardware Rescan Button
    NSButton* scanBtn = [[NSButton alloc] initWithFrame:NSMakeRect(mX, 5, 60, 20)];
    scanBtn.title = @"Scan 🔄";
    scanBtn.font = [NSFont systemFontOfSize:9.5f weight:NSFontWeightBold];
    scanBtn.bezelStyle = NSBezelStyleInline;
    scanBtn.target = self;
    scanBtn.action = @selector(rescanHardwareDevices);
    [_dawMenuBar addSubview:scanBtn];

    // 2. CHANNEL STRIP RACK HORIZONTAL SCROLL VIEW (y = 32 .. totalH - 32)
    _rackScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 32, 560, 754)];
    _rackScrollView.hasHorizontalScroller = YES;
    _rackScrollView.hasVerticalScroller = NO;
    _rackScrollView.autohidesScrollers = YES;
    _rackScrollView.drawsBackground = NO;
    [_rightPane addSubview:_rackScrollView];

    _rackContentView = [[RightMixerPaneView alloc] initWithFrame:NSMakeRect(0, 0, 580, 754)];
    _rackContentView.wantsLayer = YES;
    _rackContentView.layer.backgroundColor = [NSColor clearColor].CGColor;
    _rackScrollView.documentView = _rackContentView;

    // Instantiate Professional Channel Strips
    _channelStrips = [NSMutableArray array];
    std::shared_ptr<OnLive::DSP::AudioEngine> engine = _engine;
    __weak typeof(self) weakSelf = self;

    CGFloat stripW = 134.0f;
    CGFloat stripH = 740.0f;

    // 1) VOKAL
    _vocalStrip = [[ProChannelStripView alloc] initWithFrame:NSMakeRect(6, 4, stripW, stripH)
                                                channelType:ProChannelTypeVocal
                                                channelName:@"VOKAL"
                                                accentColor:PandaTheme::Cyan()
                                                       icon:@"🎙️"];
    self.vocalStrip = _vocalStrip;
    _vocalStrip.onVolumeChanged = ^(float db) {
        if (engine) engine->getVocalChannel().setVolumeDb(db);
    };
    _vocalStrip.onPanChanged = ^(float pan) {
        if (engine) engine->getVocalChannel().setPan(pan);
    };
    _vocalStrip.onMuteChanged = ^(BOOL m) {
        if (engine) engine->getVocalChannel().setMute(m);
    };
    _vocalStrip.onSoloChanged = ^(BOOL s) {
        if (engine) engine->getVocalChannel().setSolo(s);
    };
    _vocalStrip.onChannelClicked = ^{
        [weakSelf selectChannelStrip:weakSelf.vocalStrip];
    };
    [_channelStrips addObject:_vocalStrip];
    [_rackContentView addSubview:_vocalStrip];

    // 2) EFEK
    _fxStrip = [[ProChannelStripView alloc] initWithFrame:NSMakeRect(6 + (stripW + 6), 4, stripW, stripH)
                                             channelType:ProChannelTypeFX
                                             channelName:@"EFEK"
                                             accentColor:PandaTheme::Purple()
                                                    icon:@"✨"];
    self.fxStrip = _fxStrip;
    _fxStrip.onVolumeChanged = ^(float db) {
        if (engine) engine->getFxChannel().setVolumeDb(db);
    };
    _fxStrip.onPanChanged = ^(float pan) {
        if (engine) engine->getFxChannel().setPan(pan);
    };
    _fxStrip.onMuteChanged = ^(BOOL m) {
        if (engine) engine->getFxChannel().setMute(m);
    };
    _fxStrip.onSoloChanged = ^(BOOL s) {
        if (engine) engine->getFxChannel().setSolo(s);
    };
    _fxStrip.onChannelClicked = ^{
        [weakSelf selectChannelStrip:weakSelf.fxStrip];
    };
    [_channelStrips addObject:_fxStrip];
    [_rackContentView addSubview:_fxStrip];

    // 3) MUSIK
    _musicStrip = [[ProChannelStripView alloc] initWithFrame:NSMakeRect(6 + (stripW + 6) * 2, 4, stripW, stripH)
                                               channelType:ProChannelTypeMusic
                                               channelName:@"MUSIK"
                                               accentColor:PandaTheme::Amber()
                                                      icon:@"♫"];
    self.musicStrip = _musicStrip;
    _musicStrip.onVolumeChanged = ^(float db) {
        if (engine) engine->getMusicChannel().setVolumeDb(db);
    };
    _musicStrip.onPanChanged = ^(float pan) {
        if (engine) engine->getMusicChannel().setPan(pan);
    };
    _musicStrip.onMuteChanged = ^(BOOL m) {
        if (engine) engine->getMusicChannel().setMute(m);
    };
    _musicStrip.onSoloChanged = ^(BOOL s) {
        if (engine) engine->getMusicChannel().setSolo(s);
    };
    _musicStrip.onChannelClicked = ^{
        [weakSelf selectChannelStrip:weakSelf.musicStrip];
    };
    [_channelStrips addObject:_musicStrip];
    [_rackContentView addSubview:_musicStrip];

    // 4) MASTER
    _masterStrip = [[ProChannelStripView alloc] initWithFrame:NSMakeRect(6 + (stripW + 6) * 3, 4, stripW, stripH)
                                                channelType:ProChannelTypeMaster
                                                channelName:@"MASTER"
                                                accentColor:PandaTheme::Red()
                                                       icon:@"🔊"];
    self.masterStrip = _masterStrip;
    _masterStrip.onVolumeChanged = ^(float db) {
        if (engine) engine->getMasterChannel().setVolumeDb(db);
    };
    _masterStrip.onPanChanged = ^(float pan) {
        if (engine) engine->getMasterChannel().setPan(pan);
    };
    _masterStrip.onMuteChanged = ^(BOOL m) {
        if (engine) engine->getMasterChannel().setMute(m);
    };
    _masterStrip.onSoloChanged = ^(BOOL s) {
        if (engine) engine->getMasterChannel().setSolo(s);
    };
    _masterStrip.onChannelClicked = ^{
        [weakSelf selectChannelStrip:weakSelf.masterStrip];
    };
    [_channelStrips addObject:_masterStrip];
    [_rackContentView addSubview:_masterStrip];

    // Default: Highlight Vocal channel (cyan glow border)
    _vocalStrip.isSelected = YES;

    // Scan Real Hardware Inputs & Outputs
    [self rescanHardwareDevices];

    // 3. BOTTOM STATUS BAR (y = totalH - 30)
    _statusBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 786, 560, 32)];
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

    // Responsive Auto-Sizing Block for DAW Rack and Status Bar
    __unsafe_unretained NSScrollView* rScroll = _rackScrollView;
    __unsafe_unretained RightMixerPaneView* rContent = _rackContentView;
    __unsafe_unretained NSView* sBar = _statusBar;
    __unsafe_unretained NSView* mBar = _dawMenuBar;
    NSArray<ProChannelStripView*>* stripsRef = _channelStrips;

    _rightPane.onLayoutSubviews = ^(NSRect bounds) {
        CGFloat totalW = bounds.size.width;
        CGFloat totalH = bounds.size.height;
        CGFloat barH = 32.0f;
        CGFloat statusH = 30.0f;
        CGFloat rackH = totalH - barH - statusH;
        if (rackH < 400.0f) rackH = 400.0f;

        mBar.frame = NSMakeRect(0, 0, totalW, barH);
        sBar.frame = NSMakeRect(0, totalH - statusH, totalW, statusH);
        rScroll.frame = NSMakeRect(0, barH, totalW, rackH);

        CGFloat requiredW = 6.0f + stripsRef.count * (stripW + 6.0f) + 6.0f;
        CGFloat contentW = MAX(totalW, requiredW);
        rContent.frame = NSMakeRect(0, 0, contentW, rackH);

        for (NSUInteger i = 0; i < stripsRef.count; ++i) {
            ProChannelStripView* cs = stripsRef[i];
            cs.frame = NSMakeRect(6.0f + i * (stripW + 6.0f), 2.0f, stripW, rackH - 4.0f);
        }
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

- (void)loadPresetByName:(NSString*)presetName {
    if (!_engine) return;
    if ([presetName containsString:@"Pop"]) {
        _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::PopStudio);
    } else if ([presetName containsString:@"Akustik"]) {
        _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::AcousticWarm);
    } else if ([presetName containsString:@"Dangdut"]) {
        _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::DangdutMelayu);
    } else if ([presetName containsString:@"Talk"] || [presetName containsString:@"SAPA"]) {
        _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::TalkChitChat);
    } else {
        _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::PopStudio);
    }

    if (_vocalStrip && _vocalStrip.faderView) _vocalStrip.faderView.volumeDb = _engine->getVocalChannel().getVolumeDb();
    if (_fxStrip && _fxStrip.faderView) _fxStrip.faderView.volumeDb = _engine->getFxChannel().getVolumeDb();
    if (_musicStrip && _musicStrip.faderView) _musicStrip.faderView.volumeDb = _engine->getMusicChannel().getVolumeDb();
    if (_masterStrip && _masterStrip.faderView) _masterStrip.faderView.volumeDb = _engine->getMasterChannel().getVolumeDb();
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

- (void)selectChannelStrip:(ProChannelStripView*)targetStrip {
    for (ProChannelStripView* cs in _channelStrips) {
        cs.isSelected = (cs == targetStrip);
    }
}

- (void)rescanHardwareDevices {
    NSArray<NSString*>* inNames = [CoreAudioHALManager getAvailableInputNames];
    NSArray<NSString*>* outNames = [CoreAudioHALManager getAvailableOutputNames];

    if (_vocalStrip) [_vocalStrip updateAvailableInputs:inNames];
    if (_fxStrip) [_fxStrip updateAvailableInputs:inNames];
    if (_musicStrip) [_musicStrip updateAvailableInputs:inNames];
    if (_masterStrip) [_masterStrip updateAvailableOutputs:outNames];

    if (inNames.count > 0) {
        _selectedInputDevice = inNames[0];
    }
    if (outNames.count > 0) {
        _selectedOutputDevice = outNames[0];
    }
    [self updateStatusLabelText];
    NSLog(@"[PandaQQ] Rescanned Hardware Devices: %lu inputs, %lu outputs", (unsigned long)inNames.count, (unsigned long)outNames.count);
}

- (void)updateMeters {
    if (!_engine) return;
    float vDb = _engine->getVocalChannel().getPeakMeterDb();
    float fDb = _engine->getFxChannel().getPeakMeterDb();
    float mDb = _engine->getMusicChannel().getPeakMeterDb();
    float mstDb = _engine->getMasterChannel().getPeakMeterDb();

    if (_vocalStrip) [_vocalStrip setMeterLevelDb:vDb rms:vDb - 5.0f];
    if (_fxStrip) [_fxStrip setMeterLevelDb:fDb rms:fDb - 5.0f];
    if (_musicStrip) [_musicStrip setMeterLevelDb:mDb rms:mDb - 5.0f];
    if (_masterStrip) [_masterStrip setMeterLevelDb:mstDb rms:mstDb - 5.0f];
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
