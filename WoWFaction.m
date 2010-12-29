//
//  WoWFaction.m
//  Pocket Gnome
//
//  Created by Josh on 12/28/10.
//  Copyright 2010 Savory Software, LLC
//

#import "WoWFaction.h"
#import "ClientDbDefines.h"
#import "DatabaseManager.h"

@implementation WoWFaction

- (id)init{
    self = [super init];
    if ( self != nil ){
		_id = 0;
	}
	return self;
}

- (id)initWithID: (int)theID andTemplate:(BOOL)isTemplate {
    self = [self init];
    if ( self ) {
		_id = theID;
		if ( [self isValid] ){
		
			if ( isTemplate ){
				[[DatabaseManager sharedController] getObjectForRow:_id withTable:FactionTemplate withStruct:&_template withStructSize:(size_t)sizeof(_template)];
				[[DatabaseManager sharedController] getObjectForRow:_template.FactionId withTable:Faction withStruct:&_record withStructSize:(size_t)sizeof(_template)];
			}
			else{
				[[DatabaseManager sharedController] getObjectForRow:_id withTable:Faction withStruct:&_record withStructSize:(size_t)sizeof(_template)];
			}
			
			NSLog(@"done...");
			NSLog(@"%s", _record.Name);
			NSLog(@"%s", _record.Description);
		}
    }
	
    return self;
}

+ (WoWFaction*)WoWFactionWithID: (int)theID andTemplate:(BOOL)isTemplate {
    return [[[WoWFaction alloc] initWithID:theID andTemplate:isTemplate] autorelease];
}

- (void)dealloc{
	[super dealloc];
}

#pragma mark 

- (NSString*)name{
	NSLog(@"%s", _record.Name);
	return nil;
}

- (NSString*)description{
	NSLog(@"%s", _record.Description);
	return nil;
}

- (BOOL)isValid{
	return _id != 0;
}

- (WoWFaction*)parentFaction{
	
}



/*
- (int)CompareFactions:(WoWFaction)factionA againstFaction:(WoWFaction)FactionB{
	
	FactionTemplateDbcRecord atmpl = factionA._template;
	FactionTemplateDbcRecord btmpl = factionB._template;
	
	if ((btmpl.FightSupport & atmpl.HostileMask) != 0)
	{
		return (WoWUnitRelation) 1;
	}
	
	for (int i = 0; i < 4; i++)
	{
		if (atmpl.EnemyFactions[i] == btmpl.Id)
		{
			return (WoWUnitRelation) 1;
		}
		if (atmpl.EnemyFactions[i] == 0)
		{
			break;
		}
	}
	
	if ((btmpl.FightSupport & atmpl.FriendlyMask) != 0)
	{
		return (WoWUnitRelation) 4;
	}
	
	for (int i = 0; i < 4; i++)
	{
		if (atmpl.FriendlyFactions[i] == btmpl.Id)
		{
			return (WoWUnitRelation) 4;
		}
		if (atmpl.FriendlyFactions[i] == 0)
		{
			break;
		}
	}
	
	if ((atmpl.FightSupport & btmpl.FriendlyMask) != 0)
	{
		return (WoWUnitRelation) 4;
	}
	
	for (int i = 0; i < 4; i++)
	{
		if (btmpl.FriendlyFactions[i] == atmpl.Id)
		{
			return (WoWUnitRelation) 4;
		}
		if (btmpl.FriendlyFactions[i] == 0)
		{
			break;
		}
	}
	
	return (WoWUnitRelation) (~(byte) ((uint) atmpl.FactionFlags >> 12) & 2 | 1);
	
}*/

@end
