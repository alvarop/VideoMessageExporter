//
//  VMEAppDelegate.m
//  VideoMessageExporter
//
//  Created by Alvaro Prieto on 12/7/13.
//  Copyright (c) 2013 Alvaro Prieto. All rights reserved.
//

#import "VMEAppDelegate.h"
#include <sqlite3.h>

sqlite3 *db;

//
// Called for each matched row
//
static int sqlite_callback(void *caller, int argc, char **argv, char **azColName) {
	VMEAppDelegate *delegate = (__bridge id)(caller);
	NSURL *pathURL = nil;
	NSString *author = nil;
	NSDate *timestamp = nil;
	
	// Go through each column
	for(uint32_t i = 0; i < argc; i++) {
		if(strcmp("vod_path", azColName[i]) == 0) {
			pathURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%s", argv[i]]];
		} else if(strcmp("author", azColName[i]) == 0) {
			author = [NSString stringWithFormat:@"%s",argv[i]];
		} else if(strcmp("creation_timestamp", azColName[i]) == 0) {
			if(argv[i]) {
				timestamp = [NSDate dateWithTimeIntervalSince1970:strtod(argv[i], NULL)];
			} else {
				timestamp = [NSDate date];
			}
		}
	}
	
	[delegate addVideoMessageWithURL:pathURL author:author timestamp:timestamp];
	
	return 0;
}

@implementation VMEAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	char path[] = "/Users/alvaro/Library/Application Support/Skype/apg88zx/main.db.bak";
	int rc;
	char *errMsg;
	
	rc = sqlite3_open(path, &db);
	
	if(rc) {
		NSLog(@"Can't open database: %s\n", sqlite3_errmsg(db));
		sqlite3_close(db);
	}
	
	rc = sqlite3_exec(db, "SELECT vod_path,author,creation_timestamp from VideoMessages;", sqlite_callback, (__bridge void *)(self), &errMsg);
	if(rc != SQLITE_OK) {
		NSLog(@"SQL error: %s\n", errMsg);
		sqlite3_free(errMsg);
	}
	
	sqlite3_close(db);
}

- (void)addVideoMessageWithURL: (NSURL *)url author:(NSString *)author timestamp:(NSDate *)timestamp {
	NSLog(@"Adding video message!\nurl: %@\nauthor: %@\ntimestamp: %@", url, author, timestamp);
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

@end
