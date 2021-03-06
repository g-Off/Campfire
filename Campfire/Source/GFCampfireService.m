//
//  GFCampfireService.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireService.h"

#import <MKNetworkKit/MKNetworkKit.h>

#import "GCDAsyncSocket.h"

#import "GFCampfireRoom.h"
#import "GFCampfireUser.h"

@implementation GFCampfireService

@synthesize rooms=_rooms;
@synthesize activeRooms=_activeRooms;
@synthesize users=_users;
@synthesize avatars=_avatars;
@synthesize chats=_chats;
@synthesize commands=_commands;
@synthesize roomCommands=_roomCommands;

@synthesize username=_username;
@synthesize password=_password;
@synthesize server=_server;
@synthesize useSSL=_useSSL;

@synthesize me=_me;

@synthesize delegate=_delegate;

@synthesize networkEngine=_networkEngine;

- (id)init
{
	if ((self = [super init])) {
		_rooms = [[NSMutableDictionary alloc] init];
		_activeRooms = [[NSMutableDictionary alloc] init];
		_users = [[NSMutableDictionary alloc] init];
		_chats = [[NSMutableDictionary alloc] init];
		_avatars = [[NSMutableDictionary alloc] init];
		
		_commands = [[NSMutableDictionary alloc] init];
		_roomCommands = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void)login
{
	MKNetworkOperation *loginOperation = [_networkEngine operationWithPath:@"users/me.json" params:nil httpMethod:@"GET" ssl:_useSSL];
	[loginOperation setUsername:_username password:_password basicAuth:YES];
	[loginOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		GFCampfireUser *newMe = [GFJSONObject objectWithDictionary:json];
		if (_me && [_me isEqual:newMe]) {
			[_me updateWithUser:newMe];
		} else {
			_me = newMe;
		}
		[_delegate serviceDidLogin:self];
	} onError:^(NSError *error) {
		[_delegate serviceDidFailLogin:self error:error];
	}];
	[_networkEngine enqueueOperation:loginOperation forceReload:YES];
}

- (void)logout
{
	for (GCDAsyncSocket *socket in _chats.objectEnumerator) {
		[socket disconnect];
	}
	[_chats removeAllObjects];
	_me = nil;
	
	[_delegate serviceDidLogout:self];
}

- (void)joinRoom:(NSString *)roomId
{
	if (_me && _me.apiAuthToken) { 
		if ([_activeRooms objectForKey:roomId] == nil) {
			MKNetworkOperation *joinRoomOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@/join.json", roomId] params:nil httpMethod:@"POST" ssl:_useSSL];
			[joinRoomOperation setUsername:_me.apiAuthToken	password:@"X" basicAuth:YES];
			[joinRoomOperation onCompletion:^(MKNetworkOperation *completedOperation) {
				[self didJoinRoom:roomId];
			} onError:^(NSError *error) {
				if ([_activeRooms objectForKey:roomId] == nil) {
//					[serviceApplication plugInDidLeaveChatRoom:roomId error:error];
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

- (void)didJoinRoom:(NSString *)roomId
{
	GFCampfireRoom *room = [_rooms objectForKey:roomId];
	if (room) {
		[_activeRooms setObject:room forKey:room.roomKey];
		
//		[self startStreamingRoom:roomId];
//		
//		[self getRoom:roomId didJoin:YES];
//		NSString *lastMessageKey = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"Campfire-%@", roomId]];
//		[self getRecentMessagesForRoom:roomId sinceMessage:lastMessageKey];
//		
//		[serviceApplication plugInDidJoinChatRoom:roomId];
//		[serviceApplication plugInDidReceiveNotice:room.topic forChatRoom:roomId];
	}
}

@end
