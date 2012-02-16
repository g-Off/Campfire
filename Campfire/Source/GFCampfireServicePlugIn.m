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

#import "GFJSONObject.h"
#import "GFCampfireUser.h"
#import "GFCampfireRoom.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation GFCampfireServicePlugIn {
	id <IMServiceApplication, IMServiceApplicationGroupListSupport> serviceApplication;
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
		[GFJSONObject registerClassPrefix:@"GFCampfire"];
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
		me = [GFJSONObject objectWithDictionary:json];
		[serviceApplication plugInDidLogIn];
	} onError:^(NSError *error) {
		NSLog(@"%@", error);
		[serviceApplication plugInDidFailToAuthenticate];
	}];
	[networkEngine enqueueOperation:loginOperation forceReload:YES];
}

- (oneway void)logout
{
	[serviceApplication plugInDidLogOutWithError:nil reconnect:NO];
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

#pragma mark -
#pragma mark IMServicePlugInGroupListSupport

- (oneway void)requestGroupList
{
	MKNetworkOperation *loginOperation = [networkEngine operationWithPath:@"rooms.json" params:nil httpMethod:@"GET" ssl:useSSL];
	[loginOperation setUsername:me.apiAuthToken	password:@"X" basicAuth:YES];
	[loginOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		NSLog(@"%@", json);
		NSArray *rooms = [GFJSONObject objectWithDictionary:json];
		NSMutableArray *groupList = [NSMutableArray array];
		for (GFCampfireRoom *room in rooms) {
			NSMutableDictionary *roomDict = [NSMutableDictionary dictionary];
			[roomDict setObject:room.name forKey:IMGroupListNameKey];
			[groupList addObject:roomDict];
		}
		NSLog(@"%@", rooms);
		[serviceApplication plugInDidUpdateGroupList:groupList error:nil];
	} onError:^(NSError *error) {
		NSLog(@"%@", error);
		[serviceApplication plugInDidUpdateGroupList:nil error:error];
	}];
	[networkEngine enqueueOperation:loginOperation forceReload:YES];
}

#pragma mark -
#pragma mark IMServicePlugInPresenceSupport

- (oneway void)updateSessionProperties:(NSDictionary *)properties
{
	/*
	 Available keys include:
	 IMSessionPropertyAvailability   - the user's availablility
	 IMSessionPropertyStatusMessage  - the user's status message
	 IMSessionPropertyPictureData    - the user's icon
	 IMSessionPropertyIdleDate       - the time of the last user activity
	 IMSessionPropertyIsInvisible    - If YES, the user wishes to appear offline to other users
	 */
}


@end
