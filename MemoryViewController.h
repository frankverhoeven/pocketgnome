//
//  MemoryViewController.h
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/16/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MemoryAccess.h"

@class Controller;
@class OffsetController;

@interface MemoryViewController : NSView {
    IBOutlet Controller *controller;
	IBOutlet OffsetController *offsetController;
    IBOutlet id memoryTable;
    IBOutlet id memoryViewWindow;
    IBOutlet NSView *view;
    NSNumber *_currentAddress;
    NSTimer *_refreshTimer;
	NSMutableDictionary *_lastValues;
	int _formatOfSavedValues;
	
	IBOutlet NSTableView	*bitTableView;
	IBOutlet NSPanel		*bitPanel;
	
	// search options
	IBOutlet NSPanel		*searchPanel;
	IBOutlet NSPopUpButton	*searchTypePopUpButton;
	IBOutlet NSPopUpButton	*operatorPopUpButton;
	IBOutlet NSMatrix		*signMatrix;
	IBOutlet NSMatrix		*valueMatrix;
	IBOutlet NSTextField	*searchText;
	IBOutlet NSButton		*searchButton;
	IBOutlet NSButton		*clearButton;
	IBOutlet NSTableView	*searchTableView;
	NSArray					*_searchArray;
	
	// offset scanning
	IBOutlet NSPanel		*offsetScanPanel;
	IBOutlet NSTextField	*resultsTextField;
	IBOutlet NSTextField	*maskTextField;
	IBOutlet NSTextField	*signatureTextField;
	IBOutlet NSButton		*emulatePPCButton;
	
	// pointer scanning
	IBOutlet NSPanel				*pointerScanPanel;
	IBOutlet NSProgressIndicator	*pointerScanProgressIndicator;
	IBOutlet NSTextField			*pointerScanNumTextField;
	IBOutlet NSTextField			*pointerScanVariationTextField;
	IBOutlet NSButton				*pointerScanVariationButton;
	IBOutlet NSButton				*pointerScanCancelButton;
	IBOutlet NSButton				*pointerScanFindButton;
	NSThread *_pointerScanThread;
    
    float refreshFrequency;
    int _displayFormat;
    int _displayCount;
    //id callback;
	
	// new pointer search
	NSMutableDictionary *_pointerList;
    
    id _wowObject;

    NSSize minSectionSize, maxSectionSize;
}

@property (readonly) NSView *view;
@property (readonly) NSString *sectionTitle;    
@property NSSize minSectionSize;
@property NSSize maxSectionSize;
@property (readwrite) float refreshFrequency;

- (void)showObjectMemory: (id)object;

- (void)monitorObject: (id)object;
- (void)monitorObjects: (id)objects;

- (void)setBaseAddress: (NSNumber*)address;

- (IBAction)setCustomAddress: (id)sender;
- (IBAction)clearTable: (id)sender;
- (IBAction)snapshotMemory: (id)sender;
- (IBAction)saveValues: (id)sender;
- (IBAction)clearValues: (id)sender;

// menu options
- (IBAction)menuAction: (id)sender;

- (int)displayFormat;
- (void)setDisplayFormat: (int)displayFormat;

// search option
- (IBAction)openSearch: (id)sender;
- (IBAction)startSearch: (id)sender;
- (IBAction)clearSearch: (id)sender;
- (IBAction)typeSelected: (id)sender;

// offset scanning
- (IBAction)openOffsetPanel: (id)sender;
- (IBAction)offsetSelectAction: (id)sender;

// pointer scanning
- (IBAction)openPointerPanel: (id)sender;
- (IBAction)pointerSelectAction: (id)sender;

@end
