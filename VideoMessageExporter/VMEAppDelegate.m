//
//  VMEAppDelegate.m
//  VideoMessageExporter
//
//  Created by Alvaro Prieto on 12/7/13.
//  Copyright (c) 2013 Alvaro Prieto. All rights reserved.
//

#import "VMEAppDelegate.h"
#include <sqlite3.h>

static NSString * const kPath = @"kPath";
static NSString * const kTimestamp = @"kTimestamp";
static NSString * const kAuthor = @"kAuthor";
static NSString * const kUsername = @"kUsername";

//
// Called for each matched row
//
static int sqlite_callback(void *caller, int argc, char **argv, char **azColName) {
	VMEAppDelegate *delegate = (__bridge id)(caller);
	NSURL *pathURL = nil;
	NSString *author = nil;
	NSString *timestamp = nil;
	
	// Go through each column
	for(uint32_t i = 0; i < argc; i++) {
		if(strcmp("vod_path", azColName[i]) == 0) {
			pathURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%s", argv[i]]];
		} else if(strcmp("author", azColName[i]) == 0) {
			author = [NSString stringWithFormat:@"%s",argv[i]];
		} else if(strcmp("creation_timestamp", azColName[i]) == 0) {
			NSDate *date;
			if(argv[i]) {
				date = [NSDate dateWithTimeIntervalSince1970:strtod(argv[i], NULL)];
			} else {
				date = [NSDate date];
			}
			
			timestamp = [date descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M" timeZone:nil locale:nil];
		}
	}
	
	[delegate addVideoMessageWithURL:pathURL author:author timestamp:timestamp];
	
	return 0;
}

@implementation VMEAppDelegate {
	NSString *currentUsername;
	NSMutableArray *videos;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	videos = [[NSMutableArray alloc] init];
	[_myTableView setDataSource:self];
	
	NSDictionary *files = [self getDBFiles];
	NSEnumerator *enumerator = [files keyEnumerator];

	for(NSString *username in enumerator) {
		currentUsername = username;
		[self loadMessageInfoFromFile:[[files objectForKey:username] fileSystemRepresentation]];
	}
	
	[_myTableView reloadData];
	
	NSLog(@"Found %ld Video Messages", [videos count]);
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

-(NSDictionary *)getDBFiles {
	NSString *basePath = [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Application Support/Skype"];
	NSFileManager *fileManager = [[NSFileManager alloc] init];
	NSURL *directoryURL = [NSURL fileURLWithPath:basePath];
	NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
	NSMutableDictionary *paths = [[NSMutableDictionary alloc] init];
	
	NSLog(@"Searching %@", basePath);
	
	NSDirectoryEnumerator *enumerator = [fileManager
										 enumeratorAtURL:directoryURL
										 includingPropertiesForKeys:keys
										 options:0
										 errorHandler:^(NSURL *url, NSError *error) {
											 // Handle the error.
											 // Return YES if the enumeration should continue after the error.
											 return YES;
										 }];
	
	for (NSURL *url in enumerator) {
		NSError *error;
		NSNumber *isDirectory = nil;
		if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
			NSLog(@"ERROR: %@", error);
		} else if (![isDirectory boolValue]) {
			if([[url lastPathComponent] isEqualToString:@"main.db"]) {
				NSArray *pathComponents = [url pathComponents];
				NSString *username = [pathComponents objectAtIndex:[pathComponents count] - 2];
				
				[paths setObject:url forKey:username];
			}
		}
	}
	
	return paths;
}

//
// Open sqlite db and get VideoMessages table
//
-(void)loadMessageInfoFromFile:(const char *)path {
	sqlite3 *db;
	int rc;
	char *errMsg;
	
	NSLog(@"Opening %s", path);
	
	rc = sqlite3_open(path, &db);
	
	if(rc) {
		NSLog(@"Can't open database: %s\n", sqlite3_errmsg(db));
		sqlite3_close(db);
	}
	
	rc = sqlite3_exec(db, "SELECT vod_path,author,creation_timestamp from VideoMessages;", sqlite_callback, (__bridge void *)(self), &errMsg);
	if(rc != SQLITE_OK) {
		NSLog(@"SQL error: %s\n", errMsg);
		sqlite3_free(errMsg);
		sqlite3_close(db);
		
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:@"OK"];
		[alert setMessageText:@"Error opening Skype database"];
		[alert setInformativeText:@"Close Skype and restart the application."];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert beginSheetModalForWindow:[self window] completionHandler:^(NSInteger response){[NSApp terminate:self];}];
		
	}
	
	sqlite3_close(db);
}

- (IBAction)downloadSelected:(id)sender {
	
	NSUInteger index = [[_myTableView selectedRowIndexes] firstIndex];
	
	while(index != NSNotFound) {

		[[NSWorkspace sharedWorkspace] openURL:[[videos objectAtIndex:index] objectForKey:kPath ]];
		
		index = [[_myTableView selectedRowIndexes] indexGreaterThanIndex:index];
	}
}

- (void)addVideoMessageWithURL: (NSURL *)url author:(NSString *)author timestamp:(NSString *)timestamp {
	[videos addObject:@{kPath:url, kAuthor:author, kTimestamp:timestamp, kUsername:currentUsername}];
}

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [videos count];
}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if([tableView isEqualTo:_myTableView]) {
		
	}
	return [[videos objectAtIndex:row] objectForKey:[tableColumn identifier]];
}

@end
