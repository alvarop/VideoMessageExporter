//
//  VMEAppDelegate.m
//  VideoMessageExporter
//
//  Created by Alvaro Prieto on 12/7/13.
//  Copyright (c) 2013 Alvaro Prieto. All rights reserved.
//

#import "VMEAppDelegate.h"
#include <sqlite3.h>

static NSString * const kURI = @"kURI";
static NSString * const kThumbmail = @"kThumbnail";
static NSString * const kWebUrl = @"kWebUrl";
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

static int sqlite_callback_messages(void *caller, int argc, char **argv, char **azColName) {
    VMEAppDelegate *delegate = (__bridge id)(caller);
    NSString *author = nil;
    NSString *timestamp = nil;
    NSString *body_xml = nil;
    
    // Go through each column
    for(uint32_t i = 0; i < argc; i++) {
        if(strcmp("author", azColName[i]) == 0) {
            author = [NSString stringWithFormat:@"%s",argv[i]];
        } else if(strcmp("timestamp", azColName[i]) == 0) {
            NSDate *date;
            if(argv[i]) {
                date = [NSDate dateWithTimeIntervalSince1970:strtod(argv[i], NULL)];
            } else {
                date = [NSDate date];
            }
            
            timestamp = [date descriptionWithCalendarFormat:@"%Y-%m-%d %H.%M.%S" timeZone:nil locale:nil];
        } else if(strcmp("body_xml", azColName[i]) == 0) {
            body_xml = [NSString stringWithFormat:@"%s",argv[i]];
        }
    }
    NSRange xml = [body_xml rangeOfString:@"Video.1/Message.1"];
    if(xml.location != NSNotFound) {
        NSRange uri_range = [body_xml rangeOfString:@" uri=\""];
        NSRange url_thumb_range = [body_xml rangeOfString:@"\" url_thumb"];
        
        NSString *uri = [body_xml substringWithRange:NSMakeRange(uri_range.location+uri_range.length, url_thumb_range.location-(uri_range.location+uri_range.length))];
        
        [delegate addLocalVideoMessageWithURI:uri author:author timestamp: timestamp];
    }
    
    return 0;
}

static int sqlite_callback_media_documents(void *caller, int argc, char **argv, char **azColName) {
    VMEAppDelegate *delegate = (__bridge id)(caller);
    NSString *uri = nil;
    NSString *thumbnail_url = nil;
    NSString *web_url = nil;
    // Go through each column
    for(uint32_t i = 0; i < argc; i++) {
//        NSLog(@"%s %s", azColName[i], argv[i]);
        if(strcmp("uri", azColName[i]) == 0) {
            uri = [NSString stringWithFormat:@"%s",argv[i]];
        } if(strcmp("thumbnail_url", azColName[i]) == 0) {
            thumbnail_url = [NSString stringWithFormat:@"%s",argv[i]];
        } if(strcmp("web_url", azColName[i]) == 0) {
            web_url = [NSString stringWithFormat:@"%s",argv[i]];
        }
    }
    
    [delegate addMediaFileWithURI:uri thumbnail_url:thumbnail_url web_url:web_url];
    return 0;
}


@implementation VMEAppDelegate {
	NSString *currentUsername;
    NSString *currentPath;
	NSMutableArray *videos;
    NSMutableArray *mediaFiles;
	NSURL *saveDirectory;
}

-(void)updateSaveDirectory {
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	[panel setCanChooseDirectories:YES];
	[panel setCanCreateDirectories:YES];
	[panel setCanChooseFiles:NO];
	[panel setAllowsMultipleSelection:NO];
	[panel setTitle:@"Select save path"];
	
	[panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
		if (result == NSFileHandlingPanelOKButton) {
			NSArray* urls = [panel URLs];
			if([[NSFileManager defaultManager] fileExistsAtPath:[[urls objectAtIndex:0] path]]) {
				saveDirectory = [urls objectAtIndex:0];
				[_savePathTextField setStringValue:[[urls objectAtIndex:0] path]];
			}
		}
	}];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	saveDirectory = [NSURL URLWithString:[NSHomeDirectory() stringByAppendingPathComponent:@"/Desktop"]];
	[_savePathTextField setStringValue:[saveDirectory absoluteString]];
	[self refreshFiles:nil];
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
                NSString *path = [[url path] stringByDeletingLastPathComponent];
                NSLog(@"Adding %@", path);
				[paths setObject:path forKey:username];
			}
		}
	}
	
	return paths;
}

//
// Open sqlite db and get VideoMessages table
//
-(void)loadMessageInfoFromFile:(NSString *)path showError:(BOOL)showError {
//	NSError *error = nil;
	sqlite3 *main_db;
	int rc;
	char *errMsg;
    currentPath = path;
    NSLog(@"Loading %@", path);
	char *mainDBPath = (char*)[[path stringByAppendingString:@"/main.db"] cStringUsingEncoding:NSUTF8StringEncoding];

	NSLog(@"Opening %s", mainDBPath);
	
	rc = sqlite3_open_v2(mainDBPath, &main_db, SQLITE_OPEN_READONLY, NULL);
	
	if(rc) {
		NSLog(@"Can't open database: %s\n", sqlite3_errmsg(main_db));
		sqlite3_close(main_db);
    } else {
	
        rc = sqlite3_exec(main_db, "SELECT vod_path,author,creation_timestamp from VideoMessages;", sqlite_callback, (__bridge void *)(self), &errMsg);
        
        if(rc != SQLITE_OK) {
            NSLog(@"SQL error: %s\n", errMsg);
        }
        
        rc = sqlite3_exec(main_db, "SELECT uri,thumbnail_url,web_url FROM MediaDocuments WHERE type='Video.1/Message.1';", sqlite_callback_media_documents, (__bridge void *)(self), &errMsg);
        
        if(rc != SQLITE_OK) {
            NSLog(@"SQL error: %s\n", errMsg);
        }
        
        rc = sqlite3_exec(main_db, "SELECT author,timestamp,body_xml FROM Messages;", sqlite_callback_messages, (__bridge void *)(self), &errMsg);
        
        if(rc != SQLITE_OK) {
            NSLog(@"SQL error: %s\n", errMsg);
            sqlite3_free(errMsg);
            sqlite3_close(main_db);
            
            if(showError) {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert setMessageText:@"Error opening Skype database"];
                [alert setInformativeText:[NSString stringWithFormat:@"Close Skype and restart the application.\n(%s)", mainDBPath]];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert beginSheetModalForWindow:[self window] completionHandler:^(NSInteger response){NSLog(@"Error opening Skype database (%s)", mainDBPath);}];
            }
        }
        
        sqlite3_close(main_db);
    }
	
}

- (IBAction)downloadSelected:(id)sender {
	
	NSUInteger index = [[_myTableView selectedRowIndexes] firstIndex];
	
	while(index != NSNotFound) {
        
		NSMutableDictionary *dict = [videos objectAtIndex:index];
        
        if([[[dict objectForKey:kPath] absoluteString] rangeOfString:@"login.skype.com"].location != NSNotFound) {
            [[NSWorkspace sharedWorkspace] openURL:[[videos objectAtIndex:index] objectForKey:kPath ]];
            [dict setObject:@"Opening..." forKey:kProgress];
            [_myTableView reloadData];
        } else {
 
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
        }
		index = [[_myTableView selectedRowIndexes] indexGreaterThanIndex:index];
	}
}

- (IBAction)refreshFiles:(id)sender {
	videos = [[NSMutableArray alloc] init];
    mediaFiles = [[NSMutableArray alloc] init];
	[_myTableView setDataSource:self];
	
	NSDictionary *files = [self getDBFiles];
    NSLog(@"got the files");
	NSEnumerator *enumerator = [files keyEnumerator];
	
	for(NSString *username in enumerator) {
		currentUsername = username;

        [self loadMessageInfoFromFile:[files objectForKey:username] showError:(sender == nil)];
	}
	
	[_myTableView reloadData];
	
	NSLog(@"Found %ld Video Messages", [videos count]);
}

- (IBAction)selecPathButton:(id)sender {
	[self updateSaveDirectory];
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

- (void)addLocalVideoMessageWithURI: (NSString *)uri author:(NSString *)author timestamp:(NSString *)timestamp{
    NSLog(@"Looking for %@", uri);
    
    for (uint32_t index =0; index < [mediaFiles count]; index++){
        
        if([[[mediaFiles objectAtIndex:index] objectForKey:kURI] isEqualToString: uri]) {
            NSURL *url = [NSURL URLWithString:[[mediaFiles objectAtIndex:index] objectForKey:kWebUrl]];
            [self addVideoMessageWithURL:url author:author timestamp:timestamp];
            
        }
    }
}

- (void)addMediaFileWithURI: (NSString *)uri thumbnail_url:(NSString *)thumbnail_url web_url:(NSString *)web_url {
    NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] init];
    
    if((uri != nil) && (web_url != nil)) {
        [tmpDict setObject:uri forKey:kURI];
        [tmpDict setObject:thumbnail_url forKey:kThumbmail];
        [tmpDict setObject:web_url forKey:kWebUrl];
        [mediaFiles addObject:tmpDict];
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

		NSString *outFileName = [saveDirectory path];
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
