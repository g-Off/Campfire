//
//  GFCampfireServicePlugIn.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireServicePlugIn.h"

@implementation GFCampfireServicePlugIn {
	id <IMServiceApplication> serviceApplication;
	NSString *username;
	NSString *password;
	NSString *server;
	
	NSURL *serverURL;
}

#pragma mark -
#pragma mark IMServicePlugIn

- (id)initWithServiceApplication:(id <IMServiceApplication>)aServiceApplication
{
	if ((self = [super init])) {
		serviceApplication = aServiceApplication;
	}
	
	return self;
}

- (oneway void)updateAccountSettings:(NSDictionary *)accountSettings
{
	server = [accountSettings objectForKey:IMAccountSettingServerHost];
	username = [accountSettings objectForKey:IMAccountSettingLoginHandle];
	password = [accountSettings objectForKey:IMAccountSettingPassword];
	
	serverURL = [NSURL URLWithString:server];
}

- (oneway void)login
{
	NSURL *url = [NSURL URLWithString:@"users/me.xml" relativeToURL:serverURL];
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
}

- (oneway void)logout
{
	
}

#pragma mark -
#pragma mark IMServicePlugInChatRoomSupport

- (oneway void)joinChatRoom:(NSString *)roomName
{
	
}

- (oneway void)leaveChatRoom:(NSString *)roomName
{
	
}

- (oneway void)inviteHandles:(NSArray *)handles toChatRoom:(NSString *)roomName withMessage:(IMServicePlugInMessage *)message
{
	
}

- (oneway void)sendMessage:(IMServicePlugInMessage *)message toChatRoom:(NSString *)roomName
{
	
}

- (oneway void)declineChatRoomInvitation:(NSString *)roomName
{
	
}

@end
