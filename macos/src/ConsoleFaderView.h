#pragma once
#import <Cocoa/Cocoa.h>

@interface ConsoleFaderView : NSControl

@property (nonatomic, copy) NSString* channelName;
@property (nonatomic, strong) NSColor* accentColor;
@property (nonatomic, assign) float volumeDb;
@property (nonatomic, assign) float meterDb;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, assign) BOOL isSoloed;

@property (nonatomic, copy) void (^onVolumeChanged)(float db);
@property (nonatomic, copy) void (^onMuteChanged)(BOOL muted);
@property (nonatomic, copy) void (^onSoloChanged)(BOOL soloed);

- (instancetype)initWithFrame:(NSRect)frame
                  channelName:(NSString*)name
                  accentColor:(NSColor*)color
                      initialDb:(float)db;

- (void)updateMeterDb:(float)meterDb;

@end
