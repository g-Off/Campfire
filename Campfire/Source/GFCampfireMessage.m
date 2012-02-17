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

/*
 <message>
 <id type="integer">1</id>
 <room-id type="integer">1</room-id>
 <user-id type="integer">2</user-id>
 <body>Hello Room</body>
 <created-at type="datetime">2009-11-22T23:46:58Z</created-at>
 <type>#{TextMessage || PasteMessage || SoundMessage || AdvertisementMessage ||
 AllowGuestsMessage || DisallowGuestsMessage || IdleMessage || KickMessage ||
 LeaveMessage || SystemMessage || TimestampMessage || TopicChangeMessage ||
 UnidleMessage || UnlockMessage || UploadMessage || EnterMessage}</type>
 <starred>true</starred>
 </message>
 */

- (void)updateWithDictionary:(NSDictionary *)dict
{
	self.messageId = [(NSNumber *)[dict objectForKey:@"id"] integerValue];
	
	id roomIdObj = [dict objectForKey:@"room_id"];
	if (roomIdObj && [roomIdObj isEqual:[NSNull null]] == NO) {
		self.roomId = [(NSNumber *)[dict objectForKey:@"room_id"] integerValue];
	} else {
		self.roomId = NSNotFound;
	}
	
	// user_id can be null for TimestampMessage types
	id userIdObj = [dict objectForKey:@"user_id"];
	if (userIdObj && [userIdObj isEqual:[NSNull null]] == NO) {
		self.userId = [(NSNumber *)[dict objectForKey:@"user_id"] integerValue];
	} else {
		self.userId = NSNotFound;
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
	} else if ([messageTypeString isEqualToString:@"PasteMessage"]) {
		messageType = GFCampfireMessageTypePaste;
	} else if ([messageTypeString isEqualToString:@"SoundMessage"]) {
		messageType = GFCampfireMessageTypeSound;
	} else if ([messageTypeString isEqualToString:@"AdvertisementMessage"]) {
		messageType = GFCampfireMessageTypeAdvertisement;
	} else if ([messageTypeString isEqualToString:@"AllowGuestsMessage"]) {
		messageType = GFCampfireMessageTypeAllowGuests;
	} else if ([messageTypeString isEqualToString:@"DisallowGuestsMessage"]) {
		messageType = GFCampfireMessageTypeDisallowGuests;
	} else if ([messageTypeString isEqualToString:@"IdleMessage"]) {
		messageType = GFCampfireMessageTypeIdle;
	} else if ([messageTypeString isEqualToString:@"KickMessage"]) {
		messageType = GFCampfireMessageTypeKick;
	} else if ([messageTypeString isEqualToString:@"LeaveMessage"]) {
		messageType = GFCampfireMessageTypeLeave;
	} else if ([messageTypeString isEqualToString:@"SystemMessage"]) {
		messageType = GFCampfireMessageTypeSystem;
	} else if ([messageTypeString isEqualToString:@"TimestampMessage"]) {
		messageType = GFCampfireMessageTypeTimestamp;
	} else if ([messageTypeString isEqualToString:@"TopicChangeMessage"]) {
		messageType = GFCampfireMessageTypeTopicChange;
	} else if ([messageTypeString isEqualToString:@"UnidleMessage"]) {
		messageType = GFCampfireMessageTypeUnidle;
	} else if ([messageTypeString isEqualToString:@"UnlockMessage"]) {
		messageType = GFCampfireMessageTypeUnlock;
	} else if ([messageTypeString isEqualToString:@"UploadMessage"]) {
		messageType = GFCampfireMessageTypeUpload;
	} else if ([messageTypeString isEqualToString:@"EnterMessage"]) {
		messageType = GFCampfireMessageTypeEnter;
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

- (NSString *)messageKey
{
	return [[NSNumber numberWithInteger:self.messageId] stringValue];
}

- (id)JSONRepresentation
{
	NSMutableDictionary *JSONRepresentation = [NSMutableDictionary dictionary];
	return nil;
}

@end
