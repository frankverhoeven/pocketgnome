//
//  WoWFaction.h
//  Pocket Gnome
//
//  Created by Josh on 12/28/10.
//  Copyright 2010 Savory Software, LLC
//

#import <Cocoa/Cocoa.h>
#import "ClientDbDefines.h"

@interface WoWFaction : NSObject {

	// private!
	FactionTemplateDbcRecord _template;
	FactionDbcRecord _record;
	
	int _id;
}

- (NSString*)name;
- (NSString*)description;
- (BOOL)isValid;
- (WoWFaction*)parentFaction;

@end
