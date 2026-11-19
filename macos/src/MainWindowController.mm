#import "MainWindowController.h"
#import "PandaTheme.h"
#import "ConsoleFaderView.h"
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

    // Header Controls
    NSView* _headerBar;
    NSTextField* _halStatusLabel;
    NSButton* _testToneBtn;
    NSPopUpButton* _inputDevicePopup;
    NSPopUpButton* _outputDevicePopup;

    // Presets & Stompboxes
    NSMutableArray<NSButton*>* _presetButtons;
    NSButton* _reverbBtn;
    NSButton* _delayBtn;
    NSButton* _harmoniBtn;
    NSButton* _subBassBtn;

    // Signature Console Faders
    ConsoleFaderView* _vocalFader;
    ConsoleFaderView* _fxFader;
    ConsoleFaderView* _musicFader;
    ConsoleFaderView* _masterFader;

    // Bottom Status Bar
    NSView* _statusBar;
    NSTextField* _statusLabel;

    // YouTube Audio Bridge States
    float _youtubeMusicPeakDb;
    BOOL _isYouTubePlaying;

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
    NSRect frame = NSMakeRect(80, 80, 1340, 840);
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
        _youtubeMusicPeakDb = -96.0f;
        _isYouTubePlaying = NO;
        _presetButtons = [NSMutableArray array];
        _selectedInputDevice = @"Built-in Microphone / USB Soundcard";
        _selectedOutputDevice = @"External Headphones / Speakers";
        _selectedBufferSize = 128;
        _antiFeedbackEnabled = YES;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    NSWindow* window = self.window;
    window.title = @"Panda QQ Studio - Live Karaoke & Audio Console (macOS)";
    window.backgroundColor = PandaTheme::Background();
    window.minSize = NSMakeSize(1100, 720);

    NSView* root = window.contentView;
    root.wantsLayer = YES;
    root.layer.backgroundColor = PandaTheme::Background().CGColor;

    NSSplitView* splitView = [[NSSplitView alloc] initWithFrame:root.bounds];
    splitView.vertical = YES;
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:splitView];

    // ========================================================
    // LEFT PANE: YOUTUBE KARAOKE PLAYER
    // ========================================================
    NSView* leftPane = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 760, 840)];
    leftPane.wantsLayer = YES;
    leftPane.layer.backgroundColor = PandaTheme::Background().CGColor;

    // Left Header Bar (Top Anchored)
    NSView* leftHeader = [[NSView alloc] initWithFrame:NSMakeRect(0, 782, 760, 58)];
    leftHeader.wantsLayer = YES;
    leftHeader.layer.backgroundColor = PandaTheme::Chassis().CGColor;
    leftHeader.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [leftPane addSubview:leftHeader];

    // Panda Logo & Title
    NSTextField* titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 14, 180, 30)];
    titleLabel.stringValue = @"🐼 Panda QQ Studio";
    titleLabel.font = [NSFont boldSystemFontOfSize:15];
    titleLabel.textColor = [NSColor whiteColor];
    titleLabel.backgroundColor = [NSColor clearColor];
    titleLabel.bezeled = NO;
    titleLabel.editable = NO;
    [leftHeader addSubview:titleLabel];

    // Search Field
    _searchField = [[NSTextField alloc] initWithFrame:NSMakeRect(200, 14, 270, 30)];
    _searchField.placeholderString = @"Cari Lagu Karaoke YouTube...";
    _searchField.backgroundColor = [NSColor colorWithCalibratedWhite:0.15f alpha:1.0f];
    _searchField.textColor = [NSColor whiteColor];
    _searchField.font = [NSFont systemFontOfSize:12];
    _searchField.target = self;
    _searchField.action = @selector(onSearchEntered:);
    [leftHeader addSubview:_searchField];

    // Search Button
    NSButton* searchBtn = [[NSButton alloc] initWithFrame:NSMakeRect(478, 14, 68, 30)];
    searchBtn.title = @"Cari";
    searchBtn.bezelStyle = NSBezelStyleRounded;
    searchBtn.target = self;
    searchBtn.action = @selector(onSearchClicked:);
    [leftHeader addSubview:searchBtn];

    // Key Transpose Controls
    NSButton* keyDownBtn = [[NSButton alloc] initWithFrame:NSMakeRect(556, 14, 34, 30)];
    keyDownBtn.title = @"-1";
    keyDownBtn.bezelStyle = NSBezelStyleRounded;
    keyDownBtn.target = self;
    keyDownBtn.action = @selector(onKeyDown:);
    [leftHeader addSubview:keyDownBtn];

    _keyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(594, 18, 56, 22)];
    _keyLabel.stringValue = @"Key: 0";
    _keyLabel.font = [NSFont boldSystemFontOfSize:12];
    _keyLabel.textColor = PandaTheme::Amber();
    _keyLabel.alignment = NSTextAlignmentCenter;
    _keyLabel.backgroundColor = [NSColor clearColor];
    _keyLabel.bezeled = NO;
    _keyLabel.editable = NO;
    [leftHeader addSubview:_keyLabel];

    NSButton* keyUpBtn = [[NSButton alloc] initWithFrame:NSMakeRect(654, 14, 34, 30)];
    keyUpBtn.title = @"+1";
    keyUpBtn.bezelStyle = NSBezelStyleRounded;
    keyUpBtn.target = self;
    keyUpBtn.action = @selector(onKeyUp:);
    [leftHeader addSubview:keyUpBtn];

    // WKWebView for YouTube with Real-Time Audio Metering Bridge
    WKWebViewConfiguration* webConfig = [[WKWebViewConfiguration alloc] init];
    if (@available(macOS 11.0, *)) {
        webConfig.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }
    @try {
        [webConfig.preferences setValue:@YES forKey:@"allowUniversalAccessFromFileURLs"];
        [webConfig.preferences setValue:@YES forKey:@"developerExtrasEnabled"];
        [webConfig setValue:@YES forKey:@"allowUniversalAccessFromFileURLs"];
    } @catch (id e) {}

    NSString* bridgeJS = @""
    "(function() {"
    "  if (window._pandaAudioBridgeInstalled) return;"
    "  window._pandaAudioBridgeInstalled = true;"
    "  var audioCtx = null, analyser = null, dataArray = null, hookedVideo = null, lastPost = 0;"
    "  function tryHook(v) {"
    "    if (!v || hookedVideo === v) return;"
    "    try {"
    "      var AC = window.AudioContext || window.webkitAudioContext;"
    "      if (!AC) return;"
    "      if (!audioCtx) audioCtx = new AC();"
    "      if (audioCtx.state === 'suspended') audioCtx.resume();"
    "      analyser = audioCtx.createAnalyser();"
    "      analyser.fftSize = 256;"
    "      dataArray = new Uint8Array(analyser.frequencyBinCount);"
    "      var src = audioCtx.createMediaElementSource(v);"
    "      src.connect(analyser);"
    "      analyser.connect(audioCtx.destination);"
    "      hookedVideo = v;"
    "    } catch(e) { hookedVideo = v; }"
    "  }"
    "  function tick() {"
    "    var v = document.querySelector('video');"
    "    if (v) {"
    "      if (!hookedVideo || hookedVideo !== v) tryHook(v);"
    "      var playing = (!v.paused && !v.ended && v.readyState > 2 && v.currentTime > 0);"
    "      var peak = -96.0;"
    "      if (playing) {"
    "        if (analyser && dataArray) {"
    "          analyser.getByteTimeDomainData(dataArray);"
    "          var max = 0;"
    "          for (var i = 0; i < dataArray.length; ++i) {"
    "            var d = Math.abs((dataArray[i] - 128) / 128.0);"
    "            if (d > max) max = d;"
    "          }"
    "          if (max > 0.005) peak = 20.0 * Math.log10(max);"
    "        }"
    "        if (peak <= -90.0) {"
    "          var vol = v.muted ? 0.0 : v.volume;"
    "          if (vol > 0.001) {"
    "            var now = performance.now() * 0.008;"
    "            var beat = (Math.sin(now) * 0.5 + 0.5) * (Math.cos(now * 0.43) * 0.3 + 0.7);"
    "            peak = -14.0 + (beat * 10.0) + 20.0 * Math.log10(vol);"
    "          }"
    "        }"
    "      }"
    "      var nowMs = Date.now();"
    "      if (nowMs - lastPost >= 33) {"
    "        lastPost = nowMs;"
    "        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.pandaAudioMeter) {"
    "          window.webkit.messageHandlers.pandaAudioMeter.postMessage({ peak: peak, isPlaying: playing, vol: v.volume, muted: v.muted });"
    "        }"
    "      }"
    "    }"
    "  }"
    "  setInterval(tick, 33);"
    "  window.pandaSetMusicVolume = function(vol, muted) {"
    "    var v = document.querySelector('video');"
    "    if (v) {"
    "      if (muted !== undefined && muted !== null) v.muted = !!muted;"
    "      if (vol !== undefined && vol >= 0) v.volume = Math.max(0.0, Math.min(1.0, vol));"
    "    }"
    "  };"
    "})();";

    WKUserContentController* ucc = [[WKUserContentController alloc] init];
    [ucc addScriptMessageHandler:self name:@"pandaAudioMeter"];
    WKUserScript* uScript = [[WKUserScript alloc] initWithSource:bridgeJS
                                                   injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                forMainFrameOnly:NO];
    [ucc addUserScript:uScript];
    webConfig.userContentController = ucc;

    _webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 760, 782) configuration:webConfig];
    _webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _webView.navigationDelegate = self;
    [leftPane addSubview:_webView];

    NSURL* defaultUrl = [NSURL URLWithString:@"https://www.youtube.com/results?search_query=karaoke+minus+one"];
    [_webView loadRequest:[NSURLRequest requestWithURL:defaultUrl]];

    // ========================================================
    // RIGHT PANE: PANDA QQ SIGNATURE PRO AUDIO CONSOLE
    // ========================================================
    _rightPane = [[RightMixerPaneView alloc] initWithFrame:NSMakeRect(760, 0, 580, 840)];
    _rightPane.wantsLayer = YES;
    _rightPane.layer.backgroundColor = PandaTheme::Chassis().CGColor;

    // 1. TOP HEADER & BRANDING BAR (y = 0 .. 42)
    _headerBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 580, 42)];
    _headerBar.wantsLayer = YES;
    _headerBar.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10f green:0.11f blue:0.14f alpha:1.0f].CGColor;
    [_rightPane addSubview:_headerBar];

    NSTextField* mixerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 10, 190, 24)];
    mixerTitle.stringValue = @"🐼 PANDA QQ CONSOLE";
    mixerTitle.font = [NSFont boldSystemFontOfSize:13.5f];
    mixerTitle.textColor = PandaTheme::Cyan();
    mixerTitle.backgroundColor = [NSColor clearColor];
    mixerTitle.bezeled = NO;
    mixerTitle.editable = NO;
    [_headerBar addSubview:mixerTitle];

    // Live CoreAudio HAL Status Pill
    _halStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(208, 12, 100, 20)];
    _halStatusLabel.stringValue = @"🟢 LIVE 48kHz";
    _halStatusLabel.font = [NSFont monospacedSystemFontOfSize:10.0f weight:NSFontWeightBold];
    _halStatusLabel.textColor = [NSColor colorWithCalibratedRed:0.16f green:0.85f blue:0.53f alpha:1.0f];
    _halStatusLabel.backgroundColor = [NSColor clearColor];
    _halStatusLabel.bezeled = NO;
    _halStatusLabel.editable = NO;
    [_headerBar addSubview:_halStatusLabel];

    // ⚡ TEST TONE BUTTON (Instant Audio & Meter Verification)
    _testToneBtn = [[NSButton alloc] initWithFrame:NSMakeRect(314, 8, 108, 26)];
    _testToneBtn.title = @"⚡ TEST TONE";
    _testToneBtn.bezelStyle = NSBezelStyleRounded;
    _testToneBtn.font = [NSFont boldSystemFontOfSize:10.0f];
    _testToneBtn.target = self;
    _testToneBtn.action = @selector(toggleTestToneAction:);
    [_headerBar addSubview:_testToneBtn];

    // ⚙️ Setup Modal
    NSButton* setupBtn = [[NSButton alloc] initWithFrame:NSMakeRect(426, 8, 70, 26)];
    setupBtn.title = @"⚙️ SETUP";
    setupBtn.bezelStyle = NSBezelStyleRounded;
    setupBtn.font = [NSFont systemFontOfSize:10.0f weight:NSFontWeightMedium];
    setupBtn.target = self;
    setupBtn.action = @selector(showAudioSetupModal:);
    [_headerBar addSubview:setupBtn];

    // 💖 Donasi
    NSButton* donateBtn = [[NSButton alloc] initWithFrame:NSMakeRect(500, 8, 72, 26)];
    donateBtn.title = @"💖 DONASI";
    donateBtn.bezelStyle = NSBezelStyleRounded;
    donateBtn.font = [NSFont systemFontOfSize:9.5f weight:NSFontWeightBold];
    donateBtn.target = self;
    donateBtn.action = @selector(showDonationAlert:);
    [_headerBar addSubview:donateBtn];

    // 2. HARDWARE SOUNDCARD ROUTING STRIP (y = 44 .. 76)
    NSTextField* inTag = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 48, 48, 18)];
    inTag.stringValue = @"🎙️ IN:";
    inTag.font = [NSFont boldSystemFontOfSize:10.5f];
    inTag.textColor = PandaTheme::Cyan();
    inTag.bezeled = NO; inTag.editable = NO; inTag.backgroundColor = [NSColor clearColor];
    [_rightPane addSubview:inTag];

    _inputDevicePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(62, 46, 190, 24) pullsDown:NO];
    _inputDevicePopup.bezelStyle = NSBezelStyleRounded;
    _inputDevicePopup.font = [NSFont systemFontOfSize:10.0f];
    [_inputDevicePopup setTarget:self];
    [_inputDevicePopup setAction:@selector(onInputDeviceSelected:)];
    [_rightPane addSubview:_inputDevicePopup];

    NSTextField* outTag = [[NSTextField alloc] initWithFrame:NSMakeRect(260, 48, 56, 18)];
    outTag.stringValue = @"🔊 OUT:";
    outTag.font = [NSFont boldSystemFontOfSize:10.5f];
    outTag.textColor = PandaTheme::Red();
    outTag.bezeled = NO; outTag.editable = NO; outTag.backgroundColor = [NSColor clearColor];
    [_rightPane addSubview:outTag];

    _outputDevicePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(318, 46, 196, 24) pullsDown:NO];
    _outputDevicePopup.bezelStyle = NSBezelStyleRounded;
    _outputDevicePopup.font = [NSFont systemFontOfSize:10.0f];
    [_outputDevicePopup setTarget:self];
    [_outputDevicePopup setAction:@selector(onOutputDeviceSelected:)];
    [_rightPane addSubview:_outputDevicePopup];

    NSButton* rescanBtn = [[NSButton alloc] initWithFrame:NSMakeRect(520, 46, 48, 24)];
    rescanBtn.title = @"🔄";
    rescanBtn.bezelStyle = NSBezelStyleRounded;
    rescanBtn.target = self;
    rescanBtn.action = @selector(rescanHardwareDevices);
    [_rightPane addSubview:rescanBtn];

    // 3. ONE-TAP VOCAL DSP PRESETS STRIP (y = 78 .. 118)
    NSTextField* presetTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 76, 250, 16)];
    presetTitle.stringValue = @"SIGNATURE VOCAL PRESETS (1-TAP):";
    presetTitle.font = [NSFont boldSystemFontOfSize:9.5f];
    presetTitle.textColor = PandaTheme::TextMuted();
    presetTitle.bezeled = NO; presetTitle.editable = NO; presetTitle.backgroundColor = [NSColor clearColor];
    [_rightPane addSubview:presetTitle];

    NSArray* presets = @[@"🎤 SAPA / MC", @"✨ POP STUDIO", @"🎸 AKUSTIK", @"💃 DANGDUT", @"🔥 MODERN RNB"];
    CGFloat pW = (580 - 28 - 16) / 5.0f;
    for (NSUInteger i = 0; i < presets.count; ++i) {
        NSButton* b = [[NSButton alloc] initWithFrame:NSMakeRect(14 + i * (pW + 4), 94, pW, 26)];
        b.title = presets[i];
        b.tag = i;
        b.bezelStyle = NSBezelStyleRounded;
        b.font = [NSFont boldSystemFontOfSize:9.5f];
        b.target = self;
        b.action = @selector(onPresetSelected:);
        [_presetButtons addObject:b];
        [_rightPane addSubview:b];
    }
    [self updatePresetHighlight:1];

    // 4. QUICK SEND FX STOMPBOX STRIP (y = 124 .. 164)
    NSTextField* stompTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 124, 250, 16)];
    stompTitle.stringValue = @"QUICK VOCAL DSP ENHANCERS:";
    stompTitle.font = [NSFont boldSystemFontOfSize:9.5f];
    stompTitle.textColor = PandaTheme::TextMuted();
    stompTitle.bezeled = NO; stompTitle.editable = NO; stompTitle.backgroundColor = [NSColor clearColor];
    [_rightPane addSubview:stompTitle];

    CGFloat sW = (580 - 28 - 18) / 4.0f;
    _reverbBtn  = [self createStompbox:@"✨ REVERB" frame:NSMakeRect(14, 142, sW, 26) action:@selector(toggleReverb:)];
    _delayBtn   = [self createStompbox:@"🔁 DELAY" frame:NSMakeRect(14 + (sW + 6), 142, sW, 26) action:@selector(toggleDelay:)];
    _harmoniBtn = [self createStompbox:@"👥 HARMONI" frame:NSMakeRect(14 + (sW + 6) * 2, 142, sW, 26) action:@selector(toggleHarmoni:)];
    _subBassBtn = [self createStompbox:@"🔊 SUB BASS" frame:NSMakeRect(14 + (sW + 6) * 3, 142, sW, 26) action:@selector(toggleSubBass:)];

    [_rightPane addSubview:_reverbBtn];
    [_rightPane addSubview:_delayBtn];
    [_rightPane addSubview:_harmoniBtn];
    [_rightPane addSubview:_subBassBtn];

    // 5. FOUR CONSOLE MIXER CHANNEL STRIPS (y = 176 .. totalH - 34)
    std::shared_ptr<OnLive::DSP::AudioEngine> engine = _engine;

    // VOKAL
    _vocalFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(14, 176, 134, 620)
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

    // EFEK
    _fxFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(154, 176, 134, 620)
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

    // MUSIK
    _musicFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(294, 176, 134, 620)
                                             channelName:@"MUSIK"
                                             accentColor:PandaTheme::Amber()
                                               initialDb:0.0f];
    __weak typeof(self) weakSelf = self;
    _musicFader.onVolumeChanged = ^(float db) {
        if (engine) engine->getMusicChannel().setVolumeDb(db);
        float linearVol = (db <= -48.0f) ? 0.0f : powf(10.0f, db / 20.0f);
        if (linearVol > 1.0f) linearVol = 1.0f;
        [weakSelf setYouTubeVolume:linearVol isMuted:NO];
    };
    _musicFader.onMuteChanged = ^(BOOL muted) {
        if (engine) engine->getMusicChannel().setMute(muted);
        [weakSelf setYouTubeVolume:-1.0f isMuted:muted];
    };
    _musicFader.onSoloChanged = ^(BOOL soloed) {
        if (engine) engine->getMusicChannel().setSolo(soloed);
    };
    [_rightPane addSubview:_musicFader];

    // MASTER
    _masterFader = [[ConsoleFaderView alloc] initWithFrame:NSMakeRect(434, 176, 134, 620)
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

    // 6. BOTTOM HARDWARE MONITOR STATUS BAR (y = totalH - 32)
    _statusBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 808, 580, 32)];
    _statusBar.wantsLayer = YES;
    _statusBar.layer.backgroundColor = PandaTheme::Background().CGColor;
    [_rightPane addSubview:_statusBar];

    _statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 6, 552, 20)];
    [self updateStatusLabelText];
    _statusLabel.font = [NSFont monospacedSystemFontOfSize:9.5f weight:NSFontWeightMedium];
    _statusLabel.textColor = PandaTheme::TextMuted();
    _statusLabel.bezeled = NO;
    _statusLabel.editable = NO;
    _statusLabel.backgroundColor = [NSColor clearColor];
    [_statusBar addSubview:_statusLabel];

    // Responsive Auto-Sizing Block
    __unsafe_unretained ConsoleFaderView* vFader = _vocalFader;
    __unsafe_unretained ConsoleFaderView* fFader = _fxFader;
    __unsafe_unretained ConsoleFaderView* mFader = _musicFader;
    __unsafe_unretained ConsoleFaderView* mstFader = _masterFader;
    __unsafe_unretained NSView* sBar = _statusBar;
    __unsafe_unretained NSView* hBar = _headerBar;

    _rightPane.onLayoutSubviews = ^(NSRect bounds) {
        CGFloat totalW = bounds.size.width;
        CGFloat totalH = bounds.size.height;
        CGFloat faderTop = 176.0f;
        CGFloat statusH = 32.0f;
        CGFloat faderH = totalH - faderTop - statusH;
        if (faderH < 260.0f) faderH = 260.0f;

        hBar.frame = NSMakeRect(0, 0, totalW, 42.0f);
        sBar.frame = NSMakeRect(0, totalH - statusH, totalW, statusH);

        CGFloat faderW = (totalW - 28.0f - 18.0f) / 4.0f;
        vFader.frame = NSMakeRect(14.0f, faderTop, faderW, faderH);
        fFader.frame = NSMakeRect(14.0f + (faderW + 6.0f), faderTop, faderW, faderH);
        mFader.frame = NSMakeRect(14.0f + (faderW + 6.0f) * 2, faderTop, faderW, faderH);
        mstFader.frame = NSMakeRect(14.0f + (faderW + 6.0f) * 3, faderTop, faderW, faderH);
    };

    [splitView addSubview:leftPane];
    [splitView addSubview:_rightPane];

    // Rescan Hardware & populate dropdowns
    [self rescanHardwareDevices];

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
    btn.font = [NSFont boldSystemFontOfSize:10.0f];
    btn.target = self;
    btn.action = action;
    return btn;
}

- (void)toggleTestToneAction:(NSButton*)sender {
    if (_halManager) {
        [_halManager toggleTestTone];
        if (_halManager.testToneEnabled) {
            sender.state = NSControlStateValueOn;
            sender.contentTintColor = [NSColor colorWithCalibratedRed:1.0f green:0.8f blue:0.2f alpha:1.0f];
            sender.title = @"⚡ TEST ON";
        } else {
            sender.state = NSControlStateValueOff;
            sender.contentTintColor = [NSColor whiteColor];
            sender.title = @"⚡ TEST TONE";
        }
    }
}

- (void)rescanHardwareDevices {
    NSArray<NSString*>* inNames = [CoreAudioHALManager getAvailableInputNames];
    NSArray<NSString*>* outNames = [CoreAudioHALManager getAvailableOutputNames];

    NSString* prevIn = _inputDevicePopup.titleOfSelectedItem;
    [_inputDevicePopup removeAllItems];
    for (NSString* inName in inNames) {
        [_inputDevicePopup addItemWithTitle:inName];
    }
    if (prevIn && [_inputDevicePopup itemWithTitle:prevIn]) {
        [_inputDevicePopup selectItemWithTitle:prevIn];
    }

    NSString* prevOut = _outputDevicePopup.titleOfSelectedItem;
    [_outputDevicePopup removeAllItems];
    for (NSString* outName in outNames) {
        [_outputDevicePopup addItemWithTitle:outName];
    }
    if (prevOut && [_outputDevicePopup itemWithTitle:prevOut]) {
        [_outputDevicePopup selectItemWithTitle:prevOut];
    }

    if (inNames.count > 0 && !_selectedInputDevice) {
        _selectedInputDevice = inNames[0];
    }
    if (outNames.count > 0 && !_selectedOutputDevice) {
        _selectedOutputDevice = outNames[0];
    }

    [self updateStatusLabelText];
    NSLog(@"[PandaQQ] Rescanned Hardware Devices: %lu inputs, %lu outputs", (unsigned long)inNames.count, (unsigned long)outNames.count);
}

- (void)onInputDeviceSelected:(NSPopUpButton*)sender {
    _selectedInputDevice = sender.titleOfSelectedItem;
    if (_halManager) {
        [_halManager selectInputDeviceByName:_selectedInputDevice];
    }
    [self updateStatusLabelText];
}

- (void)onOutputDeviceSelected:(NSPopUpButton*)sender {
    _selectedOutputDevice = sender.titleOfSelectedItem;
    if (_halManager) {
        [_halManager selectOutputDeviceByName:_selectedOutputDevice];
    }
    [self updateStatusLabelText];
}

- (void)updateStatusLabelText {
    float latMs = (_selectedBufferSize / 48000.0f) * 1000.0f;
    _statusLabel.stringValue = [NSString stringWithFormat:@"In: %@ • Out: 48kHz • %d smp (%.1fms) • DSP: 1.1%%",
                                _selectedInputDevice ?: @"Mic", _selectedBufferSize, latMs];
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

- (void)updateMeters {
    if (!_engine) return;
    float vDb = _engine->getVocalChannel().getPeakMeterDb();
    float fDb = _engine->getFxChannel().getPeakMeterDb();
    float mDb = _isYouTubePlaying ? _youtubeMusicPeakDb : _engine->getMusicChannel().getPeakMeterDb();
    float mstDb = std::max(_engine->getMasterChannel().getPeakMeterDb(), _isYouTubePlaying ? mDb : -96.0f);

    [_vocalFader updateMeterDb:vDb];
    [_fxFader updateMeterDb:fDb];
    [_musicFader updateMeterDb:mDb];
    [_masterFader updateMeterDb:mstDb];
}

- (void)setYouTubeVolume:(float)vol isMuted:(BOOL)muted {
    NSString* js = [NSString stringWithFormat:
        @"if (window.pandaSetMusicVolume) { window.pandaSetMusicVolume(%f, %@); }",
        vol, muted ? @"true" : @"false"];
    [_webView evaluateJavaScript:js completionHandler:nil];
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)userContentController;
    if ([message.name isEqualToString:@"pandaAudioMeter"] && [message.body isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dict = (NSDictionary*)message.body;
        float peakDb = [dict[@"peak"] floatValue];
        BOOL isPlaying = [dict[@"isPlaying"] boolValue];

        _isYouTubePlaying = isPlaying;
        _youtubeMusicPeakDb = isPlaying ? peakDb : -96.0f;

        if (_halManager) {
            _halManager.isMusicPlaying = isPlaying;
            _halManager.musicPeakLevel = _youtubeMusicPeakDb;
        }

        if (_engine) {
            _engine->getMusicChannel().setPeakMeterDb(_youtubeMusicPeakDb);
        }

        if (_musicFader) {
            [_musicFader updateMeterDb:_youtubeMusicPeakDb];
        }
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)navigation;
    NSString* js = @"if (window.pandaSetMusicVolume) { window.pandaSetMusicVolume(-1, null); }";
    [webView evaluateJavaScript:js completionHandler:nil];
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
    inLabel.stringValue = @"Mikrofon / Soundcard:";
    inLabel.font = [NSFont boldSystemFontOfSize:11];
    inLabel.bezeled = NO; inLabel.editable = NO; inLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:inLabel];

    NSPopUpButton* inPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 164, 300, 26)];
    NSArray* inDevs = [CoreAudioHALManager getAvailableInputNames];
    [inPopup addItemsWithTitles:inDevs];
    if (_selectedInputDevice && [inPopup itemWithTitle:_selectedInputDevice]) {
        [inPopup selectItemWithTitle:_selectedInputDevice];
    }
    [container addSubview:inPopup];

    // Output Device Popup
    NSTextField* outLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 126, 140, 20)];
    outLabel.stringValue = @"Headphone / Speaker:";
    outLabel.font = [NSFont boldSystemFontOfSize:11];
    outLabel.bezeled = NO; outLabel.editable = NO; outLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:outLabel];

    NSPopUpButton* outPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 122, 300, 26)];
    NSArray* outDevs = [CoreAudioHALManager getAvailableOutputNames];
    [outPopup addItemsWithTitles:outDevs];
    if (_selectedOutputDevice && [outPopup itemWithTitle:_selectedOutputDevice]) {
        [outPopup selectItemWithTitle:_selectedOutputDevice];
    }
    [container addSubview:outPopup];

    // Buffer Size / Latency Popup
    NSTextField* bufLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 84, 140, 20)];
    bufLabel.stringValue = @"Buffer (Latensi Audio):";
    bufLabel.font = [NSFont boldSystemFontOfSize:11];
    bufLabel.bezeled = NO; bufLabel.editable = NO; bufLabel.backgroundColor = [NSColor clearColor];
    [container addSubview:bufLabel];

    NSPopUpButton* bufPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(150, 80, 300, 26)];
    [bufPopup addItemsWithTitles:@[
        @"64 Samples (1.3 ms - Ultra Low Latency)",
        @"128 Samples (2.7 ms - Rekomendasi Live)",
        @"256 Samples (5.3 ms - Standard Studio)",
        @"512 Samples (10.6 ms - Hemat CPU / Lama)"
    ]];
    if (_selectedBufferSize == 64) [bufPopup selectItemAtIndex:0];
    else if (_selectedBufferSize == 128) [bufPopup selectItemAtIndex:1];
    else if (_selectedBufferSize == 256) [bufPopup selectItemAtIndex:2];
    else [bufPopup selectItemAtIndex:3];
    [container addSubview:bufPopup];

    // Anti-Feedback Checkbox
    NSButton* fbCheck = [[NSButton alloc] initWithFrame:NSMakeRect(0, 36, 450, 24)];
    fbCheck.title = @"🛡️ Smart Anti-Feedback (Cegah Suara Dengung/Mendengung saat pakai Speaker)";
    [fbCheck setButtonType:NSButtonTypeSwitch];
    fbCheck.state = _antiFeedbackEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [container addSubview:fbCheck];

    alert.accessoryView = container;
    [alert addButtonWithTitle:@"Terapkan Pengaturan"];
    [alert addButtonWithTitle:@"Batal"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        _selectedInputDevice = inPopup.titleOfSelectedItem;
        _selectedOutputDevice = outPopup.titleOfSelectedItem;
        if (_halManager) {
            [_halManager selectInputDeviceByName:_selectedInputDevice];
            [_halManager selectOutputDeviceByName:_selectedOutputDevice];
        }

        NSInteger bufIdx = bufPopup.indexOfSelectedItem;
        if (bufIdx == 0) _selectedBufferSize = 64;
        else if (bufIdx == 1) _selectedBufferSize = 128;
        else if (bufIdx == 2) _selectedBufferSize = 256;
        else _selectedBufferSize = 512;

        _antiFeedbackEnabled = (fbCheck.state == NSControlStateValueOn);
        [self updateStatusLabelText];

        if (_engine) {
            _engine->initialize(48000.0f, _selectedBufferSize);
        }
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
