#import "MainWindowController.h"
#import "PandaTheme.h"

@interface LEDMeterView : NSView
@property (nonatomic, assign) float levelDb;
@end

@implementation LEDMeterView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    [[NSColor blackColor] setFill];
    NSRectFill(self.bounds);

    const int totalSegments = 16;
    const float segHeight = (self.bounds.size.height - 4.0f) / totalSegments;
    const float segWidth = self.bounds.size.width - 4.0f;

    // Map -60dB .. 0dB to 0 .. 16
    float norm = (self.levelDb + 60.0f) / 60.0f;
    if (norm < 0.0f) norm = 0.0f;
    if (norm > 1.0f) norm = 1.0f;
    int litCount = (int)(norm * totalSegments);

    for (int i = 0; i < totalSegments; ++i) {
        NSRect r = NSMakeRect(2.0f, 2.0f + i * segHeight, segWidth, segHeight - 1.5f);
        NSColor* c;
        if (i >= 13) {
            c = PandaTheme::Red();
        } else if (i >= 9) {
            c = PandaTheme::Amber();
        } else {
            c = PandaTheme::Green();
        }

        if (i < litCount) {
            [c setFill];
        } else {
            [[c colorWithAlphaComponent:0.15f] setFill];
        }
        NSRectFill(r);
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
    BOOL _isLiveLocked;

    // Faders
    NSSlider* _vocalSlider;
    NSSlider* _fxSlider;
    NSSlider* _musicSlider;
    NSSlider* _masterSlider;

    // Meters
    LEDMeterView* _vocalMeter;
    LEDMeterView* _fxMeter;
    LEDMeterView* _musicMeter;
    LEDMeterView* _masterMeter;

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
    window.title = @"Panda QQ - Live Karaoke Desktop DAW (macOS)";
    window.backgroundColor = PandaTheme::Background();
    window.minSize = NSMakeSize(1024, 680);

    NSView* root = window.contentView;
    root.wantsLayer = YES;
    root.layer.backgroundColor = PandaTheme::Background().CGColor;

    NSSplitView* splitView = [[NSSplitView alloc] initWithFrame:root.bounds];
    splitView.vertical = YES;
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:splitView];

    // ========================================================
    // LEFT PANE: YOUTUBE KARAOKE PLAYER (60% Width)
    // ========================================================
    NSView* leftPane = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 760, 800)];
    leftPane.wantsLayer = YES;
    leftPane.layer.backgroundColor = PandaTheme::Background().CGColor;

    // Left Pane Header Bar
    NSView* leftHeader = [[NSView alloc] initWithFrame:NSMakeRect(0, 740, 760, 60)];
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
    _searchField = [[NSTextField alloc] initWithFrame:NSMakeRect(210, 14, 280, 30)];
    _searchField.placeholderString = @"Cari Lagu Karaoke YouTube...";
    _searchField.backgroundColor = [NSColor colorWithCalibratedWhite:0.15f alpha:1.0f];
    _searchField.textColor = [NSColor whiteColor];
    _searchField.font = [NSFont systemFontOfSize:12];
    _searchField.target = self;
    _searchField.action = @selector(onSearchEntered:);
    [leftHeader addSubview:_searchField];

    // Search Button
    NSButton* searchBtn = [[NSButton alloc] initWithFrame:NSMakeRect(498, 14, 70, 30)];
    searchBtn.title = @"Cari";
    searchBtn.bezelStyle = NSBezelStyleRounded;
    searchBtn.target = self;
    searchBtn.action = @selector(onSearchClicked:);
    [leftHeader addSubview:searchBtn];

    // Key Transpose Controls
    NSButton* keyDownBtn = [[NSButton alloc] initWithFrame:NSMakeRect(580, 14, 34, 30)];
    keyDownBtn.title = @"-1";
    keyDownBtn.bezelStyle = NSBezelStyleRounded;
    keyDownBtn.target = self;
    keyDownBtn.action = @selector(onKeyDown:);
    [leftHeader addSubview:keyDownBtn];

    _keyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(618, 18, 56, 22)];
    _keyLabel.stringValue = @"Key: 0";
    _keyLabel.font = [NSFont boldSystemFontOfSize:12];
    _keyLabel.textColor = PandaTheme::Amber();
    _keyLabel.alignment = NSTextAlignmentCenter;
    _keyLabel.backgroundColor = [NSColor clearColor];
    _keyLabel.bezeled = NO;
    _keyLabel.editable = NO;
    [leftHeader addSubview:_keyLabel];

    NSButton* keyUpBtn = [[NSButton alloc] initWithFrame:NSMakeRect(678, 14, 34, 30)];
    keyUpBtn.title = @"+1";
    keyUpBtn.bezelStyle = NSBezelStyleRounded;
    keyUpBtn.target = self;
    keyUpBtn.action = @selector(onKeyUp:);
    [leftHeader addSubview:keyUpBtn];

    // WKWebView for YouTube
    WKWebViewConfiguration* webConfig = [[WKWebViewConfiguration alloc] init];
    _webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 760, 740) configuration:webConfig];
    _webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _webView.navigationDelegate = self;
    [leftPane addSubview:_webView];

    // Load Default Karaoke YouTube page
    NSURL* defaultUrl = [NSURL URLWithString:@"https://www.youtube.com/results?search_query=karaoke+minus+one"];
    [_webView loadRequest:[NSURLRequest requestWithURL:defaultUrl]];

    // ========================================================
    // RIGHT PANE: DESKTOP AUDIO CONSOLE (40% Width)
    // ========================================================
    NSView* rightPane = [[NSView alloc] initWithFrame:NSMakeRect(760, 0, 520, 800)];
    rightPane.wantsLayer = YES;
    rightPane.layer.backgroundColor = PandaTheme::Chassis().CGColor;

    // Right Header with Donation button
    NSView* rightHeader = [[NSView alloc] initWithFrame:NSMakeRect(0, 740, 520, 60)];
    rightHeader.wantsLayer = YES;
    rightHeader.layer.backgroundColor = PandaTheme::Background().CGColor;
    rightHeader.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [rightPane addSubview:rightHeader];

    NSTextField* mixerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 16, 160, 26)];
    mixerTitle.stringValue = @"PRO AUDIO CONSOLE";
    mixerTitle.font = [NSFont boldSystemFontOfSize:13];
    mixerTitle.textColor = PandaTheme::Cyan();
    mixerTitle.backgroundColor = [NSColor clearColor];
    mixerTitle.bezeled = NO;
    mixerTitle.editable = NO;
    [rightHeader addSubview:mixerTitle];

    // Donation Button
    NSButton* donateBtn = [[NSButton alloc] initWithFrame:NSMakeRect(360, 14, 140, 32)];
    donateBtn.title = @"💖 Donasi E-Wallet";
    donateBtn.bezelStyle = NSBezelStyleRounded;
    donateBtn.contentTintColor = [NSColor whiteColor];
    donateBtn.target = self;
    donateBtn.action = @selector(showDonationAlert:);
    [rightHeader addSubview:donateBtn];

    // 1-Tap Preset Bar
    NSTextField* presetTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 700, 200, 20)];
    presetTitle.stringValue = @"FACTORY PRESETS:";
    presetTitle.font = [NSFont boldSystemFontOfSize:10];
    presetTitle.textColor = PandaTheme::TextMuted();
    presetTitle.bezeled = NO;
    presetTitle.editable = NO;
    presetTitle.backgroundColor = [NSColor clearColor];
    [rightPane addSubview:presetTitle];

    NSArray* presets = @[@"🎤 SAPA", @"✨ POP", @"🎸 AKUSTIK", @"💃 DANGDUT", @"🔥 RNB"];
    for (NSUInteger i = 0; i < presets.count; ++i) {
        NSButton* b = [[NSButton alloc] initWithFrame:NSMakeRect(16 + i * 98, 665, 92, 30)];
        b.title = presets[i];
        b.tag = i;
        b.bezelStyle = NSBezelStyleRounded;
        b.target = self;
        b.action = @selector(onPresetSelected:);
        [rightPane addSubview:b];
    }

    // Stompbox Quick FX Strip
    NSTextField* stompTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 630, 200, 20)];
    stompTitle.stringValue = @"QUICK SEND FX STOMPBOXES:";
    stompTitle.font = [NSFont boldSystemFontOfSize:10];
    stompTitle.textColor = PandaTheme::TextMuted();
    stompTitle.bezeled = NO;
    stompTitle.editable = NO;
    stompTitle.backgroundColor = [NSColor clearColor];
    [rightPane addSubview:stompTitle];

    _reverbBtn = [self createStompbox:@"✨ REVERB" frame:NSMakeRect(16, 595, 115, 30) action:@selector(toggleReverb:)];
    _delayBtn = [self createStompbox:@"🔁 DELAY" frame:NSMakeRect(140, 595, 115, 30) action:@selector(toggleDelay:)];
    _harmoniBtn = [self createStompbox:@"👥 HARMONI" frame:NSMakeRect(264, 595, 115, 30) action:@selector(toggleHarmoni:)];
    _subBassBtn = [self createStompbox:@"🔊 SUB BASS" frame:NSMakeRect(388, 595, 115, 30) action:@selector(toggleSubBass:)];

    [rightPane addSubview:_reverbBtn];
    [rightPane addSubview:_delayBtn];
    [rightPane addSubview:_harmoniBtn];
    [rightPane addSubview:_subBassBtn];

    // 4 MAIN FADERS (Vocal, FX, Music, Master)
    _vocalSlider = [self createFaderInView:rightPane x:40 label:@"VOKAL" accent:PandaTheme::Cyan() tag:0];
    _fxSlider    = [self createFaderInView:rightPane x:160 label:@"EFEK" accent:PandaTheme::Purple() tag:1];
    _musicSlider = [self createFaderInView:rightPane x:280 label:@"MUSIK" accent:PandaTheme::Amber() tag:2];
    _masterSlider= [self createFaderInView:rightPane x:400 label:@"MASTER" accent:PandaTheme::Red() tag:3];

    // Meters
    _vocalMeter  = [[LEDMeterView alloc] initWithFrame:NSMakeRect(105, 160, 16, 360)];
    _fxMeter     = [[LEDMeterView alloc] initWithFrame:NSMakeRect(225, 160, 16, 360)];
    _musicMeter  = [[LEDMeterView alloc] initWithFrame:NSMakeRect(345, 160, 16, 360)];
    _masterMeter = [[LEDMeterView alloc] initWithFrame:NSMakeRect(465, 160, 16, 360)];

    [rightPane addSubview:_vocalMeter];
    [rightPane addSubview:_fxMeter];
    [rightPane addSubview:_musicMeter];
    [rightPane addSubview:_masterMeter];

    // Status bar at bottom of right pane
    NSView* statusBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 36)];
    statusBar.wantsLayer = YES;
    statusBar.layer.backgroundColor = PandaTheme::Background().CGColor;
    [rightPane addSubview:statusBar];

    NSTextField* statusText = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 8, 480, 20)];
    statusText.stringValue = @"DSP Load: 1.24% • Sample Rate: 48.0 kHz • CoreAudio Low-Latency";
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

- (NSSlider*)createFaderInView:(NSView*)parent x:(CGFloat)x label:(NSString*)label accent:(NSColor*)color tag:(NSInteger)tag {
    NSTextField* lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(x, 535, 60, 20)];
    lbl.stringValue = label;
    lbl.font = [NSFont boldSystemFontOfSize:11];
    lbl.textColor = color;
    lbl.alignment = NSTextAlignmentCenter;
    lbl.bezeled = NO;
    lbl.editable = NO;
    lbl.backgroundColor = [NSColor clearColor];
    [parent addSubview:lbl];

    NSSlider* slider = [[NSSlider alloc] initWithFrame:NSMakeRect(x + 15, 160, 30, 360)];
    slider.vertical = YES;
    slider.minValue = -48.0f;
    slider.maxValue = 6.0f;
    slider.floatValue = 0.0f;
    slider.tag = tag;
    slider.target = self;
    slider.action = @selector(onFaderChanged:);
    [parent addSubview:slider];

    NSButton* muteBtn = [[NSButton alloc] initWithFrame:NSMakeRect(x, 115, 60, 26)];
    muteBtn.title = @"MUTE";
    muteBtn.bezelStyle = NSBezelStyleRounded;
    [muteBtn setButtonType:NSButtonTypePushOnPushOff];
    muteBtn.tag = tag;
    muteBtn.target = self;
    muteBtn.action = @selector(onMuteToggled:);
    [parent addSubview:muteBtn];

    return slider;
}

- (void)onFaderChanged:(NSSlider*)sender {
    if (!_engine) return;
    float db = sender.floatValue;
    switch (sender.tag) {
        case 0: _engine->getVocalChannel().setVolumeDb(db); break;
        case 1: _engine->getFxChannel().setVolumeDb(db); break;
        case 2: _engine->getMusicChannel().setVolumeDb(db); break;
        case 3: _engine->getMasterChannel().setVolumeDb(db); break;
    }
}

- (void)onMuteToggled:(NSButton*)sender {
    if (!_engine) return;
    bool isMuted = (sender.state == NSControlStateValueOn);
    switch (sender.tag) {
        case 0: _engine->getVocalChannel().setMute(isMuted); break;
        case 1: _engine->getFxChannel().setMute(isMuted); break;
        case 2: _engine->getMusicChannel().setMute(isMuted); break;
        case 3: _engine->getMasterChannel().setMute(isMuted); break;
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
    switch (sender.tag) {
        case 0: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::TalkChitChat); break;
        case 1: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::PopStudio); break;
        case 2: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::AcousticWarm); break;
        case 3: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::DangdutMelayu); break;
        case 4: _engine->loadFactoryPreset(OnLive::DSP::FactoryPreset::ModernRnB); break;
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
    _vocalMeter.levelDb = _engine->getVocalChannel().getPeakMeterDb();
    _fxMeter.levelDb = _engine->getFxChannel().getPeakMeterDb();
    _musicMeter.levelDb = _engine->getMusicChannel().getPeakMeterDb();
    _masterMeter.levelDb = _engine->getMasterChannel().getPeakMeterDb();

    [_vocalMeter setNeedsDisplay:YES];
    [_fxMeter setNeedsDisplay:YES];
    [_musicMeter setNeedsDisplay:YES];
    [_masterMeter setNeedsDisplay:YES];
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
