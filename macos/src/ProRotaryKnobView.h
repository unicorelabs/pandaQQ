#pragma once
#import <Cocoa/Cocoa.h>

@interface ProRotaryKnobView : NSControl

@property (nonatomic, copy) NSString* label;
@property (nonatomic, assign) float value; // 0.0 to 1.0 (or -1.0 to 1.0 for Pan)
@property (nonatomic, assign) BOOL isPan;
@property (nonatomic, copy) NSString* valueDisplayString;
@property (nonatomic, copy) void (^onValueChanged)(float val);

- (instancetype)initWithFrame:(NSRect)frame
                        label:(NSString*)label
                        isPan:(BOOL)isPan
                 initialValue:(float)val;

@end
