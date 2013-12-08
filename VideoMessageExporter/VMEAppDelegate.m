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
static NSString * const kProgress = @"kProgress";
static NSString * const kConnection = @"kConnection";
static NSString * const kData = @"kData";
static NSString * const kDataSize = @"kDataSize";

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
			if(argv[i]) {
				pathURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%s", argv[i]]];
			}
		} else if(strcmp("author", azColName[i]) == 0) {
			author = [NSString stringWithFormat:@"%s",argv[i]];
		} else if(strcmp("creation_timestamp", azColName[i]) == 0) {
			NSDate *date;
			if(argv[i]) {
				date = [NSDate dateWithTimeIntervalSince1970:strtod(argv[i], NULL)];
			} else {
				date = [NSDate date];
			}
			
			timestamp = [date descriptionWithCalendarFormat:@"%Y-%m-%d %H.%M.%S" timeZone:nil locale:nil];
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
	NSError *error = nil;
	sqlite3 *db;
	int rc;
	char *errMsg;
	char tmpFileName[] = "/tmp/skypedb.XXXXXX";
	char *dbPath = (char *)path;
	
	// Make temporary filename to copy database to
	mktemp(tmpFileName);
	
	// Copy skype DB to temporary file so we can open it while it is running
	if ([[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%s",path] toPath:[NSString stringWithFormat:@"%s",tmpFileName]  error:&error]) {
		dbPath = tmpFileName;
	} else {
		NSLog(@"Error creating temporary db file. %@", error);
	}
	
	NSLog(@"Opening %s", dbPath);
	
	rc = sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, NULL);
	
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
	
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%s",tmpFileName] error:&error];
}

- (IBAction)downloadSelected:(id)sender {
	
	NSUInteger index = [[_myTableView selectedRowIndexes] firstIndex];
	
	while(index != NSNotFound) {

		//[[NSWorkspace sharedWorkspace] openURL:[[videos objectAtIndex:index] objectForKey:kPath ]];
		NSMutableDictionary *dict = [videos objectAtIndex:index];
		NSURLRequest *newRequest = [NSURLRequest requestWithURL:[dict objectForKey:kPath] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
		NSMutableData *newData = [NSMutableData dataWithCapacity:0];
		NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:newRequest delegate:self];
		
		if (!theConnection) {
			// Release the receivedData object.
			[dict removeObjectForKey:kConnection];
			[dict removeObjectForKey:kData];
			
			NSLog(@"Error downloading %@", [dict objectForKey:kPath] );
		} else {
			[dict setObject:newData forKey:kData];
			[dict setObject:theConnection forKey:kConnection];
			NSLog(@"Downloading %@", [dict objectForKey:kPath]);
			[dict setObject:@"Downloading..." forKey:kProgress];
			[_myTableView reloadData];
		}
		
		index = [[_myTableView selectedRowIndexes] indexGreaterThanIndex:index];
	}
}

- (void)addVideoMessageWithURL: (NSURL *)url author:(NSString *)author timestamp:(NSString *)timestamp {
	NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] init];
	
	if(url != nil) {
		[tmpDict setObject:url forKey:kPath];
		[tmpDict setObject:author forKey:kAuthor];
		[tmpDict setObject:timestamp forKey:kTimestamp];
		[tmpDict setObject:currentUsername forKey:kUsername];
		[videos addObject:tmpDict];
	}
}

-(NSMutableDictionary *)getDictForConnection:(NSURLConnection *)connection {
	NSMutableDictionary *connectionDict = nil;
	for(NSInteger index=0; index < [videos count]; index++) {
		if([[[videos objectAtIndex:index] objectForKey:kConnection] isEqualTo:connection]) {
			connectionDict = [videos objectAtIndex:index];
			break;
		}
	}
	
	return connectionDict;
}

#pragma mark -
#pragma mark NSTableViewDelegate Methods

-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [videos count];
}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if([tableView isEqualTo:_myTableView]) {
		
	}
	return [[videos objectAtIndex:row] objectForKey:[tableColumn identifier]];
}

#pragma mark -
#pragma mark NSURLConnectionDataDelegate Methods

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	NSMutableData *connectionData;
	NSMutableDictionary *dict = [self getDictForConnection:connection];
	
	if(dict != nil) {
		if([response expectedContentLength] == NSURLResponseUnknownLength) {
			
		} else {
			connectionData = [dict objectForKey:kData];
			[connectionData setLength:0];
		}
		
		[dict setObject:[NSNumber numberWithInteger:[response expectedContentLength]] forKey:kDataSize];
	}
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	NSMutableData *connectionData;
	NSMutableDictionary *dict = [self getDictForConnection:connection];
	
	if(dict != nil) {
		connectionData = [dict objectForKey:kData];
		[connectionData appendData:data];
		[dict setObject:[NSString stringWithFormat:@"%3.1f%%", [connectionData length]/[[dict objectForKey:kDataSize] doubleValue] * 100.0] forKey:kProgress];
		[_myTableView reloadData];
	}
}

#pragma mark -
#pragma mark NSURLConnectionDelegate Methods
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSMutableData *connectionData;
	NSMutableDictionary *dict = [self getDictForConnection:connection];
	
	if(dict != nil) {
		[dict removeObjectForKey:kConnection];
		connectionData = [dict objectForKey:kData];
		[connectionData setLength:0];
		[dict setObject:@"ERROR" forKey:kProgress];
		[_myTableView reloadData];
	}
	
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSMutableData *connectionData;
	NSMutableDictionary *dict = [self getDictForConnection:connection];
	
	if(dict != nil) {
		connectionData = [dict objectForKey:kData];

		NSString *outFileName = [NSHomeDirectory() stringByAppendingPathComponent:@"/Desktop"];
		outFileName = [outFileName stringByAppendingString:[NSString stringWithFormat:@"/%@%@.mp4", [dict objectForKey:kAuthor], [dict objectForKey:kTimestamp]]];
		
		if([[dict objectForKey:kDataSize] integerValue] == NSURLResponseUnknownLength) {
			NSLog(@"Error downloading %@", outFileName);
			[connectionData setLength:0];
			[dict removeObjectForKey:kConnection];
			[dict removeObjectForKey:kData];
			[dict setObject:@"ERROR 401" forKey:kProgress];
			[_myTableView reloadData];
		} else {
			[connectionData writeToURL:[NSURL fileURLWithPath:outFileName] atomically:YES];
			
			NSLog(@"Successfully downloaded %@", outFileName);
			
			[connectionData setLength:0];
			[dict removeObjectForKey:kConnection];
			[dict removeObjectForKey:kData];
			[dict setObject:@"Done!" forKey:kProgress];
			[_myTableView reloadData];
		}
	}

}

@end
