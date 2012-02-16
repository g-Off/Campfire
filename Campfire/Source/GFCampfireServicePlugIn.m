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

@interface GFCampfireServicePlugIn ()

- (void)updateAllRoomsInformation;

@end

@implementation GFCampfireServicePlugIn {
	id <IMServiceApplication, IMServiceApplicationGroupListSupport, IMServiceApplicationChatRoomSupport> serviceApplication;
	NSString *_username;
	NSString *_password;
	NSString *_server;
	BOOL _useSSL;
	
	MKNetworkEngine *_networkEngine;
	
	GFCampfireUser *_me;
	
	NSMutableDictionary *_rooms;
	NSMutableDictionary *_users;
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
		
		_rooms = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (oneway void)updateAccountSettings:(NSDictionary *)accountSettings
{
	_server = [accountSettings objectForKey:IMAccountSettingServerHost];
	_username = [accountSettings objectForKey:IMAccountSettingLoginHandle];
	_password = [accountSettings objectForKey:IMAccountSettingPassword];
	_useSSL = [[accountSettings objectForKey:IMAccountSettingUsesSSL] boolValue];
	
	_networkEngine = [[MKNetworkEngine alloc] initWithHostName:_server customHeaderFields:nil];
}

- (oneway void)login
{
	MKNetworkOperation *loginOperation = [_networkEngine operationWithPath:@"users/me.json" params:nil httpMethod:@"GET" ssl:_useSSL];
	[loginOperation setUsername:_username password:_password basicAuth:YES];
	[loginOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		_me = [GFJSONObject objectWithDictionary:json];
		[serviceApplication plugInDidLogIn];
	} onError:^(NSError *error) {
		NSLog(@"%@", error);
		[serviceApplication plugInDidFailToAuthenticate];
	}];
	[_networkEngine enqueueOperation:loginOperation forceReload:YES];
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
	if (_me && _me.apiAuthToken) {
		MKNetworkOperation *groupListOperation = [_networkEngine operationWithPath:@"rooms.json" params:nil httpMethod:@"GET" ssl:_useSSL];
		[groupListOperation setUsername:_me.apiAuthToken	password:@"X" basicAuth:YES];
		[groupListOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = [completedOperation responseJSON];
			NSArray *allRooms = [GFJSONObject objectWithDictionary:json];
			
			for (GFCampfireRoom *room in allRooms) {
				NSString *roomKey = [[NSNumber numberWithInteger:room.roomId] stringValue];
				GFCampfireRoom *existingRoom = [_rooms objectForKey:roomKey];
				if (existingRoom) {
					// update existing room
				} else {
					[_rooms setObject:room forKey:roomKey];
				}
			}
			
			NSMutableDictionary *campfireGroup = [NSMutableDictionary dictionary];
			
			NSMutableArray *handles = [NSMutableArray array];
			for (GFCampfireRoom *room in _rooms.objectEnumerator) {
				NSString *handle = [[NSNumber numberWithInteger:room.roomId] stringValue];
				[handles addObject:handle];
			}
			
			[campfireGroup setObject:handles forKey:IMGroupListHandlesKey];
			[campfireGroup setObject:IMGroupListDefaultGroup forKey:IMGroupListNameKey];
			
			[serviceApplication plugInDidUpdateGroupList:[NSArray arrayWithObject:campfireGroup] error:nil];
			[self updateAllRoomsInformation];
		} onError:^(NSError *error) {
			[serviceApplication plugInDidUpdateGroupList:nil error:error];
		}];
		[_networkEngine enqueueOperation:groupListOperation forceReload:YES];
	}
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

#pragma mark -
#pragma mark Helper Methods

- (void)updateAllRoomsInformation
{
	[_rooms enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		NSString *handle = key;
		GFCampfireRoom *room = obj;
		NSMutableDictionary *properties = [NSMutableDictionary dictionary];
		NSNumber *roomStatus = [NSNumber numberWithInteger:IMHandleAvailabilityAvailable];
		if (room.locked) {
			
		} else if (room.full) {
			
		}
		
		[properties setObject:roomStatus forKey:IMHandlePropertyAvailability];
		[properties setObject:room.topic forKey:IMHandlePropertyStatusMessage];
		[properties setObject:room.name forKey:IMHandlePropertyAlias];
		if (room.full == NO && room.locked == NO) {
			[properties setObject:IMHandleCapabilityChatRoom forKey:IMHandlePropertyCapabilities];
		}
		
		/*
		 IMHandlePropertyAvailability      - The IMHandleAvailability of the handle
		 IMHandlePropertyStatusMessage     - Current status message as plaintext NSString
		 IMHandlePropertyIdleDate          - The time of the last user activity
		 IMHandlePropertyAlias             - A "prettier" version of the handle, if available
		 IMHandlePropertyFirstName         - The first name (given name) of a handle
		 IMHandlePropertyLastName          - The last name (family name) of a handle
		 IMHandlePropertyEmailAddress      - The e-mail address for a handle
		 IMHandlePropertyPictureIdentifier - A unique identifier for the handle's picture
		 IMHandlePropertyCapabilities      - The capabilities of the handle
		 */
		
		[serviceApplication plugInDidUpdateProperties:properties ofHandle:handle];
	}];
}

- (void)updateUserRooms
{
	if (_me && _me.apiAuthToken) {
		MKNetworkOperation *usersRooms = [_networkEngine operationWithPath:@"presence.json" params:nil httpMethod:@"GET" ssl:_useSSL];
		[usersRooms setUsername:_me.apiAuthToken	password:@"X" basicAuth:YES];
		[usersRooms onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = [completedOperation responseJSON];
			NSArray *usersRooms = [GFJSONObject objectWithDictionary:json];
			
			for (GFCampfireRoom *room in usersRooms) {
				// should be joining the chat rooms here
			}
		} onError:^(NSError *error) {
//			[serviceApplication plugInDidUpdateGroupList:nil error:error];
		}];
		[_networkEngine enqueueOperation:usersRooms forceReload:YES];
	}
}

- (void)getRoom:(NSString *)roomId
{
	if (_me && _me.apiAuthToken) {
		MKNetworkOperation *roomOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@.json", roomId] params:nil httpMethod:@"GET" ssl:_useSSL];
		[roomOperation setUsername:_me.apiAuthToken	password:@"X" basicAuth:YES];
		[roomOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = [completedOperation responseJSON];
			GFCampfireRoom *room = [GFJSONObject objectWithDictionary:json];
			
//			[serviceApplication handles:<#(NSArray *)#> didJoinChatRoom:<#(NSString *)#>];
//			[serviceApplication handles:<#(NSArray *)#> didLeaveChatRoom:<#(NSString *)#>];
		} onError:^(NSError *error) {
//			[serviceApplication plugInDidUpdateGroupList:nil error:error];
		}];
		[_networkEngine enqueueOperation:roomOperation forceReload:YES];
	}
}


@end
