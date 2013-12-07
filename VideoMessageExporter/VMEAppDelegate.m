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

static int sqlite_callback(void *caller, int argc, char **argv, char **azColName) {
	VMEAppDelegate *delegate = (__bridge id)(caller);
	
	for(uint32_t i = 0; i < argc; i++) {
		NSLog(@"%s = %s\n", azColName[i], argv[i] ? argv[i] : "NULL");
	}
	
	[delegate testFunction];
	
	return 0;
}

@implementation VMEAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	
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

- (void)testFunction {
	NSLog(@"Test function!");
}

@end
