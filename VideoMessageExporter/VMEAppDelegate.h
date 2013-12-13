//
//  VMEAppDelegate.h
//  VideoMessageExporter
//
//  Created by Alvaro Prieto on 12/7/13.
//  Copyright (c) 2013 Alvaro Prieto. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface VMEAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTableView *myTableView;

@property (weak) IBOutlet NSTextField *savePathTextField;
- (IBAction)downloadSelected:(id)sender;
- (IBAction)refreshFiles:(id)sender;
- (IBAction)selecPathButton:(id)sender;
- (void)addVideoMessageWithURL: (NSURL *)url author:(NSString *)author timestamp:(NSString *)timestamp;

@end
