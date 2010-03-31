/*
 * Copyright (c) 2007-2010 Savory Software, LLC, http://pg.savorydeviate.com/
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * $Id$
 *
 */

#import <Cocoa/Cocoa.h>

@class Controller;
@class ChatLogEntry;
@class OffsetController;

#define WhisperReceived		@"WhisperReceived"

@interface ChatLogController : NSObject {
    IBOutlet Controller *controller;
	IBOutlet OffsetController *offsetController;
    
    IBOutlet NSView *view;
    IBOutlet NSTableView *chatLogTable, *whisperLogTable;
    IBOutlet NSPredicateEditor *ruleEditor;
    IBOutlet NSArrayController *chatActionsController;
    IBOutlet NSPanel *relayPanel;
	
	IBOutlet NSButton *enableGrowlNotifications;

    NSUInteger passNumber;
    BOOL _shouldScan, _lastPassFoundChat, _lastPassFoundWhisper;
    NSMutableArray *_chatLog, *_chatActions, *_whisperLog;
    NSSize minSectionSize, maxSectionSize;
    NSDateFormatter *_timestampFormat;
    NSSortDescriptor *_passNumberSortDescriptor;
    NSSortDescriptor *_relativeOrderSortDescriptor;
	NSMutableDictionary *_whisperHistory;				// Tracks player name with # of whispers
}

// Controller interface
@property (readonly) NSView *view;
@property (readonly) NSString *sectionTitle;
@property NSSize minSectionSize;
@property NSSize maxSectionSize;

- (IBAction)something: (id)sender;
- (IBAction)createChatAction: (id)sender;
- (IBAction)sendEmail: (id)sender;

- (IBAction)openRelayPanel: (id)sender;
- (IBAction)closeRelayPanel: (id)sender;

- (BOOL)sendLogEntry: (ChatLogEntry*)logEntry toiChatBuddy: (NSString*)buddyName;
- (BOOL)sendLogEntries: (NSArray*)logEntries toiChatBuddy: (NSString*)buddyName;

- (BOOL)sendLogEntry: (ChatLogEntry*)logEntry toEmailAddress: (NSString*)emailAddress;
- (BOOL)sendLogEntries: (NSArray*)logEntries toEmailAddress: (NSString*)emailAddress;

- (void)clearWhisperHistory;

@property (readonly, retain) NSMutableArray *chatActions;

@property (readwrite, assign) BOOL shouldScan;
@property (readwrite, assign) BOOL lastPassFoundChat;

@end
