//
//  GFCampfireRoom.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireRoom.h"

@implementation GFCampfireRoom

@synthesize roomId;
@synthesize name;
@synthesize topic;
@synthesize membershipLimit;
@synthesize full;
@synthesize openToGuests;
@synthesize activeTokenValue;
@synthesize updatedAt;
@synthesize createdAt;
@synthesize users;
@synthesize locked;

/*
 {
	 "rooms": [
		 {
			 "created_at": "2007/07/03 15:42:43 +0000",
			 "id": 100257,
			 "locked": 0,
			 "membership_limit": 50,
			 "name": "Open Bar 1.1",
			 "topic": "New office! woop woop",
			 "updated_at": "2012/01/02 14:23:25 +0000",
		 },
	 ],
 }
 */

- (void)updateWithDictionary:(NSDictionary *)dict
{
	self.roomId = [(NSNumber *)[dict objectForKey:@"id"] integerValue];
	self.name = [dict objectForKey:@"name"];
	self.topic = [dict objectForKey:@"topic"];
	self.membershipLimit = [(NSNumber *)[dict objectForKey:@"membership_limit"] integerValue];
//	self.full;
	self.openToGuests = [(NSNumber *)[dict objectForKey:@"open_to_guests"] boolValue];
//	self.activeTokenValue;
//	self.updatedAt;
//	self.createdAt;
	NSArray *usersArray = [dict objectForKey:@"users"];
	if (usersArray) {
		NSDictionary *usersDict = [NSDictionary dictionaryWithObject:usersArray forKey:@"users"];
		self.users = [GFJSONObject objectWithDictionary:usersDict];
	}
	self.locked = [(NSNumber *)[dict objectForKey:@"locked"] boolValue];
}

- (void)updateWithObject:(GFJSONObject *)obj
{
	if ([self isKindOfClass:[self class]]) {
		[self updateWithRoom:(GFCampfireRoom *)obj];
	}
}

- (void)updateWithRoom:(GFCampfireRoom *)room
{
	if (self.roomId != room.roomId) {
		return;
	}
	
	if (self == room) {
		return;
	}
	
	self.name = room.name;
	self.topic = room.topic;
	self.membershipLimit = room.membershipLimit;
	self.full = room.full;
	self.openToGuests = room.openToGuests;
	self.activeTokenValue = room.activeTokenValue;
	self.updatedAt = room.updatedAt;
	self.createdAt = room.createdAt;
	self.users = room.users;
	self.locked = room.locked;
}

- (NSString *)roomKey
{
	return [[NSNumber numberWithInteger:self.roomId] stringValue];
}

@end
