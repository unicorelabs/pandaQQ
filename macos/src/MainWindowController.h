#pragma once
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include "AudioEngine.hpp"
#import "CoreAudioHALManager.h"
#include <memory>

@interface MainWindowController : NSWindowController <WKNavigationDelegate>

- (instancetype)initWithAudioEngine:(std::shared_ptr<OnLive::DSP::AudioEngine>)engine
                         halManager:(CoreAudioHALManager*)halManager;

@end
