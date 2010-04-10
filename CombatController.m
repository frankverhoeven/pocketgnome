//
//  CombatController.m
//  Pocket Gnome
//
//  Created by Josh on 12/19/09.
//  Copyright 2009 Savory Software, LLC. All rights reserved.
//

#import "CombatController.h"
#import "PlayersController.h"
#import "AuraController.h"
#import "MobController.h"
#import "BotController.h"
#import "PlayerDataController.h"
#import "BlacklistController.h"
#import "MovementController.h"
#import "Controller.h"
#import "AuraController.h"
#import "MacroController.h"

#import "Unit.h"
#import "Rule.h"
#import "CombatProfile.h"
#import "Behavior.h"

#import "ImageAndTextCell.h"

@interface CombatController ()
@property (readwrite, retain) Unit *attackUnit;
@property (readwrite, retain) Unit *castingUnit;
@property (readwrite, retain) Unit *addUnit;
@end

@interface CombatController (Internal)
- (NSArray*)friendlyUnits;
- (NSRange)levelRange;
- (int)weight: (Unit*)unit PlayerPosition:(Position*)playerPosition;
- (void)stayWithUnit;
- (NSArray*)combatListValidated;
- (void)updateCombatTable;
- (void)monitorUnit: (Unit*)unit;
@end

@implementation CombatController

- (id) init{
    self = [super init];
    if (self != nil) {
        
		_attackUnit		= nil;
		_friendUnit		= nil;
		_addUnit		= nil;
		_castingUnit	= nil;
		
		_enteredCombat = nil;
		
		_inCombat = NO;
		_hasStepped = NO;
		
		_unitsAttackingMe = [[NSMutableArray array] retain];
		_unitsAllCombat = [[NSMutableArray array] retain];
		_unitLeftCombatCount = [[NSMutableDictionary dictionary] retain];
		_unitLeftCombatTargetCount = [[NSMutableDictionary dictionary] retain];
		
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(playerHasDied:) name: PlayerHasDiedNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(playerEnteringCombat:) name: PlayerEnteringCombatNotification object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(playerLeavingCombat:) name: PlayerLeavingCombatNotification object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(invalidTarget:) name: ErrorInvalidTarget object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(targetOutOfRange:) name: ErrorTargetOutOfRange object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(targetNotInLOS:) name: ErrorTargetNotInLOS object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(targetNotInFront:) name: ErrorTargetNotInFront object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(morePowerfullSpellActive:) name: ErrorMorePowerfullSpellActive object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(unitDied:) 
                                                     name: UnitDiedNotification 
                                                   object: nil];
    }
    return self;
}

- (void) dealloc
{
	[_unitsAttackingMe release];
	[_unitsAllCombat release];
	[_unitLeftCombatCount release];
	[_unitLeftCombatTargetCount release];
    [super dealloc];
}

@synthesize attackUnit = _attackUnit;
@synthesize castingUnit = _castingUnit;
@synthesize addUnit = _addUnit;
@synthesize inCombat = _inCombat;

#pragma mark -

int DistFromPositionCompare(id <UnitPosition> unit1, id <UnitPosition> unit2, void *context) {
    
    //PlayerDataController *playerData = (PlayerDataController*)context; [playerData position];
    Position *position = (Position*)context; 
	
    float d1 = [position distanceToPosition: [unit1 position]];
    float d2 = [position distanceToPosition: [unit2 position]];
    if (d1 < d2)
        return NSOrderedAscending;
    else if (d1 > d2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

int WeightCompare(id unit1, id unit2, void *context) {
	
	NSDictionary *dict = (NSDictionary*)context;

	NSNumber *w1 = [dict objectForKey:[NSNumber numberWithLongLong:[unit1 GUID]]];
	NSNumber *w2 = [dict objectForKey:[NSNumber numberWithLongLong:[unit2 GUID]]];
	
	int weight1=0, weight2=0;
	
	if ( w1 )
		weight1 = [w1 intValue];
	if ( w2 )
		weight2 = [w2 intValue];
	
	log(LOG_DEV, @"WeightCompare: (%@)%d vs. (%@)%d", unit1, weight1, unit2, weight2);

    if (weight1 > weight2)
        return NSOrderedAscending;
    else if (weight1 < weight2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
	
	return NSOrderedSame;
}

#pragma mark Notifications

- (void)playerEnteringCombat: (NSNotification*)notification {
    log(LOG_DEV, @"------ Player Entering Combat ------");
	
	_inCombat = YES;
}

- (void)playerLeavingCombat: (NSNotification*)notification {
    log(LOG_DEV, @"------ Player Leaving Combat ------");
	
	_inCombat = NO;
	
	[self cancelAllCombat];
}

- (void)playerHasDied: (NSNotification*)notification {
	log(LOG_COMBAT, @"Player has died!");
	
	[self cancelAllCombat];
}

// invalid target
- (void)invalidTarget: (NSNotification*)notification {
	log(LOG_DEV, @"[Notification] %@ %@ is an Invalid Target!", [self unitHealthBar: [botController castingUnit]], [botController castingUnit]);

//	if ( [botController castingUnit] && ![[botController procedureInProgress] isEqualToString: CombatProcedure] ) {
	if ( [botController castingUnit] ) {
		log(LOG_BLACKLIST, @"%@ %@ is an Invalid Target, blacklisting.", [self unitHealthBar: [botController castingUnit]], [botController castingUnit]);
		[blacklistController blacklistObject:[botController castingUnit] withReason:Reason_InvalidTarget];
	}

	[botController cancelCurrentProcedure];
	[self cancelAllCombat];
	[botController evaluateSituation];
}

// not in LoS
- (void)targetNotInLOS: (NSNotification*)notification {
	log(LOG_DEV, @"[Notification] %@ %@ is not in LoS!", [self unitHealthBar: [botController castingUnit]], [botController castingUnit]);

	if ([botController castingUnit]) {
		log(LOG_BLACKLIST, @"%@ %@ is not in LoS, blacklisting.", [self unitHealthBar: [botController castingUnit]], [botController castingUnit]);
		[blacklistController blacklistObject:[botController castingUnit] withReason:Reason_NotInLoS];
	}

	[botController cancelCurrentProcedure];
	[self cancelAllCombat];
	[botController evaluateSituation];
	
}

// target is out of range
- (void)targetOutOfRange: (NSNotification*)notification {

	// If this is a combat target
//	if ([botController castingUnit] == [self castingUnit]) {

		// if we can correct this error
		if ( [movementController checkUnitOutOfRange:[self castingUnit]] ) {
			[botController cancelCurrentProcedure];
			[self cancelAllCombat];
			[botController actOnUnit: _castingUnit];
			return;
		}
//	}

	log(LOG_DEV, @"[Notification] %@ %@ is out of range, disengaging.", [self unitHealthBar: [botController castingUnit]], [botController castingUnit]);

//	if ([botController castingUnit]) {
// If it's out of range it won't be selected again if we cancel the procedure so why blacklist and potentially screw ourselves if it comes back into range
//		log(LOG_BLACKLIST, @"%@ %@ is out of range, blacklisting.", [self unitHealthBar: [botController castingUnit]], [botController castingUnit]);
//		[blacklistController blacklistObject:[botController castingUnit] withReason:Reason_OutOfRange];
//	}

	[botController cancelCurrentProcedure];
	[self cancelAllCombat];
	[botController evaluateSituation];
	
}

- (void)morePowerfullSpellActive: (NSNotification*)notification {
	log(LOG_ERROR, @"You need to adjust your behavior so the previous spell doesn't cast if the player has a more powerfull buff!");
	
	if ([botController castingUnit]) {
		[blacklistController blacklistObject:[botController castingUnit] withReason:Reason_RecentlyHelpedFriend];
	}

	[botController cancelCurrentProcedure];
	[self cancelAllCombat];
	[botController evaluateSituation];
	
}

- (void)targetNotInFront: (NSNotification*)notification {
//	[botController cancelCurrentProcedure];

	log(LOG_COMBAT, @"%@ %@ is not in front, adjusting.", [self unitHealthBar: _castingUnit] ,_castingUnit);
	/*
	log(LOG_COMBAT, @"Stepping forward to try to unbug a bad casting position.");
	[movementController stepForward];
	usleep(50000);
	[movementController stopMovement];
	usleep(50000);
	[playerData faceToward: [_castingUnit position]];
	usleep(200000);
	 */
	[movementController establishPlayerPosition];

//	[botController actOnUnit: _castingUnit];
	
}

- (void)unitDied: (NSNotification*)notification{
	Unit *unit = [notification object];

	if ( unit == _addUnit ) {
		log(LOG_COMBAT, @"%@ %@ died, removing add.", [self unitHealthBar: unit] ,unit);
		[_addUnit release]; _addUnit = nil;
	} else 
		
	if ( unit == _castingUnit ) [self cancelAllCombat];

}
	
#pragma mark Public

// list of units we're in combat with, XXX NO friendlies XXX
// This is now updated to include units attacking party members
- (NSArray*)combatList{
	
	NSMutableArray *units = [NSMutableArray array];
	
	if ( [_unitsAttackingMe count] ) {
		[units addObjectsFromArray:_unitsAttackingMe];
	}
	
	// add the other units if we need to
	if ( _attackUnit!= nil && ![units containsObject:_attackUnit] && ![blacklistController isBlacklisted:_attackUnit] ) {
		[units addObject:_attackUnit];
		log(LOG_DEV, @"Adding attack unit: %@", _attackUnit);
	}
	
	// add our add
	if ( _addUnit != nil && ![units containsObject:_addUnit] && ![blacklistController isBlacklisted:_addUnit] ){
		[units addObject:_addUnit];
		log(LOG_COMBAT, @"[Bot] Adding add unit: %@", _addUnit);
	}
	
	// If we're in party mode we'll add the units our party members are in combat with
	if ( botController.theCombatProfile.partyEnabled && ![botController isOnAssist] ) {
		log(LOG_DEV, @"Checking to see if party members have agro.");
		UInt64 playerID;
		Player *player;
		UInt64 targetID;
		Mob *target;

		// Check only party members
		int i;
		for (i=1;i<=6;i++) {

			playerID = [playerData PartyMember: i];
			if ( playerID <= 0x0) break;
			
			// We don't add ourselves
			if ( playerID == [playerData GUID] ) continue;

			player = [playersController playerWithGUID: playerID];

			if ( ![player isValid] || ![player isInCombat] ) continue;

			targetID = [player targetID];
			target = [mobController mobWithGUID: targetID];

			if ( ![target isValid] || [target isDead] || ![target isInCombat] || ![playerData isHostileWithFaction: [target factionTemplate]] ) {
				log(LOG_DEV, @"%@ is invalid, dead, not in combat or not hostile", target);
				continue;
			}
			
			log(LOG_DEV, @"Adding party members unit: %@", target);
			// If we've made it this far our friend is in combat with the unit
			[units addObject: target];
		}

	}

	// sort
	NSMutableDictionary *dictOfWeights = [NSMutableDictionary dictionary];
	Position *playerPosition = [playerData position];
	for ( Unit *unit in units ){
		[dictOfWeights setObject: [NSNumber numberWithInt:[self weight:unit PlayerPosition:playerPosition]] forKey:[NSNumber numberWithUnsignedLongLong:[unit GUID]]];
	}
	[units sortUsingFunction: WeightCompare context: dictOfWeights];
	
	return [[units retain] autorelease];
}

// out of the units that are attacking us, which are valid for us to attack back?
- (NSArray*)combatListValidated{
	NSArray *units = [self combatList];
	NSMutableArray *validUnits = [NSMutableArray array];
	
	Position *playerPosition = [playerData position];
	float vertOffset = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"CombatBlacklistVerticalOffset"] floatValue];
	
	for ( Unit *unit in units ){
		
		if ( [blacklistController isBlacklisted:unit] ) {
			log(LOG_COMBAT, @"Not adding blacklisted unit to validated combat list: %@", unit);
			continue;
		}
		// ignore dead/evading/not valid units
		if ( [unit isDead] || [unit isEvading] || ![unit isValid] ){
			continue;
		}
		
		// ignore if vertical distance is too great
		if ( [[unit position] verticalDistanceToPosition: playerPosition] > vertOffset ) {
			continue;
		}
		
		// range changes if the unit is friendly or not
		float distanceToTarget = [playerPosition distanceToPosition:[unit position]];
		float attackRange = ( botController.theCombatProfile.attackRange > botController.theCombatProfile.engageRange ) ? botController.theCombatProfile.attackRange : botController.theCombatProfile.engageRange;
		float range = ([playerData isFriendlyWithFaction: [unit factionTemplate]] ? botController.theCombatProfile.healingRange : attackRange);
		if ( distanceToTarget > range ){
			continue;
		}

		if ( ![botController combatProcedureValidForUnit:unit] ) continue;

		[validUnits addObject:unit];		
	}	
	
	// sort
	NSMutableDictionary *dictOfWeights = [NSMutableDictionary dictionary];
	for ( Unit *unit in validUnits ){
		[dictOfWeights setObject: [NSNumber numberWithInt:[self weight:unit PlayerPosition:playerPosition]] forKey:[NSNumber numberWithUnsignedLongLong:[unit GUID]]];
	}
	[validUnits sortUsingFunction: WeightCompare context: dictOfWeights];

	return [[validUnits retain] autorelease];
}


- (BOOL)combatEnabled{
	return botController.theCombatProfile.combatEnabled;
}

// from performProcedureWithState (CombatProcedure)
// this will keep the unit targeted!
- (void)stayWithUnit:(Unit*)unit withType:(int)type{
	
	Unit *oldTarget = [_castingUnit retain];
	
	[_castingUnit release]; _castingUnit = nil;
	_castingUnit = [unit retain];
	
	// enemy
	if ( type == TargetEnemy ){
		_attackUnit = [unit retain];
	}
	// add
	else if ( type == TargetAdd ){
		_addUnit = [unit retain];
	}
	// friendly
	else if ( type == TargetFriend || type == TargetPet ){
		_friendUnit = [unit retain];
	}
	// otherwise lets clear our target (we're either targeting no one or ourself)
	else{
		[_castingUnit release];
		_castingUnit = nil;
	}
	
	// remember when we started w/this unit
	[_enteredCombat release]; _enteredCombat = [[NSDate date] retain];
	
	
	
	// stop monitoring our "old" unit - we ONLY want to do this in PvP as we'd like to know when the unit dies!
	if ( oldTarget && [botController isPvPing] ){
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(monitorUnit:) object: oldTarget];
		[oldTarget release];
	}
	
	// we want to monitor enemies to fire off notifications if they die!
	if ( type == TargetEnemy ){
		// cancel a previous request if it's going on
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(monitorUnit:) object: unit];
		
		// monitor again!
		[self monitorUnit:unit];
	}
	
	log(LOG_DEV, @"Now staying with %@", unit);
	
	// we don't need to monitor friendlies!
	if ( ![playerData isFriendlyWithFaction: [unit factionTemplate]] )
		[self stayWithUnit];
}

- (void)stayWithUnit{
	
	log(LOG_DEV, @"Staying with %@ in procedure %@", _castingUnit, [botController procedureInProgress]);
	// cancel other requests
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(stayWithUnit) object: nil];
	
	if ( _castingUnit == nil ) {
		log(LOG_COMBAT, @"No longer staying w/the unit");
		return;
	}
	
	// dead
	if ( [_castingUnit isDead] ){
		log(LOG_COMBAT, @"Unit is dead! %@", _castingUnit);
		return;
	}
	
	// sanity checks
	if ( ![_castingUnit isValid] || [_castingUnit isEvading] || [blacklistController isBlacklisted:_castingUnit] ) {
		log(LOG_COMBAT, @"STOP ATTACK: Invalid? (%d)  Evading? (%d)  Blacklisted? (%d)", ![_castingUnit isValid], [_castingUnit isEvading], [blacklistController isBlacklisted:_castingUnit]);
		return;
	}
	
	if ( [playerData isDead] ){
		log(LOG_COMBAT, @"You died, stopping attack.");
		return;
	}
	
	// no longer in combat procedure
	if ( ![[botController procedureInProgress] isEqualToString:CombatProcedure] ){
		log(LOG_COMBAT, @"No longer in combat procedure, no longer staying with unit");
		return;
	}
	
	BOOL isCasting = [playerData isCasting];
	
	// check player facing vs. unit position
	Position *playerPosition = [playerData position];
	float playerDirection = [playerData directionFacing];
	float theAngle = [playerPosition angleTo: [_castingUnit position]];
	
	// compensate for the 2pi --> 0 crossover
	if(fabsf(theAngle - playerDirection) > M_PI) {
		if(theAngle < playerDirection)  theAngle        += (M_PI*2);
		else                            playerDirection += (M_PI*2);
	}
	
	// find the difference between the angles
	float angleTo = fabsf(theAngle - playerDirection);
	
	// if the difference is more than 90 degrees (pi/2) M_PI_2, reposition
	if( (angleTo > 0.785f) ) {  // changed to be ~45 degrees
		log(LOG_COMBAT, @"[Combat] Unit is behind us (%.2f). Repositioning.", angleTo);
		
		// set player facing and establish position
		//BOOL useSmooth = [movementController useSmoothTurning];
		
		//if(!isCasting) [movementController pauseMovement];
		[movementController turnTowardObject: _castingUnit];
		//if(!isCasting && !useSmooth) {
		//	[movementController backEstablishPosition];
		//}
	}

	if( !isCasting ) {
		
		// ensure unit is our target
		UInt64 unitGUID = [_castingUnit GUID];
		
		if ( ( [playerData targetID] != unitGUID) || [_castingUnit isFeignDeath] ) [playerData targetGuid:unitGUID];
		
		// move toward unit?
		if ( [botController.theBehavior meleeCombat] ){
			
			if ( [playerPosition distanceToPosition: [_castingUnit position]] > 5.0f ){
				log(LOG_COMBAT, @"[Combat] Moving to %@", _castingUnit);
				
				[movementController moveToObject:_castingUnit];	//andNotify: NO
			}
		}
	}
	
	// tell/remind bot controller to attack
	//[botController attackUnit: _castingUnit];
	[self performSelector: @selector(stayWithUnit) withObject: nil afterDelay: 0.25];
}

- (void)cancelAllCombat{
	
	log(LOG_DEV, @"All combat cancelled");
	
	// cancel selecting the unit!
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(stayWithUnit) object: nil];
	
	// cancel all requests!
	//[NSObject cancelPreviousPerformRequestsWithTarget: self];		// we're not calling this as it kills our monitor function + the death might not be fired!

	// reset our variables
	self.castingUnit = nil;
	self.attackUnit = nil;
	self.addUnit = nil;
	[_friendUnit release];	_friendUnit =  nil;
	
	// remove blacklisted units (TO DO: we should only remove those of type Unit)
//	[blacklistController removeAllUnits];
}

- (void)resetAllCombat{
	[self cancelAllCombat];
	[_unitLeftCombatCount removeAllObjects];
	[_unitLeftCombatTargetCount removeAllObjects];
	[NSObject cancelPreviousPerformRequestsWithTarget: self];
}

// units here will meet all conditions! Combat Profile WILL be checked
- (NSArray*)validUnitsWithFriendly:(BOOL)includeFriendly onlyHostilesInCombat:(BOOL)onlyHostilesInCombat {

	// *************************************************
	//	Find all available units!
	//		Add friendly units
	//		Add Assist unit if we're assisting!
	//		Add hostile/neutral units if we should
	//		Add units attacking us
	// *************************************************

	NSMutableArray *allPotentialUnits = [NSMutableArray array];
	BOOL needToAssist = NO;

	// add friendly units w/in range
	// only do this if we dont have the onlyHostilesInCombat flag
//	if ( ( botController.theCombatProfile.healingEnabled || includeFriendly ) && !onlyHostilesInCombat) {
	if ( ( botController.theCombatProfile.healingEnabled || includeFriendly ) ) {
		log(LOG_DEV, @"Adding friendlies to the list of valid units");
		[allPotentialUnits addObjectsFromArray:[self friendlyUnits]];
	}

	// Get the assist players target
	if ( [botController isOnAssist] && [[botController assistUnit] isInCombat] ) {

		UInt64 targetGUID = [[botController assistUnit] targetID];
		log(LOG_DEV, @"On assist, checking to see if I need to assist.");

		if ( targetGUID > 0x0) {
			log(LOG_DEV, @"Assist has a target.");
			Mob *mob = [mobController mobWithGUID:targetGUID];
			if ( mob && ![mob isDead]) {
				[allPotentialUnits addObject:mob];
				log(LOG_DEV, @"Adding my assist's target to list of valid units");
				needToAssist = YES;
			} else {
				log(LOG_DEV, @"My assist's target is dead!");
			}
		}
	}

	// add new units w/in range if we're not on assist
	if ( botController.theCombatProfile.combatEnabled && ![botController.theCombatProfile onlyRespond] && !onlyHostilesInCombat && ![botController isOnAssist] && !needToAssist) {
		log(LOG_DEV, @"Adding ALL available combat units");
		// determine attack range
		float attackRange = [botController.theCombatProfile engageRange];
		if ( botController.isPvPing && [botController.theCombatProfile attackRange] > [botController.theCombatProfile engageRange] )
			attackRange = [botController.theCombatProfile attackRange];
		[allPotentialUnits addObjectsFromArray:[self enemiesWithinRange:attackRange]];
	}
	
	// remove units attacking us from the list
	if ( [_unitsAttackingMe count] && !needToAssist) [allPotentialUnits removeObjectsInArray:_unitsAttackingMe];

	// add combat units that have been validated! (includes attack unit + add)
	NSArray *inCombatUnits = [self combatListValidated];
	if ( [inCombatUnits count] ) {
		log(LOG_DEV, @"Adding %d validated in combat units to list", [inCombatUnits count]);
		for ( Unit *unit in inCombatUnits ) if ( ![allPotentialUnits containsObject:unit] ) [allPotentialUnits addObject:unit];
	}
	
	log(LOG_DEV, @"Found %d potential units to validate", [allPotentialUnits count]);
	
	// *************************************************
	//	Validate all potential units - check for:
	//		Blacklisted
	//		Dead, evading, invalid
	//		Vertical distance
	//		Distance to target
	//		Ghost
	// *************************************************

	Position *playerPosition = [playerData position];
	NSMutableArray *validUnits = [NSMutableArray array];
	
	if ( [allPotentialUnits count] ){
		float vertOffset = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"CombatBlacklistVerticalOffset"] floatValue];
		float distanceToTarget = 0.0f, range = 0.0f;
		BOOL isFriendly = NO;
		
		for ( Unit *unit in allPotentialUnits ){

			if ( [blacklistController isBlacklisted:unit] ) {
				log(LOG_DEV, @":Ignoring blacklisted unit: %@", unit);
				continue;
			}

			if ( [unit isDead] || [unit isEvading] || ![unit isValid] ) continue;
			
			if ( [[unit position] verticalDistanceToPosition: playerPosition] > vertOffset ) continue;
			
			if ( !includeFriendly && [playerData isFriendlyWithFaction: [unit factionTemplate]] ) continue;

			if ( !includeFriendly && ![botController combatProcedureValidForUnit:unit] ) return NO;
			
			// range changes if the unit is friendly or not
			distanceToTarget = [playerPosition distanceToPosition:[unit position]];
			range = (self.inCombat ? (isFriendly ? botController.theCombatProfile.healingRange : botController.theCombatProfile.attackRange) : botController.theCombatProfile.engageRange);
			if ( distanceToTarget > range ) continue;
			
			// player: make sure they're not a ghost
			if ( [unit isPlayer] ) {
				NSArray *auras = [auraController aurasForUnit: unit idsOnly: YES];
				if ( [auras containsObject: [NSNumber numberWithUnsignedInt: 8326]] || [auras containsObject: [NSNumber numberWithUnsignedInt: 20584]] ) {
					continue;
				}
			}
			
			[validUnits addObject: unit];
		}
		
	}
	
	if ([validUnits count]) log(LOG_DEV, @"Found %d valid units", [validUnits count]);
	// sort
	NSMutableDictionary *dictOfWeights = [NSMutableDictionary dictionary];
	for ( Unit *unit in validUnits ) {
		[dictOfWeights setObject: [NSNumber numberWithInt:[self weight:unit PlayerPosition:playerPosition]] forKey:[NSNumber numberWithUnsignedLongLong:[unit GUID]]];
	}
	[validUnits sortUsingFunction: WeightCompare context: dictOfWeights];	
	return [[validUnits retain] autorelease];
}

// find a unit to attack, CC, or heal
- (Unit*)findUnitWithFriendly:(BOOL)includeFriendly onlyHostilesInCombat:(BOOL)onlyHostilesInCombat {

	log(LOG_FUNCTION, @"findUnitWithFriendly called");

	// flying check?
	if ( botController.theCombatProfile.ignoreFlying ) if ( ![playerData isOnGround] ) return nil;

	// no combat or healing?
	if ( !botController.theCombatProfile.healingEnabled && !botController.theCombatProfile.combatEnabled ) return nil;


	NSArray *validUnits = [NSArray arrayWithArray:[self validUnitsWithFriendly:includeFriendly onlyHostilesInCombat:onlyHostilesInCombat]];
	Position *playerPosition = [playerData position];

	if ( ![validUnits count] ) return nil;

	// Some weights can be pretty low so let's make sure we don't fail if comparing low weights
	int highestWeight = -500;

	Unit *bestUnit = nil;
	for ( Unit *unit in validUnits ) {
		
		// Let's make sure we can even act on this unit before we consider it
		if ( onlyHostilesInCombat && ![botController combatProcedureValidForUnit:unit] ) continue;

		// begin weight calculation
		int weight = [self weight:unit PlayerPosition:playerPosition];
		log(LOG_DEV, @"Valid target %@ found with weight %d", unit, weight);

		// best weight
		if ( weight > highestWeight ) {
			highestWeight = weight;
			bestUnit = unit;
		}
	}
	return bestUnit;	
}

- (NSArray*)allAdds {	
	NSMutableArray *allAdds = [NSMutableArray array];
	
	// loop through units that are attacking us!
	for ( Unit *unit in _unitsAttackingMe ) if ( unit != _attackUnit && ![unit isDead] ) [allAdds addObject:unit];
	
	return [[allAdds retain] autorelease];
}

// so, in a perfect world
// -) players before pets
// -) low health targets before high health targets
// -) closer before farther
// everything needs to be in combatProfile range

// assign 'weights' to each target based on current conditions/settings
// highest weight unit is our best target

// current target? +25
// player? +100 pet? +25
// hostile? +100, neutral? +100
// health: +(100-percentHealth)
// distance: 100*(attackRange - distance)/attackRange
- (int)weight: (Unit*)unit PlayerPosition:(Position*)playerPosition{

	float attackRange = (botController.theCombatProfile.engageRange > botController.theCombatProfile.attackRange) ? botController.theCombatProfile.engageRange : botController.theCombatProfile.attackRange;

	float distanceToTarget = [playerPosition distanceToPosition:[unit position]];

	BOOL isFriendly = [playerData isFriendlyWithFaction: [unit factionTemplate]];
	
	// begin weight calculation
	int weight = 0;
	
	// player or pet?
	if ([unit isPlayer]) weight += 100;
	
	if ( [unit isPet] ) {
		weight -= 25;
		// we hate pets!
		if ( !botController.theCombatProfile.attackPets ) weight -= 300;
	}

	// health left
	int healthLeft = (100-[unit percentHealth]);
	weight += healthLeft;
	
	// our add?
	if ( unit == _addUnit ) weight -= 50;
	
	// non-friendly checks only
	if ( !isFriendly ) {
		if ( attackRange > 0 ) weight += ( 100 * ((attackRange-distanceToTarget)/attackRange));

		
		// current target
		if ( [playerData targetID] == [unit GUID] ) weight += 30;
		
		// Hostile Players get even more weight
		if ([unit isPlayer]) weight += 25;

		// Assist mode - assists target
		if ( [botController isOnAssist] && [[botController assistUnit] isInCombat]) {
			UInt64 targetGUID = [[botController assistUnit] targetID];
			if ( targetGUID > 0x0) {
				Mob *assistMob = [mobController mobWithGUID:targetGUID];
				if ( unit == assistMob ) weight += 200;
			}
		}
		
		// Tanks target
		if ( [botController isTankUnit] && [[botController tankUnit] isInCombat]) {
			UInt64 targetGUID = [[botController tankUnit] targetID];
			if ( targetGUID > 0x0) {
				Mob *tankMob = [mobController mobWithGUID:targetGUID];
				if ( unit == tankMob ) weight += 100;	// Still less than the assist just in case
			}
		}
		
	} else {	
	// friendly?
		// tank gets a pretty big weight @ all times
		if ( botController.theCombatProfile.partyEnabled && botController.theCombatProfile.tankUnit && botController.theCombatProfile.tankUnitGUID == [unit GUID] )
			weight += healthLeft;
		weight *= 1.5;
	}
	return weight;
}
- (NSString*)unitHealthBar: (Unit*)unit {
	// lets build a log prefix that reflects units health
	NSString *logPrefix = nil;
	UInt32 unitPercentHealth = 0;
	if (unit) {
		unitPercentHealth = [unit percentHealth];
	} else {
		unitPercentHealth = [[playerData player] percentHealth];
	}
	if ([[playerData player] GUID] == [unit GUID] || !unit) {
		// Ourselves
		if (unitPercentHealth == 100)		logPrefix = @"[OOOOOOOOOOO]";
		else if (unitPercentHealth >= 90)	logPrefix = @"[OOOOOOOOOO ]";
		else if (unitPercentHealth >= 80)	logPrefix = @"[OOOOOOOOO  ]";
		else if (unitPercentHealth >= 70)	logPrefix = @"[OOOOOOOO   ]";
		else if (unitPercentHealth >= 60)	logPrefix = @"[OOOOOOO    ]";
		else if (unitPercentHealth >= 50)	logPrefix = @"[OOOOOO     ]";
		else if (unitPercentHealth >= 40)	logPrefix = @"[OOOOO      ]";
		else if (unitPercentHealth >= 30)	logPrefix = @"[OOOO       ]";
		else if (unitPercentHealth >= 20)	logPrefix = @"[OOO        ]";
		else if (unitPercentHealth >= 10)	logPrefix = @"[OO         ]";
		else if (unitPercentHealth > 0)		logPrefix = @"[O          ]";
		else								logPrefix = @"[           ]";		
	} else
	if ([playerData isFriendlyWithFaction: [unit factionTemplate]]) {
		// Friendly
		if (unitPercentHealth == 100)			logPrefix = @"[+++++++++++]";
			else if (unitPercentHealth >= 90)	logPrefix = @"[++++++++++ ]";
			else if (unitPercentHealth >= 80)	logPrefix = @"[+++++++++  ]";
			else if (unitPercentHealth >= 70)	logPrefix = @"[++++++++   ]";
			else if (unitPercentHealth >= 60)	logPrefix = @"[+++++++    ]";
			else if (unitPercentHealth >= 50)	logPrefix = @"[++++++     ]";
			else if (unitPercentHealth >= 40)	logPrefix = @"[+++++      ]";
			else if (unitPercentHealth >= 30)	logPrefix = @"[++++       ]";
			else if (unitPercentHealth >= 20)	logPrefix = @"[+++        ]";
			else if (unitPercentHealth >= 10)	logPrefix = @"[++         ]";
			else if (unitPercentHealth > 0)		logPrefix = @"[+          ]";
			else								logPrefix = @"[           ]";		
	} else {
		// Hostile
		if (unitPercentHealth == 100)			logPrefix = @"[***********]";
			else if (unitPercentHealth >= 90)	logPrefix = @"[********** ]";
			else if (unitPercentHealth >= 80)	logPrefix = @"[*********  ]";
			else if (unitPercentHealth >= 70)	logPrefix = @"[********   ]";
			else if (unitPercentHealth >= 60)	logPrefix = @"[*******    ]";
			else if (unitPercentHealth >= 50)	logPrefix = @"[******     ]";
			else if (unitPercentHealth >= 40)	logPrefix = @"[*****      ]";
			else if (unitPercentHealth >= 30)	logPrefix = @"[****       ]";
			else if (unitPercentHealth >= 20)	logPrefix = @"[***        ]";
			else if (unitPercentHealth >= 10)	logPrefix = @"[**         ]";
			else if (unitPercentHealth > 0)		logPrefix = @"[*          ]";
			else								logPrefix = @"[           ]";
	}
	 return logPrefix;
 }
		 
#pragma mark Enemy

- (int)weight: (Unit*)unit {
	return [self weight:unit PlayerPosition:[playerData position]];
}

// find available hostile targets
- (NSArray*)enemiesWithinRange:(float)range {

    NSMutableArray *targetsWithinRange = [NSMutableArray array];
	NSRange levelRange = [self levelRange];

	 // check for mobs?
	 if ( botController.theCombatProfile.attackNeutralNPCs || botController.theCombatProfile.attackHostileNPCs ) {
		 [targetsWithinRange addObjectsFromArray: [mobController mobsWithinDistance: range
																		 levelRange: levelRange
																	   includeElite: !(botController.theCombatProfile.ignoreElite)
																	includeFriendly: NO
																	 includeNeutral: botController.theCombatProfile.attackNeutralNPCs
																	 includeHostile: botController.theCombatProfile.attackHostileNPCs]];
	 }
	
	 // check for players?
	 if ( botController.theCombatProfile.attackPlayers ) {
		 [targetsWithinRange addObjectsFromArray: [playersController playersWithinDistance: range
																				levelRange: levelRange
																		   includeFriendly: NO
																			includeNeutral: NO
																			includeHostile: YES]];
	 }
	
	//log(LOG_COMBAT, @"[Combat] Found %d targets within range", [targetsWithinRange count]);
	
	return targetsWithinRange;
}

#pragma mark Friendly

- (BOOL)validFriendlyUnit: (Unit*)unit{
	
	NSArray *auras = [auraController aurasForUnit: unit idsOnly: YES];
	// regular dead - night elf ghost
	if ( [auras containsObject: [NSNumber numberWithUnsignedInt: 8326]] || [auras containsObject: [NSNumber numberWithUnsignedInt: 20584]] ){
		//log(LOG_COMBAT, @"[Combat] Friendly is a ghost! And dead! We should consider them invalid");
		return NO;
	}

	// We need to check:
	//	Not dead
	//	Friendly
	//	Could check position + health threshold + if they are moving away!
	if ( ![unit isDead] && [playerData isFriendlyWithFaction: [unit factionTemplate]] ){
		return YES;
	}
	
	return NO;
}

- (NSArray*)friendlyUnits{
	
	// get list of all targets
    NSMutableArray *friendliesWithinRange = [NSMutableArray array];
	NSMutableArray *friendlyTargets = [NSMutableArray array];
	
	// If we're in party mode and only supposed to help party members
	if ( botController.theCombatProfile.partyEnabled && botController.theCombatProfile.partyIgnoreOtherFriendlies ) {

		Player *player;
		UInt64 playerID;

		// Check only party members
		int i;
		for (i=1;i<=6;i++) {
			playerID = [playerData PartyMember: i];
			if ( playerID <= 0x0) break;
			
			// We don't add ourselves
			if ( playerID == [playerData GUID] ) continue;

			player = [playersController playerWithGUID: playerID];
			
			if ( ![player isValid] ) continue;

			[friendliesWithinRange addObject: player];
		}
		
	} else {

		// Check all friendlies
		[friendliesWithinRange addObjectsFromArray: [playersController allPlayers]];

	}

	// sort by range
    Position *playerPosition = [playerData position];
    [friendliesWithinRange sortUsingFunction: DistFromPositionCompare context: playerPosition];

	// if we have some targets
    if ( [friendliesWithinRange count] ) {
        for ( Unit *unit in friendliesWithinRange ) {
			log(LOG_DEV, @"Friendly - Checking %@", unit);
			if ( [self validFriendlyUnit:unit] ){
				log(LOG_DEV, @"Valid friendly");
				[friendlyTargets addObject: unit];
			}
        }
    }
	
	log(LOG_DEV, @"Total friendlies: %d", [friendlyTargets count]);
	
	return friendlyTargets;
}

#pragma mark Internal

// monitor unit until it dies
- (void)monitorUnit: (Unit*)unit{
	
	// invalid unit
	if ( !unit || ![unit isValid] ) {
		log(LOG_COMBAT, @"Unit isn't valid! %@", unit);
		return;
	}
	
	// unit died, fire off notification
	if ( [unit isDead] ){
		log(LOG_DEV, @"Firing death notification for unit %@", unit);
		[[NSNotificationCenter defaultCenter] postNotificationName: UnitDiedNotification object: [[unit retain] autorelease]];
		return;
	} 
	
	// unit has ghost aura (so is dead, fire off notification)
	NSArray *auras = [[AuraController sharedController] aurasForUnit: unit idsOnly: YES];
	if ( [auras containsObject: [NSNumber numberWithUnsignedInt: 8326]] || [auras containsObject: [NSNumber numberWithUnsignedInt: 20584]] ){
		log(LOG_COMBAT, @"%@ Firing death notification for player %@", [self unitHealthBar: unit], unit);
		[[NSNotificationCenter defaultCenter] postNotificationName: UnitDiedNotification object: [[unit retain] autorelease]];
		return;
	}
	
	// Tanaris4: I'd recommend using cachedGUID, as (in theory) an object's GUID shouldn't change + this saves memory reads
	GUID guid = [unit cachedGUID];
	
	// Unit not in combat check
	int leftCombatCount = [[_unitLeftCombatCount objectForKey:[NSNumber numberWithLongLong:guid]] intValue];

	if ( ![unit isInCombat] ) {
		
		float secondsInCombat = leftCombatCount/10;
		
		log(LOG_DEV, @"%@ Unit not in combat now for %d seconds", [self unitHealthBar: unit], secondsInCombat);
		leftCombatCount++;

		// If it's our target let's do some checks as we should be in combat
		if ( unit == _attackUnit ) {

			// This is to set timer if the unit actually our target vs being an add
			int leftCombatTargetCount = [[_unitLeftCombatTargetCount objectForKey:[NSNumber numberWithLongLong:guid]] intValue];
			
			secondsInCombat = leftCombatTargetCount/10;
			
			float combatBlacklistDelay = [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey: @"CombatBlacklistDelay"] floatValue];

			// not in combat after x seconds we blacklist for the short term, long enough to target something else or move
			if ( secondsInCombat >  combatBlacklistDelay ) {
				_hasStepped = NO;
				log(LOG_COMBAT, @"%@ Unit not in combat after %.2f seconds, temp blacklisting", [self unitHealthBar: unit], combatBlacklistDelay);
				[blacklistController blacklistObject:unit withReason:Reason_NotInCombatTemp];
				[self cancelAllCombat];
				return;
			} else

			// not in combat after 25 seconds we blacklist perm
			if ( secondsInCombat > 25 ) {
				_hasStepped = NO;
				log(LOG_COMBAT, @"%@ Unit not in combat after 25 seconds, seriously blacklisting", [self unitHealthBar: unit]);
				[blacklistController blacklistObject:unit withReason:Reason_NotInCombatPerm];
				[self cancelAllCombat];
				return;
			}
			
			leftCombatTargetCount++;
			[_unitLeftCombatTargetCount setObject:[NSNumber numberWithInt:leftCombatTargetCount] forKey:[NSNumber numberWithLongLong:guid]];
			log(LOG_DEV, @"%@ Monitoring %@", [self unitHealthBar: unit], unit);
		}

		// Unit is an add or not our primary target
		// after a minute stop monitoring
		if ( secondsInCombat > 60 ){
			_hasStepped = NO;
			log(LOG_COMBAT, @"%@ No longer monitoring %@, didn't enter combat after  %d seconds.", [self unitHealthBar: unit], unit, secondsInCombat);

			leftCombatCount = 0;
			[_unitLeftCombatCount setObject:[NSNumber numberWithInt:leftCombatCount] forKey:[NSNumber numberWithLongLong:guid]];

			return;
		}
		
	} else {
		log(LOG_DEV, @"%@ Monitoring %@", [self unitHealthBar: unit], unit);
		leftCombatCount = 0;
	}
	[_unitLeftCombatCount setObject:[NSNumber numberWithInt:leftCombatCount] forKey:[NSNumber numberWithLongLong:guid]];
	
	[self performSelector:@selector(monitorUnit:) withObject:unit afterDelay:0.1f];
}

// find all units we are in combat with
- (void)doCombatSearch{
	
	if ( [[playerData player] isDead] ){
		
		log(LOG_COMBAT, @"Dead, removing all objects!");
		
		[_unitsAttackingMe removeAllObjects];
		self.attackUnit = nil;
		self.addUnit = nil;
		self.castingUnit = nil;
		
		return;
	}
	
	// add all mobs + players
	NSArray *mobs = [mobController allMobs];
	NSArray *players = [playersController allPlayers];
	
	UInt64 playerGUID = [[playerData player] GUID];
	UInt64 unitTarget = 0;
	BOOL playerHasPet = [[playerData player] hasPet];
	BOOL tapCheckPassed = YES;
	
	for ( Mob *mob in mobs ){
		tapCheckPassed = YES;
		unitTarget = [mob targetID];
		
		if ([mob isTappedByOther] && !botController.theCombatProfile.partyEnabled && !botController.isPvPing) tapCheckPassed = NO;
		
		if (
			![mob isDead]	&&		// 1 - living units only
			[mob isInCombat] &&		// 2 - in Combat
			[mob isSelectable] &&	// 3 - can select this target
			[mob isAttackable] &&	// 4 - attackable
			//[mob isTapped] &&		// 5 - tapped - in theory someone could tap a target while you're casting, and you get agg - so still kill (removed as a unit @ 100% could attack us and not be tapped)
			tapCheckPassed &&	// lets give this one a go
			[mob isValid] &&		// 6 - valid mob
			(	(unitTarget == playerGUID ||										// 7 - targetting us
				 (playerHasPet && unitTarget == [[playerData player] petGUID]) ) ||	// or targetting our pet
			 [mob isFleeing])													// or fleeing
			){
			
			// add mob!
			if ( ![_unitsAttackingMe containsObject:(Unit*)mob] ){
				log(LOG_DEV, @"Adding mob %@", mob);
				[_unitsAttackingMe addObject:(Unit*)mob];
				[[NSNotificationCenter defaultCenter] postNotificationName: UnitEnteredCombat object: [[mob retain] autorelease]];
			}
		}
		// remove unit
		else if ( [_unitsAttackingMe containsObject:(Unit*)mob] ) {
			log(LOG_DEV, @"Removing mob %@", mob);
			[_unitsAttackingMe removeObject:(Unit*)mob];
		}
	}
	
	for ( Player *player in players ){
		unitTarget = [player targetID];
		if (
			![player isDead] &&										// 1 - living units only
			[player currentHealth] != 1 &&							// 2 - this should be a ghost check, being lazy for now
			[player isInCombat] &&									// 3 - in combat
			[player isSelectable] &&								// 4 - can select this target
			([player isAttackable] || [player isFeignDeath] ) &&	// 5 - attackable or feigned
			[player isValid] &&										// 6 - valid
			(	(unitTarget == playerGUID ||										// 7 - targetting us
				 (playerHasPet && unitTarget == [[playerData player] petGUID]) ) ||	// or targetting our pet
			 [player isFleeing])													// or fleeing
			){
			
			// add player
			if ( ![_unitsAttackingMe containsObject:(Unit*)player] ){
				log(LOG_COMBAT, @"[Combat] Adding player %@", player);
				[_unitsAttackingMe addObject:(Unit*)player];
				[[NSNotificationCenter defaultCenter] postNotificationName: UnitEnteredCombat object: [[player retain] autorelease]];
			}
		}
		// remove unit
		else if ( [_unitsAttackingMe containsObject:(Unit*)player] ) {
			log(LOG_COMBAT, @"[Combat] Removing player %@", player);
			[_unitsAttackingMe removeObject:(Unit*)player];
		}
	}
	
	// double check to see if we should remove any!
	NSMutableArray *unitsToRemove = [NSMutableArray array];
	for ( Unit *unit in _unitsAttackingMe ){
		if ( !unit || ![unit isValid] || [unit isDead] || ![unit isInCombat] || ![unit isSelectable] || ![unit isAttackable] ){
			log(LOG_COMBAT, @"[Combat] Removing unit: %@", unit);
			[unitsToRemove addObject:unit];
		}
	}
	if ( [unitsToRemove count] ){
		[_unitsAttackingMe removeObjectsInArray:unitsToRemove];
	}
	
	log(LOG_DEV, @"In combat with %d units", [_unitsAttackingMe count]);
	
	for ( Unit *unit in _unitsAttackingMe ){
		log(LOG_DEV, @"	%@", unit);
	}
}

// this will return the level range of mobs we are attacking!
- (NSRange)levelRange{
	
	// set the level of mobs/players we are attacking!
	NSRange range = NSMakeRange(0, 0);
	
	// any level
	if ( botController.theCombatProfile.attackAnyLevel ){
		range.length = 200;	// in theory this would be 83, but just making it a high value to be safe
		
		// ignore level one?
		if ( botController.theCombatProfile.ignoreLevelOne ){
			range.location = 2;
		}
		else{
			range.location = 1;
		}
	}
	// we have level requirements!
	else{
		range.location = botController.theCombatProfile.attackLevelMin;
		range.length = botController.theCombatProfile.attackLevelMax - botController.theCombatProfile.attackLevelMin;
	}
	
	return range;
}

#pragma mark UI

- (void)showCombatPanel{
	[combatPanel makeKeyAndOrderFront: self];
}

- (void)updateCombatTable{
	
	if ( [combatPanel isVisible] ){

		[_unitsAllCombat removeAllObjects];
		
		NSArray *allUnits = [self validUnitsWithFriendly:YES onlyHostilesInCombat:NO];
		NSMutableArray *allAndSelf = [NSMutableArray array];
		
		if ( [allUnits count] ){
			[allAndSelf addObjectsFromArray:allUnits];
		}
		[allAndSelf addObject:[playerData player]];
		
		Position *playerPosition = [playerData position];
		
		for(Unit *unit in allAndSelf) {
			if( ![unit isValid] )
				continue;
			
			float distance = [playerPosition distanceToPosition: [unit position]];
			unsigned level = [unit level];
			if(level > 100) level = 0;
			int weight = [self weight: unit PlayerPosition:playerPosition];
			
			NSString *name = [unit name];
			if ( (name == nil || [name length] == 0) && ![unit isNPC] ){
				[name release]; name = nil;
				name = [playersController playerNameWithGUID:[unit GUID]];
			}
			
			if ( [unit GUID] == [[playerData player] GUID] ){
				weight = 0;
			}
			
			[_unitsAllCombat addObject: [NSDictionary dictionaryWithObjectsAndKeys: 
										 unit,                                                                @"Player",
										 name,																  @"Name",
										 [NSString stringWithFormat: @"0x%X", [unit lowGUID]],                @"ID",
										 [NSString stringWithFormat: @"%@%@", [unit isPet] ? @"[Pet] " : @"", [Unit stringForClass: [unit unitClass]]],                             @"Class",
										 [Unit stringForRace: [unit race]],                                   @"Race",
										 [NSString stringWithFormat: @"%d%%", [unit percentHealth]],          @"Health",
										 [NSNumber numberWithUnsignedInt: level],                             @"Level",
										 [NSNumber numberWithFloat: distance],                                @"Distance", 
										 [NSNumber numberWithInt:weight],									  @"Weight",
										 nil]];
		}
		
		// Update our combat table!
		[_unitsAllCombat sortUsingDescriptors: [combatTable sortDescriptors]];
		[combatTable reloadData];
	}
	
}

#pragma mark -
#pragma mark TableView Delegate & Datasource

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
	[aTableView reloadData];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
	if ( aTableView == combatTable ){
		return [_unitsAllCombat count];
	}
	
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	if ( aTableView == combatTable ){
		if(rowIndex == -1 || rowIndex >= [_unitsAllCombat count]) return nil;
		
		if([[aTableColumn identifier] isEqualToString: @"Distance"])
			return [NSString stringWithFormat: @"%.2f", [[[_unitsAllCombat objectAtIndex: rowIndex] objectForKey: @"Distance"] floatValue]];
		
		if([[aTableColumn identifier] isEqualToString: @"Status"]) {
			NSString *status = [[_unitsAllCombat objectAtIndex: rowIndex] objectForKey: @"Status"];
			if([status isEqualToString: @"1"])  status = @"Combat";
			if([status isEqualToString: @"2"])  status = @"Hostile";
			if([status isEqualToString: @"3"])  status = @"Dead";
			if([status isEqualToString: @"4"])  status = @"Neutral";
			if([status isEqualToString: @"5"])  status = @"Friendly";
			return [NSImage imageNamed: status];
		}
		
		return [[_unitsAllCombat objectAtIndex: rowIndex] objectForKey: [aTableColumn identifier]];
	}
	
	return nil;
}

- (void)tableView: (NSTableView *)aTableView willDisplayCell: (id)aCell forTableColumn: (NSTableColumn *)aTableColumn row: (int)aRowIndex{
	
	if ( aTableView == combatTable ){
		if( aRowIndex == -1 || aRowIndex >= [_unitsAllCombat count]) return;
		
		if ([[aTableColumn identifier] isEqualToString: @"Race"]) {
			[(ImageAndTextCell*)aCell setImage: [[_unitsAllCombat objectAtIndex: aRowIndex] objectForKey: @"RaceIcon"]];
		}
		if ([[aTableColumn identifier] isEqualToString: @"Class"]) {
			[(ImageAndTextCell*)aCell setImage: [[_unitsAllCombat objectAtIndex: aRowIndex] objectForKey: @"ClassIcon"]];
		}
		
		// do text color
		if( ![aCell respondsToSelector: @selector(setTextColor:)] ){
			return;
		}
		
		Unit *unit = [[_unitsAllCombat objectAtIndex: aRowIndex] objectForKey: @"Player"];
		
		// casting unit
		if ( unit == _castingUnit ){
			[aCell setTextColor: [NSColor blueColor]];
		}
		else if ( unit == _addUnit ){
			[aCell setTextColor: [NSColor purpleColor]];
		}
		// all others
		else{
			if ( [playerData isFriendlyWithFaction:[unit factionTemplate]] || [unit GUID] == [[playerData player] GUID] ){
				[aCell setTextColor: [NSColor greenColor]];
			}
			else{
				[aCell setTextColor: [NSColor redColor]];
			}
		}
	}
	
	return;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    return NO;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectTableColumn:(NSTableColumn *)aTableColumn {
    if( [[aTableColumn identifier] isEqualToString: @"RaceIcon"])
        return NO;
    if( [[aTableColumn identifier] isEqualToString: @"ClassIcon"])
        return NO;
    return YES;
}

@end
