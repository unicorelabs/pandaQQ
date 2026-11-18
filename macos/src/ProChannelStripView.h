#pragma once
#import <Cocoa/Cocoa.h>
#import "ProRotaryKnobView.h"
#import "ConsoleFaderView.h"

typedef NS_ENUM(NSInteger, ProChannelStripType) {
    ProChannelTypeVocal,
    ProChannelTypeFX,
    ProChannelTypeMusic,
    ProChannelTypeMaster,
    ProChannelTypeAux
};

@interface ProChannelStripView : NSView

@property (nonatomic, assign) ProChannelStripType channelType;
@property (nonatomic, copy) NSString* channelName;
@property (nonatomic, strong) NSColor* accentColor;
@property (nonatomic, copy) NSString* channelIcon; // e.g. @"🎙️", @"✨", @"♫", @"🔊"
@property (nonatomic, assign) BOOL isSelected;

// Components
@property (nonatomic, strong) NSPopUpButton* presetPopup;
@property (nonatomic, strong) NSPopUpButton* inputPopup;
@property (nonatomic, strong) NSPopUpButton* outputPopup;
@property (nonatomic, strong) NSPopUpButton* sendsPopup;
@property (nonatomic, strong) NSMutableArray<NSPopUpButton*>* insertPopups;
@property (nonatomic, strong) ProRotaryKnobView* hpfKnob;
@property (nonatomic, strong) ProRotaryKnobView* lpfKnob;
@property (nonatomic, strong) ProRotaryKnobView* panKnob;
@property (nonatomic, strong) ConsoleFaderView* faderView;

// Callbacks
@property (nonatomic, copy) void (^onVolumeChanged)(float db);
@property (nonatomic, copy) void (^onPanChanged)(float pan);
@property (nonatomic, copy) void (^onHpfChanged)(float hz);
@property (nonatomic, copy) void (^onLpfChanged)(float hz);
@property (nonatomic, copy) void (^onMuteChanged)(BOOL muted);
@property (nonatomic, copy) void (^onSoloChanged)(BOOL soloed);
@property (nonatomic, copy) void (^onInputChanged)(NSString* inputDevice);
@property (nonatomic, copy) void (^onOutputChanged)(NSString* outputDevice);
@property (nonatomic, copy) void (^onInsertChanged)(NSInteger slot, NSString* effectName);
@property (nonatomic, copy) void (^onPresetSelected)(NSString* presetName);
@property (nonatomic, copy) void (^onChannelClicked)(void);

- (instancetype)initWithFrame:(NSRect)frame
                  channelType:(ProChannelStripType)type
                  channelName:(NSString*)name
                  accentColor:(NSColor*)accentColor
                         icon:(NSString*)icon;

- (void)updateAvailableInputs:(NSArray<NSString*>*)inputs;
- (void)updateAvailableOutputs:(NSArray<NSString*>*)outputs;
- (void)setMeterLevelDb:(float)peakDb rms:(float)rmsDb;

@end

