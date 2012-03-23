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
@synthesize avatarURL;
@synthesize userId;
@synthesize apiAuthToken;

+ (NSDictionary *)jsonMapping
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"name", @"name",
			@"email_address", @"emailAddress",
			@"admin", @"admin",
			@"avatar_url", @"avatarURL",
			@"id", @"userId",
			@"api_auth_token", @"apiAuthToken",
			@"type", @"type",
			@"created_at", @"createdAt",
			nil];
}

+ (NSDictionary *)valueTransformers
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"GFJSONURLValueTransformer", @"avatarURL",
			@"GFCampfireUserTypeValueTransformer", @"type",
			@"GFCampfireDateValueTransformer", @"createdAt",
			nil];
}

/*
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
	
	if (self == user) {
		return;
	}
	
	self.name = user.name;
	self.emailAddress = user.emailAddress;
	self.admin = user.admin;
	self.createdAt = user.createdAt;
	self.type = user.type;
	
	if (user.avatarURL) {
		self.avatarURL = user.avatarURL;
	}
	
	if (user.apiAuthToken) {
		self.apiAuthToken = user.apiAuthToken;
	}
}

- (NSString *)userKey
{
	return [[NSNumber numberWithInteger:self.userId] stringValue];
}

- (NSString *)avatarKey
{
	return [NSString stringWithFormat:@"%@%ld",self.userKey, [self.avatarURL hash]];
}

- (NSUInteger)hash
{
	return self.userId;
}

- (BOOL)isEqual:(id)object
{
	return [object isKindOfClass:[self class]] && self.userId == ((GFCampfireUser *)object).userId;
}

@end

@implementation GFCampfireUserTypeValueTransformer

+ (NSArray *)userTypes
{
	static NSArray *userTypes = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		userTypes = [[NSArray alloc] initWithObjects:
						@"Member",
						@"Guest",
						nil];
	});
	return userTypes;
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
	GFCampfireUserType userType = GFCampfireUserTypeGuest;
	if ([value isKindOfClass:[NSString class]]) {
		NSString *userTypeString = value;
		NSArray *userTypes = [[self class] userTypes];
		NSUInteger userTypeIndex = [userTypes indexOfObject:userTypeString];
		if (userTypeIndex != NSNotFound) {
			userType = userTypeIndex;
		}
	}
	
	return [NSNumber numberWithInteger:userType];
}

- (id)reverseTransformedValue:(id)value
{
	NSString *transformedValue = nil;
	if ([value isKindOfClass:[NSNumber class]]) {
		NSInteger userType = [(NSNumber *)value integerValue];
		NSArray *userTypes = [[self class] userTypes];
		if (userType >= 0 && userType < [userTypes count]) {
			transformedValue = [userTypes objectAtIndex:userType];
		}
	}
	
	return transformedValue;
}

@end
