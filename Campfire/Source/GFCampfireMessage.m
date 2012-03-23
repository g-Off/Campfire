//
//  GFCampfireMessage.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-05.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireMessage.h"
#import "GFCampfireTweet.h"

@implementation GFCampfireMessage

@synthesize messageId;
@synthesize roomId;
@synthesize userId;
@synthesize body;
@synthesize createdAt;
@synthesize type;
@synthesize starred;
@synthesize tweet;

/*
 {
	 "body": <null>,
	 "created_at": "2012/02/26 22:02:10 +0000",
	 "id": 509928543,
	 "room_id": 474752,
	 "starred": "false",
	 "type": "EnterMessage",
	 "user_id": 509886,
 }
 */

+ (NSDictionary *)jsonMapping
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"id", @"messageId",
			@"room_id", @"roomId",
//			@"user_id", @"userId",
			@"body", @"body",
			@"created_at", @"createdAt",
			@"type", @"type",
			@"starred", @"starred",
			@"tweet", @"tweet",
			nil];
}

+ (NSDictionary *)valueTransformers
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"GFCampfireMessageTypeValueTransformer", @"type",
			@"GFCampfireBOOLValueTransformer", @"starred",
			@"GFCampfireDateValueTransformer", @"createdAt",
			nil];
}

+ (NSDictionary *)jsonProperties
{
	return [NSDictionary dictionaryWithObject:[GFCampfireTweet class] forKey:@"tweet"];
}

- (void)updateWithDictionary:(NSDictionary *)dict
{
	[super updateWithDictionary:dict];
	
	// user_id can be null for TimestampMessage types
	id userIdObj = [dict objectForKey:@"user_id"];
	if (userIdObj && [userIdObj isEqual:[NSNull null]] == NO) {
		self.userId = [(NSNumber *)[dict objectForKey:@"user_id"] integerValue];
	} else {
		self.userId = NSNotFound;
	}
	
//	self.createdAt;
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
	return [JSONRepresentation copy];
}

@end

@implementation GFCampfireMessageTypeValueTransformer

+ (NSArray *)messageTypes
{
	static NSArray *messageTypes = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		messageTypes = [[NSArray alloc] initWithObjects:
						@"TextMessage",
						@"PasteMessage",
						@"SoundMessage",
						@"AdvertisementMessage",
						@"AllowGuestsMessage",
						@"DisallowGuestsMessage",
						@"IdleMessage",
						@"KickMessage",
						@"LeaveMessage",
						@"SystemMessage",
						@"TimestampMessage",
						@"TopicChangeMessage",
						@"UnidleMessage",
						@"UnlockMessage",
						@"UploadMessage",
						@"EnterMessage",
						nil];
	});
	return messageTypes;
}

+ (Class)transformedValueClass
{
	return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue:(id)value
{
	GFCampfireMessageType messageType = GFCampfireMessageTypeUnknown;
	if ([value isKindOfClass:[NSString class]]) {
		NSString *messageTypeString = value;
		NSArray *messageTypes = [[self class] messageTypes];
		NSUInteger messageTypeIndex = [messageTypes indexOfObject:messageTypeString];
		if (messageTypeIndex != NSNotFound) {
			messageType = messageTypeIndex;
		}
	}
	
	return [NSNumber numberWithInteger:messageType];
}

- (id)reverseTransformedValue:(id)value
{
	NSString *transformedValue = nil;
	if ([value isKindOfClass:[NSNumber class]]) {
		NSInteger messageType = [(NSNumber *)value integerValue];
		NSArray *messageTypes = [[self class] messageTypes];
		if (messageType >= 0 && messageType < [messageTypes count]) {
			transformedValue = [messageTypes objectAtIndex:messageType];
		}
	}
	
	return transformedValue;
}

@end
