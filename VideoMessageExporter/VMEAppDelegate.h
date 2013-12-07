//
//  VMEAppDelegate.h
//  VideoMessageExporter
//
//  Created by Alvaro Prieto on 12/7/13.
//  Copyright (c) 2013 Alvaro Prieto. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VMEAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

- (void)addVideoMessageWithURL: (NSURL *)url author:(NSString *)author timestamp:(NSDate *)timestamp;

@end
