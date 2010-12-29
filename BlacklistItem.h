//
//  BlacklistItem.h
//  Pocket Gnome
//
//  Created by Josh on 12/29/10.
//  Copyright 2010 Savory Software, LLC
//

#import <Cocoa/Cocoa.h>

@class Position;

@interface BlacklistItem : NSObject {

	NSString *_name;
	NSString *_description;
	NSString *_type;			// Mob, Node
	Position *_position;
}

@property (readwrite, retain) NSString *name;
@property (readwrite, retain) NSString *description;
@property (readwrite, retain) NSString *type;
@property (readwrite, retain) Position *position;

@end
