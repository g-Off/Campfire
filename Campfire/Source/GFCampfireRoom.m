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
	self.openToGuests = ![(NSNumber *)[dict objectForKey:@"locked"] boolValue];
//	self.activeTokenValue;
//	self.updatedAt;
//	self.createdAt;
//	self.users;
}

@end
