//
//  Route.m
//  Pocket Gnome
//
//  Created by Jon Drummond on 12/16/07.
//  Copyright 2007 Savory Software, LLC. All rights reserved.
//

#import "Route.h"

@implementation Route

- (id) init
{
    self = [super init];
    if (self != nil) {
        self.waypoints = [NSArray array];
    }
    return self;
}

+ (id)route {
    Route *route = [[Route alloc] init];
    
    return [route autorelease];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super init];
	if(self) {
        self.waypoints = [decoder decodeObjectForKey: @"Waypoints"] ? [decoder decodeObjectForKey: @"Waypoints"] : [NSArray array];
	}
	return self;
}

-(void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject: self.waypoints forKey: @"Waypoints"];
}

- (id)copyWithZone:(NSZone *)zone
{
    Route *copy = [[[self class] allocWithZone: zone] init];
    copy.waypoints = self.waypoints;
    
    // log(LOG_GENERAL, @"Old route: %@", self.waypoints);
    // log(LOG_GENERAL, @"New route: %@", copy.waypoints);
    
    return copy;
}

- (void) dealloc
{
    self.waypoints = nil;
    [super dealloc];
}

#pragma mark -

- (NSString*)description {
    return [NSString stringWithFormat: @"<0x%X Route: %d waypoints>", self, [self waypointCount]];
}

@synthesize waypoints = _waypoints;

- (void)setWaypoints: (NSArray*)wps {
    [_waypoints autorelease];
    if(wps) {
        _waypoints = [[NSMutableArray alloc] initWithArray: wps copyItems: YES];
    } else {
        _waypoints = nil;
    }
}

- (unsigned)waypointCount {
    return _waypoints ? [_waypoints count] : 0;
}

- (Waypoint*)waypointAtIndex: (unsigned)index {
    if(index >= 0 && index < [_waypoints count])
        return [[[_waypoints objectAtIndex: index] retain] autorelease];
    return nil;
}

- (Waypoint*)waypointClosestToPosition: (Position*)position {
    Waypoint *closestWP = nil;
    float minDist = INFINITY, tempDist = 0;
    for ( Waypoint *waypoint in [self waypoints] ) {
        tempDist = [position distanceToPosition: [waypoint position]];
		//log(LOG_GENERAL, @" %0.2f < %0.2f  %@", tempDist, minDist, waypoint);
        if ( (tempDist < minDist) && (tempDist >= 0.0f) ) {
            minDist = tempDist;
            closestWP = waypoint;
        }
    }

	log(LOG_MOVEMENT, @"Closest WP found at a distance of %0.2f  Vertical Distance: %0.2f Total waypoints searched: %d", minDist, [position verticalDistanceToPosition:[closestWP position]], [[self waypoints] count]);
	
    return [[closestWP retain] autorelease];
}

- (void)addWaypoint: (Waypoint*)waypoint {
    if(waypoint != nil) {
        log(LOG_DEV, @"addWaypoint: adding waypoint");
        [_waypoints addObject: waypoint];
   } else {
        log(LOG_GENERAL, @"addWaypoint: failed; waypoint is nil");
   }
}

- (void)insertWaypoint: (Waypoint*)waypoint atIndex: (unsigned)index {
    if(waypoint != nil && index >= 0 && index <= [_waypoints count])
        [_waypoints insertObject: waypoint atIndex: index];
    else
        log(LOG_GENERAL, @"insertWaypoint:atIndex: failed; either waypoint is nil or index is out of bounds");
}

- (void)removeWaypoint: (Waypoint*)waypoint {
    if(waypoint == nil) return;
    [_waypoints removeObject: waypoint];
}

- (void)removeWaypointAtIndex: (unsigned)index {
    if(index >= 0 && index < [_waypoints count])
        [_waypoints removeObjectAtIndex: index];
}

- (void)removeAllWaypoints {
    [_waypoints removeAllObjects];
}

- (int)indexOfWaypoint:(Waypoint*)wp{
	int index = 0;
	for ( ; index < [_waypoints count]; index++ ){
		
		if ( [[_waypoints objectAtIndex:index] isEqual:wp] ){
			return index;
		}
	}
	
	return -1;
}

// returns a new route w/the shortest distance in b/t the two waypoints
- (Route*)routeFromWP:(Waypoint*)fromWP toWP:(Waypoint*)toWP compare:(BOOL)compare{
	
	NSLog(@"finding shortest route from %@ to %@", fromWP, toWP);
	
	// find our waypoints
	int fromIndex = [self indexOfWaypoint:fromWP];
	int toIndex = [self indexOfWaypoint:toWP];
	
	// the 2 different ways we can go!
	NSMutableArray *goLeftRoute = [NSMutableArray array];
	NSMutableArray *goRightRoute = [NSMutableArray array];
	
	float leftDist = 0.0f, rightDist = 0.0f;
	BOOL routeComplete = NO;
	
	// run right (this is how PG has always operated, just increment the route by 1 and keep going down the list)
	int i = fromIndex;
	while ( !routeComplete ){
		
		Waypoint *l = [_waypoints objectAtIndex:i];
		[goRightRoute addObject:l];
		
		// we're at the end, reset to the beginning!
		if ( i == [_waypoints count]-1 ){
			i = -1;
		}
		
		Waypoint *r = [_waypoints objectAtIndex:i+1];
		
		float dist = [[l position] distanceToPosition:[r position]];
		
		//NSLog(@" %0.2f %@ %@", dist, r, l);
		
		rightDist += dist;
		
		if ( i+1 == toIndex ){
			NSLog(@" ** full route going right complete! %0.2f", rightDist);
			break;
		}
		
		i++;
	}
	
	// no comparison!
	if ( !compare ){
		Route *route = [Route route];
		[route setWaypoints:goRightRoute];
		return [[route retain] autorelease];
	}
	
	
	routeComplete = NO;
	// run left
	i = fromIndex;
	while ( !routeComplete ){
		
		Waypoint *r = [_waypoints objectAtIndex:i];
		[goLeftRoute addObject:r];
		
		// then the waypoint to the left or r is going to be at the end of our array!
		if ( i == 0 ){
			i = [_waypoints count];
		}
		
		Waypoint *l = [_waypoints objectAtIndex:i-1];
		
		float dist = [[r position] distanceToPosition:[l position]];
		
		//NSLog(@" %0.2f %@ %@", dist, l, r);
		
		leftDist += dist;
		
		if ( i-1 == toIndex ){
			NSLog(@" ** full route going left complete! %0.2f", leftDist);
			break;
		}
		
		i--;
	}
	
	Route *route = [Route route];
	
	// right wins!
	if ( rightDist < leftDist ){
		[route setWaypoints:goRightRoute];
	}
	
	// left wins
	else{
		[route setWaypoints:goLeftRoute];
	}
	
	return [[route retain] autorelease];
}

@end
