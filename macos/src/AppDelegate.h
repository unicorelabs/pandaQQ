#pragma once
#import <Cocoa/Cocoa.h>
#import "MainWindowController.h"
#import "CoreAudioHALManager.h"
#include "AudioEngine.hpp"
#include <memory>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) MainWindowController* mainWindowController;
@property (nonatomic, strong) CoreAudioHALManager* halManager;
@property (nonatomic, assign) std::shared_ptr<OnLive::DSP::AudioEngine> audioEngine;

@end

