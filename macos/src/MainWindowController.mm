#import "MainWindowController.h"
#import "PandaTheme.h"
#import "ConsoleFaderView.h"

@interface MainWindowController () {
    std::shared_ptr<OnLive::DSP::AudioEngine> _engine;
    CoreAudioHALManager* _halManager;

    WKWebView* _webView;
    NSTextField* _searchField;
    NSTextField* _keyLabel;
    int _currentKey;
    BOOL _isLiveLocked;

    // Real Hardware Style Console Channel Strips
    ConsoleFaderView* _vocalFader;
    ConsoleFaderView* _fxFader;
    ConsoleFaderView* _musicFader;
    ConsoleFaderView* _masterFader;

    // Stompbox Buttons
    NSButton* _reverbBtn;
    NSButton* _delayBtn;
    NSButton* _harmoniBtn;
    NSButton* _subBassBtn;

    NSTimer* _meterTimer;
}
@end

@implementation MainWindowController

- (instancetype)initWithAudioEngine:(std::shared_ptr<OnLive::DSP::AudioEngine>)engine
                         halManager:(CoreAudioHALManager*)halManager {
    NSRect frame = NSMakeRect(100, 100, 1280, 800);
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
        _isLiveLocked = NO;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    NSWindow* window = self.window;
    window.title = @"Panda QQ - Live Karaoke Desktop DAW & Studio Console (macOS)";
    window.backgroundColor = PandaTheme::Background();
    window.minSize = NSMakeSize(1024, 700);

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
    NSView* leftPane = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 740, 800)];
    leftPane.wantsLayer = YES;
    leftPane.layer.backgroundColor = PandaTheme::Background().CGColor;

    // Left Pane Header Bar
    NSView* leftHeader = [[NSView alloc] initWithFrame:NSMakeRect(0, 740, 740, 60)];
    leftHeader.wantsLayer = YES;
    leftHeader.layer.backgroundColor = PandaTheme::Chassis().CGColor;
    leftHeader.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [leftPane addSubview:leftHeader];

    // Panda Logo & Title
    NSTextField* titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 14, 180, 30)];
    titleLabel.stringValue = @"🐼 Panda QQ Studio";
    titleLabel.font = [NSFont boldSystemFontOfSize:16];
    titleLabel.textColor = [NSColor whiteColor];
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.bezeled = NO;
    titleLabel.editable = NO;
    [leftHeader addSubview:titleLabel];

    // Search Field
    _searchField = [[NSTextField alloc] initWithFrame:NSMakeRect(210, 14, 270, 30)];
    _searchField.placeholderString = @"Cari Lagu Karaoke YouTube...";
    _searchField.backgroundColor = [NSColor colorWithCalibratedWhite:0.15f alpha:1.0f];
    _searchField.textColor = [NSColor whiteColor];
    _searchField.font = [NSFont systemFontOfSize:12];
    _searchField.target = self;
    _searchField.action = @selector(onSearchEntered:);
    [leftHeader addSubview:_searchField];

    // Search Button
    NSButton* searchBtn = [[NSButton alloc] initWithFrame:NSMakeRect(488, 14, 70, 30)];
    searchBtn.title = @"Cari";
    searchBtn.bezelStyle = NSBezelStyleRounded;
    searchBtn.target = self;
    searchBtn.action = @selector(onSearchClicked:);
    [leftHeader addSubview:searchBtn];

    // Key Transpose Controls
    NSButton* keyDownBtn = [[NSButton alloc] initWithFrame:NSMakeRect(570, 14, 34, 30)];
    keyDownBtn.title = @"-1";
    keyDownBtn.bezelStyle = NSBezelStyleRounded;
    keyDownBtn.target = self;
    keyDownBtn.action = @selector(onKeyDown:);
    [leftHeader addSubview:keyDownBtn];

    _keyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(608, 18, 56, 22)];
    _keyLabel.stringValue = @"Key: 0";
    _keyLabel.font = [NSFont boldSystemFontOfSize:12];
    _keyLabel.textColor = PandaTheme::Amber();
    _keyLabel.alignment = NSTextAlignmentCenter;
    _keyLabel.backgroundColor = [NSColor clearColor];
    _keyLabel.bezeled = NO;
    _keyLabel.editable = NO;
    [leftHeader addSubview:_keyLabel];

    NSButton* keyUpBtn = [[NSButton alloc] initWithFrame:NSMakeRect(668, 14, 34, 30)];
    keyUpBtn.title = @"+1";
    keyUpBtn.bezelStyle = NSBezelStyleRounded;
    keyUpBtn.target = self;
    keyUpBtn.action = @selector(onKeyUp:);
    [leftHeader addSubview:keyUpBtn];

    // WKWebView for YouTube
    WKWebViewConfiguration* webConfig = [[WKWebViewConfiguration alloc] init];
    _webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 740, 740) configuration:webConfig];
    _webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _webView.navigationDelegate = self;
    [leftPane addSubview:_webView];

    // Load Default Karaoke YouTube page
    NSURL* defaultUrl = [NSURL URLWithString:@"https://www.youtube.com/results?search_query=karaoke+minus+one"];
    [_webView loadRequest:[NSURLRequest requestWithURL:defaultUrl]];

    // ========================================================
    // RIGHT PANE: PRO HARDWARE MIXING CONSOLE
    // ========================================================
    NSView* rightPane = [[NSView alloc] initWithFrame:NSMakeRect(740, 0, 540, 800)];
    rightPane.wantsLayer = YES;
    rightPane.layer.backgroundColor = PandaTheme::Chassis().CGColor;

    // Right Header with Donation button
    NSView* rightHeader = [[NSView alloc] initWithFrame:NSMakeRect(0, 740, 540, 60)];
    rightHeader.wantsLayer = YES;
    rightHeader.layer.backgroundColor = PandaTheme::Background().CGColor;
    rightHeader.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [rightPane addSubview:rightHeader];

    NSTextField* mixerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 16, 190, 26)];
    mixerTitle.stringValue = @"PRO HARDWARE MIXER";
    mixerTitle.font = [NSFont boldSystemFontOfSize:13];
    mixerTitle.textColor = PandaTheme::Cyan();
    mixerTitle.backgroundColor = [NSColor clearColor];
    mixerTitle.bezeled = NO;
    mixerTitle.editable = NO;
    [rightHeader addSubview:mixerTitle];

    // Donation Button
    NSButton* donateBtn = [[NSButton alloc] initWithFrame:NSMakeRect(370, 14, 150, 32)];
    donateBtn.title = @"💖 Donasi E-Wallet";
    donateBtn.bezelStyle = NSBezelStyleRounded;
    donateBtn.contentTintColor = [NSColor whiteColor];
    donateBtn.target = self;
    donateBtn.action = @selector(showDonationAlert:);
    [rightHeader addSubview:donateBtn];

    // 1-Tap Preset Bar
    NSTextField* presetTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 705, 200, 18)];
    presetTitle.stringValue = @"FACTORY PRESETS (1-TAP):";
    presetTitle.font = [NSFont boldSystemFontOfSize:10];
    presetTitle.textColor = PandaTheme::TextMuted();
    presetTitle.bezeled = NO;
    presetTitle.editable = NO;
    presetTitle.backgroundColor = [NSColor clearColor];
    [rightPane addSubview:presetTitle];

    NSArray* presets = @[@"🎤 SAPA", @"✨ POP", @"🎸 AKUSTIK", @"💃 DANGDUT", @"🔥 RNB"];
    for (NSUInteger i = 0; i < presets.count; ++i) {
        NSButton* b = [[NSButton alloc] initWithFrame:NSMakeRect(16 + i * 102, 672, 96, 28)];
        b.title = presets[i];
        b.tag = i;
        b.bezelStyle = NSBezelStyleRounded;
        b.target = self;
        b.action = @selector(onPresetSelected:);
        [rightPane addSubview:b];
    }

    // Stompbox Quick FX Strip
    NSTextField* stompTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 642, 220, 18)];
    stompTitle.stringValue = @"QUICK SEND FX STOMPBOXES:";
    stompTitle.font = [NSFont boldSystemFontOfSize:10];
    stompTitle.textColor = PandaTheme::TextMuted();
    stompTitle.bezeled = NO;
    stompTitle.editable = NO;
    stompTitle.backgroundColor = [NSColor clearColor];
    [rightPane addSubview:stompTitle];

    _reverbBtn = [self createStompbox:@"✨ REVERB" frame:NSMakeRect(16, 610, 120, 28) action:@selector(toggleReverb:)];
    _delayBtn = [self createStompbox:@"🔁 DELAY" frame:NSMakeRect(144, 610, 120, 28) action:@selector(toggleDelay:)];
    _harmoniBtn = [self createStompbox:@"👥 HARMONI" frame:NSMakeRect(272, 610, 120, 28) action:@selector(toggleHarmoni:)];
    _subBassBtn = [self createStompbox:@"🔊 SUB BASS" frame:NSMakeRect(400, 610, 120, 28) action:@selector(toggleSubBass:)];

    [rightPane addSubview:_reverbBtn];
    [rightPane addSubview:_delayBtn];
    [rightPane addSubview:_harmoniBtn];
    [rightPane addSubview:_subBassBtn];

    // ========================================================
    // 4 REAL HARDWARE FADER CONSOLE STRIPS (VOKAL, EFEK, MUSIK, MASTER)
    // ========================================================
    const CGFloat startX = 16.0f;
    const CGFloat faderW = 120.0f;
    const CGFloat faderSpacing = 8.0f;
    const CGFloat faderY = 46.0f;
    const CGFloat faderH = 555.0f;

    __unsafe_unretained MainWindowController* weakSelf = self;

    // 1. VOKAL CHANNEL STRIP
    _vocalFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(startX, faderY, faderW, faderH)
                                             channelName:@"VOKAL"
                                             accentColor:PandaTheme::Cyan()
                                               initialDb:0.0f];
    _vocalFader.autoresizingMask = NSViewMinYMargin | NSViewHeightSizable;
    _vocalFader.onVolumeChanged = ^(float db) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getVocalChannel().setVolumeDb(db);
    };
    _vocalFader.onMuteChanged = ^(BOOL muted) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getVocalChannel().setMute(muted);
    };
    _vocalFader.onSoloChanged = ^(BOOL soloed) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getVocalChannel().setSolo(soloed);
    };
    [rightPane addSubview:_vocalFader];

    // 2. EFEK CHANNEL STRIP
    _fxFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(startX + (faderW + faderSpacing) * 1, faderY, faderW, faderH)
                                          channelName:@"EFEK"
                                          accentColor:PandaTheme::Purple()
                                            initialDb:0.0f];
    _fxFader.autoresizingMask = NSViewMinYMargin | NSViewHeightSizable;
    _fxFader.onVolumeChanged = ^(float db) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getFxChannel().setVolumeDb(db);
    };
    _fxFader.onMuteChanged = ^(BOOL muted) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getFxChannel().setMute(muted);
    };
    _fxFader.onSoloChanged = ^(BOOL soloed) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getFxChannel().setSolo(soloed);
    };
    [rightPane addSubview:_fxFader];

    // 3. MUSIK CHANNEL STRIP
    _musicFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(startX + (faderW + faderSpacing) * 2, faderY, faderW, faderH)
                                             channelName:@"MUSIK"
                                             accentColor:PandaTheme::Amber()
                                               initialDb:0.0f];
    _musicFader.autoresizingMask = NSViewMinYMargin | NSViewHeightSizable;
    _musicFader.onVolumeChanged = ^(float db) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getMusicChannel().setVolumeDb(db);
    };
    _musicFader.onMuteChanged = ^(BOOL muted) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getMusicChannel().setMute(muted);
    };
    _musicFader.onSoloChanged = ^(BOOL soloed) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getMusicChannel().setSolo(soloed);
    };
    [rightPane addSubview:_musicFader];

    // 4. MASTER CHANNEL STRIP
    _masterFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(startX + (faderW + faderSpacing) * 3, faderY, faderW, faderH)
                                              channelName:@"MASTER"
                                              accentColor:PandaTheme::Red()
                                                initialDb:0.0f];
    _masterFader.autoresizingMask = NSViewMinYMargin | NSViewHeightSizable;
    _masterFader.onVolumeChanged = ^(float db) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getMasterChannel().setVolumeDb(db);
    };
    _masterFader.onMuteChanged = ^(BOOL muted) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getMasterChannel().setMute(muted);
    };
    _masterFader.onSoloChanged = ^(BOOL soloed) {
        if (weakSelf && weakSelf->_engine) weakSelf->_engine->getMasterChannel().setSolo(soloed);
    };
    [rightPane addSubview:_masterFader];

    // Status bar at bottom of right pane
    NSView* statusBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 540, 36)];
    statusBar.wantsLayer = YES;
    statusBar.layer.backgroundColor = PandaTheme::Background().CGColor;
    statusBar.autoresizingMask = NSViewWidthSizable;
    [rightPane addSubview:statusBar];

    NSTextField* statusText = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 8, 500, 20)];
    statusText.stringValue = @"DSP Load: 1.24% • Sample Rate: 48.0 kHz • CoreAudio Low-Latency HAL";
    statusText.font = [NSFont systemFontOfSize:10];
    statusText.textColor = PandaTheme::TextMuted();
    statusText.bezeled = NO;
    statusText.editable = NO;
    statusText.backgroundColor = [NSColor clearColor];
    [statusBar addSubview:statusText];

    [splitView addSubview:leftPane];
    [splitView addSubview:rightPane];

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
    btn.target = self;
    btn.action = action;
    return btn;
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
    switch (sender.tag) {
        case 0: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::TalkChitChat); break;
        case 1: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::PopStudio); break;
        case 2: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::AcousticWarm); break;
        case 3: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::DangdutMelayu); break;
        case 4: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::ModernRnB); break;
    }
    _vocalFader.volumeDb = _engine->getVocalChannel().getVolumeDb();
    _fxFader.volumeDb = _engine->getFxChannel().getVolumeDb();
    _musicFader.volumeDb = _engine->getMusicChannel().getVolumeDb();
    _masterFader.volumeDb = _engine->getMasterChannel().getVolumeDb();
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
