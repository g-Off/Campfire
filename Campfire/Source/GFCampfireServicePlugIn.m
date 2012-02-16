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
#import "GFCampfireMessage.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface GFCampfireServicePlugIn ()

- (void)updateInformationForRoom:(GFCampfireRoom *)room;
- (void)updateAllRoomsInformation;
- (void)updateUserRooms;

- (void)getRoom:(NSString *)roomId;

- (void)updateAllUsersInformation;
- (void)updateInformationForUserId:(NSString *)userKey;
- (void)updateInformationForUser:(GFCampfireUser *)user;

- (void)didJoinRoom:(NSString *)roomId;

- (void)getRecentMessagesForRoom:(NSString *)roomId sinceMessage:(NSString *)messageId;

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
	NSMutableDictionary *_activeRooms;
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

- (id)initWithServiceApplication:(id <IMServiceApplication, IMServiceApplicationGroupListSupport, IMServiceApplicationChatRoomSupport>)aServiceApplication
{
	if ((self = [super init])) {
		serviceApplication = aServiceApplication;
		
		_rooms = [[NSMutableDictionary alloc] init];
		_activeRooms = [[NSMutableDictionary alloc] init];
		_users = [[NSMutableDictionary alloc] init];
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
		[self updateUserRooms];
		[serviceApplication plugInDidLogIn];
	} onError:^(NSError *error) {
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

- (oneway void)joinChatRoom:(NSString *)roomId
{
	if (_me && _me.apiAuthToken) { 
		if ([_activeRooms objectForKey:roomId] == nil) {
			MKNetworkOperation *joinRoomOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@/join.json", roomId] params:nil httpMethod:@"POST" ssl:_useSSL];
			[joinRoomOperation setUsername:_me.apiAuthToken	password:@"X" basicAuth:YES];
			[joinRoomOperation onCompletion:^(MKNetworkOperation *completedOperation) {
				[self didJoinRoom:roomId];
			} onError:^(NSError *error) {
				if ([_activeRooms objectForKey:roomId] == nil) {
					[serviceApplication plugInDidLeaveChatRoom:roomId error:error];
				} else {
					[self didJoinRoom:roomId];
				}
			}];
			[_networkEngine enqueueOperation:joinRoomOperation forceReload:YES];
		} else {
			[self didJoinRoom:roomId];
		}
	}
}

- (oneway void)leaveChatRoom:(NSString *)roomName
{
	
}

- (oneway void)inviteHandles:(NSArray *)handles toChatRoom:(NSString *)roomName withMessage:(IMServicePlugInMessage *)message
{
	NSLog(@"%@", handles);
}

- (oneway void)sendMessage:(IMServicePlugInMessage *)message toChatRoom:(NSString *)roomName
{
	
}

- (oneway void)declineChatRoomInvitation:(NSString *)roomName
{
	
}

#pragma mark -
#pragma mark IMServicePlugInGroupListHandlePictureSupport

- (oneway void)requestPictureForHandle:(NSString *)handle withIdentifier:(NSString *)identifier
{
	GFCampfireUser *user = [_users objectForKey:identifier];
	if (user) {
		
	} else {
//		[serviceApplication plugInDidUpdateProperties:<#(NSDictionary *)#> ofHandle:<#(NSString *)#>];
	}
}

#pragma mark -
#pragma mark IMServicePlugInGroupListSupport

- (oneway void)requestGroupList
{
//	if (_me && _me.apiAuthToken) {
//		MKNetworkOperation *groupListOperation = [_networkEngine operationWithPath:@"rooms.json" params:nil httpMethod:@"GET" ssl:_useSSL];
//		[groupListOperation setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
//		[groupListOperation onCompletion:^(MKNetworkOperation *completedOperation) {
//			id json = [completedOperation responseJSON];
//			NSArray *allRooms = [GFJSONObject objectWithDictionary:json];
//			
//			for (GFCampfireRoom *room in allRooms) {
//				GFCampfireRoom *existingRoom = [_rooms objectForKey:room.roomKey];
//				if (existingRoom) {
//					// update existing room
//				} else {
//					[_rooms setObject:room forKey:room.roomKey];
//				}
//			}
//			
//			NSMutableDictionary *campfireGroup = [NSMutableDictionary dictionary];
//			
//			NSMutableArray *handles = [NSMutableArray array];
//			for (GFCampfireRoom *room in _rooms.objectEnumerator) {
//				NSString *handle = [[NSNumber numberWithInteger:room.roomId] stringValue];
//				[handles addObject:handle];
//			}
//			
//			[campfireGroup setObject:handles forKey:IMGroupListHandlesKey];
//			[campfireGroup setObject:IMGroupListDefaultGroup forKey:IMGroupListNameKey];
//			
//			[serviceApplication plugInDidUpdateGroupList:[NSArray arrayWithObject:campfireGroup] error:nil];
//			[self updateAllRoomsInformation];
//		} onError:^(NSError *error) {
//			[serviceApplication plugInDidUpdateGroupList:nil error:error];
//		}];
//		[_networkEngine enqueueOperation:groupListOperation forceReload:YES];
//	}
//	[self updateUserRooms];
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
			roomStatus = [NSNumber numberWithInteger:IMHandleAvailabilityOffline];
		} else if (room.full) {
			roomStatus = [NSNumber numberWithInteger:IMHandleAvailabilityAway];
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
		[usersRooms setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
		[usersRooms onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = [completedOperation responseJSON];
			NSArray *usersRooms = [GFJSONObject objectWithDictionary:json];
			
			for (GFCampfireRoom *room in usersRooms) {
				[_activeRooms setObject:room forKey:room.roomKey];
				[self updateInformationForRoom:room];
			}
		} onError:^(NSError *error) {
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
			[self updateInformationForRoom:room];
		} onError:^(NSError *error) {
//			[serviceApplication plugInDidUpdateGroupList:nil error:error];
		}];
		[_networkEngine enqueueOperation:roomOperation forceReload:YES];
	}
}
- (void)didJoinRoom:(NSString *)roomId
{
	GFCampfireRoom *room = [_rooms objectForKey:roomId];
	if (room) {
		[_activeRooms setObject:room forKey:room.roomKey];
		
		// TODO: open streaming API
		[self getRoom:roomId];
		[self getRecentMessagesForRoom:roomId sinceMessage:nil];
		
		[serviceApplication plugInDidJoinChatRoom:roomId];
	}
}

- (void)getRecentMessagesForRoom:(NSString *)roomId sinceMessage:(NSString *)messageId
{
	if (_me && _me.apiAuthToken) {
		NSMutableDictionary *params = nil;
		if (messageId) {
			params = [NSMutableDictionary dictionaryWithObject:messageId forKey:@"since_message_id"];
		}
		MKNetworkOperation *recentMessagesOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@/recent.json", roomId] params:params httpMethod:@"GET" ssl:_useSSL];
		[recentMessagesOperation setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
		[recentMessagesOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = [completedOperation responseJSON];
			NSArray *messages = [GFJSONObject objectWithDictionary:json];
			
			for (GFCampfireMessage *message in messages) {
				if (message.body && message.userId != NSNotFound) {
					NSMutableAttributedString *messageString = [[NSMutableAttributedString alloc] initWithString:message.body];
					IMServicePlugInMessage *pluginMessage = [IMServicePlugInMessage servicePlugInMessageWithContent:messageString];
					NSString *handle = [[NSNumber numberWithInteger:message.userId] stringValue];
					[serviceApplication plugInDidReceiveMessage:pluginMessage forChatRoom:roomId fromHandle:handle];
				}
			}
		} onError:^(NSError *error) {
			// couldn't fetch recents, do I care?
		}];
		[_networkEngine enqueueOperation:recentMessagesOperation forceReload:YES];
	}
}

- (void)updateInformationForRoom:(GFCampfireRoom *)room
{
	BOOL triggersUpdate = NO;
	
	NSMutableSet *joinedUsers = nil;
	NSMutableSet *departedUsers = nil;
	
	GFCampfireRoom *existingRoom = [_rooms objectForKey:room.roomKey];
	if (existingRoom) {
		if (existingRoom != room) {
			if (room.users != nil) {
				joinedUsers = [NSMutableSet setWithArray:room.users];
				[joinedUsers minusSet:[NSSet setWithArray:existingRoom.users]];
				
				departedUsers = [NSMutableSet setWithArray:existingRoom.users];
				[departedUsers minusSet:[NSSet setWithArray:room.users]];
				
			}
			
			[existingRoom updateWithRoom:room];
			triggersUpdate = YES;
		}
	} else {
		[_rooms setObject:room forKey:room.roomKey];
		triggersUpdate = YES;
	}
	
	if (triggersUpdate) {
		[serviceApplication handles:[joinedUsers allObjects] didJoinChatRoom:room.roomKey];
		[serviceApplication handles:[departedUsers allObjects] didLeaveChatRoom:room.roomKey];
		
		[self updateAllUsersInformation];
	}
}

- (void)updateAllUsersInformation
{
	for (GFCampfireUser *user in _users.objectEnumerator) {
		[self updateInformationForUser:user];
	}
}

- (void)updateInformationForUser:(GFCampfireUser *)user
{
	BOOL triggersUpdate = NO;
	GFCampfireUser *existingUser = [_users objectForKey:user.userKey];
	if (existingUser) {
		if (existingUser != user) {
			[existingUser updateWithUser:user];
			triggersUpdate = YES;
		}
	} else {
		triggersUpdate = YES;
		[_users setObject:user forKey:user.userKey];
	}
	
	if (triggersUpdate) {
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:user.name forKey:IMHandlePropertyAlias];
		[userInfo setObject:user.emailAddress forKey:IMHandlePropertyEmailAddress];
		[userInfo setObject:[NSArray arrayWithObjects:IMHandleCapabilityHandlePicture, nil] forKey:IMHandlePropertyCapabilities];
		
		// TODO: IMHandlePropertyPictureIdentifier
		
		NSInteger userStatus = IMHandleAvailabilityUnknown;
		for (GFCampfireRoom *room in _rooms.objectEnumerator) {
			if ([room.users indexOfObject:user] != NSNotFound) {
				userStatus = IMHandleAvailabilityAvailable;
				break;
			}
		}
		[userInfo setObject:[NSNumber numberWithInteger:userStatus] forKey:IMHandlePropertyAvailability];
		
		[serviceApplication plugInDidUpdateProperties:userInfo ofHandle:user.userKey];
	}
}

- (void)updateInformationForUserId:(NSString *)userKey
{
	GFCampfireUser *user = [_users objectForKey:userKey];
	if (user) {
		[self updateInformationForUser:user];
	}
}


@end
