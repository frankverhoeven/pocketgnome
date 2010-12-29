//
//  BlacklistItem.m
//  Pocket Gnome
//
//  Created by Josh on 12/29/10.
//  Copyright 2010 Savory Software, LLC
//

#import "BlacklistItem.h"
#import "Position.h"

@implementation BlacklistItem

- (id) init{
    self = [super init];
    if (self != nil) {
        self.name = nil;
        self.description = nil;
		self.type = @"Unknown";
		self.position = nil;
    }
    return self;
}

@synthesize name = _name;
@synthesize description = _description;
@synthesize type = _type;
@synthesize position = _position;

// load
- (id)initWithCoder:(NSCoder *)decoder{
	self = [self init];
	if ( self ) {
		
		self.name = [decoder decodeObjectForKey:@"Name"];
		self.description = [decoder decodeObjectForKey:@"Description"];
		self.type = [decoder decodeObjectForKey:@"Type"];
		
		float x = [[decoder decodeObjectForKey:@"X"] floatValue];
		float y = [[decoder decodeObjectForKey:@"Y"] floatValue];
		float z = [[decoder decodeObjectForKey:@"Z"] floatValue];
		
		Position *pos = [Position positionWithX:x Y:y Z:z];
		self.position = pos;
	}
	return self;
}

// save
- (void)encodeWithCoder:(NSCoder *)coder{
	[coder encodeObject: self.name forKey:@"Name"];
	[coder encodeObject: self.description forKey:@"Description"];
	[coder encodeObject: self.type forKey:@"Type"];
	[coder encodeObject: [NSNumber numberWithFloat:[self.position xPosition]] forKey:@"X"];
	[coder encodeObject: [NSNumber numberWithFloat:[self.position yPosition]] forKey:@"Y"];
	[coder encodeObject: [NSNumber numberWithFloat:[self.position zPosition]] forKey:@"Z"];
}

// copy
- (id)copyWithZone:(NSZone *)zone{
    BlacklistItem *copy = [[[self class] allocWithZone: zone] initWithName: self.name];
	copy.name = self.name;
	copy.description = self.description;
	copy.type = self.type;
	copy.position = self.position;
    return copy;
}

@end
