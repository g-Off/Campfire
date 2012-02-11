//
//  GFCampfireServicePlugIn.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireServicePlugIn.h"
#import "DDLog.h"
#import "DDASLLogger.h"

#import <MKNetworkKit/MKNetworkKit.h>

#import "GFCampfireUser.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation GFCampfireServicePlugIn {
	id <IMServiceApplication> serviceApplication;
	NSString *username;
	NSString *password;
	NSString *server;
	BOOL useSSL;
	
	NSURL *serverURL;
	
	MKNetworkEngine *networkEngine;
	
	GFCampfireUser *me;
}

+ (void)initialize
{
	if (self == [GFCampfireServicePlugIn class]) {
		[DDLog addLogger:[DDASLLogger sharedInstance]];
	}
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
	useSSL = [[accountSettings objectForKey:IMAccountSettingUsesSSL] boolValue];
	
//	if (useSSL) {
//		if ([server hasPrefix:@"https://"] == NO) {
//			server = [NSString stringWithFormat:@"https://%@", server];
//		}
//	} else {
//		if ([server hasPrefix:@"http://"] == NO) {
//			server = [NSString stringWithFormat:@"http://%@", server];
//		}
//	}
	
	DDLogInfo(@"%@", accountSettings);
	
	networkEngine = [[MKNetworkEngine alloc] initWithHostName:server customHeaderFields:nil];
}

- (oneway void)login
{
	MKNetworkOperation *loginOperation = [networkEngine operationWithPath:@"users/me.json" params:nil httpMethod:@"GET" ssl:useSSL];
	[loginOperation setUsername:username password:password basicAuth:YES];
	[loginOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		NSLog(@"%@", json);
	} onError:^(NSError *error) {
		NSLog(@"%@", error);
	}];
//	[loginOperation setAuthHandler:(MKNKAuthBlock)authHandler];
	[networkEngine enqueueOperation:loginOperation forceReload:YES];
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
