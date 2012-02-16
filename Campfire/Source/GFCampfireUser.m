//
//  GFCampfireUser.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireUser.h"

@implementation GFCampfireUser

@synthesize name;
@synthesize emailAddress;
@synthesize admin;
@synthesize createdAt;
@synthesize type;
@synthesize avatar;
@synthesize userId;
@synthesize apiAuthToken;

/*
 <user>
	 <id type="integer">1</id>
	 <name>Jason Fried</name>
	 <email-address>jason@37signals.com</email-address>
	 <admin type="boolean">true</admin>
	 <created-at type="datetime">2009-11-20T16:41:39Z</created-at>
	 <type>Member</type>
	 <avatar-url>https://asset0.37img.com/global/.../avatar.png</avatar-url>
 </user>
 
 {
	 "user": {
		 "admin": 0,
		 "api_auth_token": "0d3afe0bc167d367e91ea0fd44b488e3ce3089ce",
		 "avatar_url": "http://asset0.37img.com/global/843d8a119b3d4bca9e69efc399f970bc9def4686/avatar.gif?r=3",
		 "created_at": "2012/01/31 17:48:53 +0000",
		 "email_address": "geoffrey.foster@gmail.com",
		 "id": 1115252,
		 "name": "Geoff Foster",
		 "type": "Member",
	 },
 }
 */

- (void)updateWithDictionary:(NSDictionary *)dict
{
	self.name = [dict objectForKey:@"name"];
	self.emailAddress = [dict objectForKey:@"email_address"];
	self.admin = [(NSNumber *)[dict objectForKey:@"admin"] boolValue];
//	self.createdAt = 
//	self.type
	self.avatar = [NSURL URLWithString:[dict objectForKey:@"avatar_url"]];
	self.userId = [(NSNumber *)[dict objectForKey:@"id"] integerValue];
	self.apiAuthToken = [dict objectForKey:@"api_auth_token"];
}

- (void)updateWithObject:(GFCampfireUser *)obj
{
	if ([self isKindOfClass:[self class]]) {
		[self updateWithUser:(GFCampfireUser *)obj];
	}
}

- (void)updateWithUser:(GFCampfireUser *)user
{
	if (self.userId != user.userId) {
		return;
	}
	self.name = user.name;
	self.emailAddress = user.emailAddress;
	self.admin = user.admin;
	self.createdAt = user.createdAt;
	self.type = user.type;
	self.avatar = user.avatar;
	
	self.apiAuthToken = user.apiAuthToken;
}

@end
