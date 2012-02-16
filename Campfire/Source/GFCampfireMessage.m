//
//  GFCampfireMessage.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-05.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireMessage.h"

@implementation GFCampfireMessage

@synthesize messageId;
@synthesize roomId;
@synthesize userId;
@synthesize body;
@synthesize createdAt;
@synthesize type;
@synthesize starred;

- (void)updateWithDictionary:(NSDictionary *)dict
{
	self.messageId = [(NSNumber *)[dict objectForKey:@"id"] integerValue];
	
	id roomIdObj = [dict objectForKey:@"room_id"];
	if (roomIdObj && [roomIdObj isEqual:[NSNull null]] == NO) {
		self.roomId = [(NSNumber *)[dict objectForKey:@"room_id"] integerValue];
	}
	
	// user_id can be null for TimestampMessage types
	id userIdObj = [dict objectForKey:@"user_id"];
	if (userIdObj && [userIdObj isEqual:[NSNull null]] == NO) {
		self.userId = [(NSNumber *)[dict objectForKey:@"user_id"] integerValue];
	}
	
	id bodyObj = [dict objectForKey:@"body"];
	if (bodyObj && [bodyObj isEqual:[NSNull null]] == NO) {
		self.body = [dict objectForKey:@"body"];
	}
//	self.createdAt;
	GFCampfireMessageType messageType = GFCampfireMessageTypeUnknown;
	NSString *messageTypeString = [dict objectForKey:@"type"];
	if ([messageTypeString isEqualToString:@"TextMessage"]) {
		messageType = GFCampfireMessageTypeText;
	}
	self.type = messageType;
	self.starred = [(NSNumber *)[dict objectForKey:@"starred"] boolValue];
}

- (void)updateWithObject:(GFJSONObject *)obj
{
	if ([self isKindOfClass:[self class]]) {
		[self updateWithMessage:(GFCampfireMessage *)obj];
	}
}

- (void)updateWithMessage:(GFCampfireMessage *)message
{
	
}

@end
