#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main([[maybe_unused]] int argc, [[maybe_unused]] const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
