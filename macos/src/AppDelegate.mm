#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // 1. Initialize Core Audio DSP Engine
    self.audioEngine = std::make_shared<OnLive::DSP::AudioEngine>();
    self.audioEngine->initialize(48000.0f, 256);

    // 2. Initialize CoreAudio HAL Manager
    self.halManager = [[CoreAudioHALManager alloc] initWithAudioEngine:self.audioEngine];
    [self.halManager start];

    // 3. Create Main Window
    self.mainWindowController = [[MainWindowController alloc] initWithAudioEngine:self.audioEngine
                                                                      halManager:self.halManager];
    [self.mainWindowController showWindow:nil];
    [self.mainWindowController.window makeKeyAndOrderFront:nil];

    [NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    if (self.halManager) {
        [self.halManager stop];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

