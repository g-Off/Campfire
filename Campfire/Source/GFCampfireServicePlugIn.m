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
#import "DDTTYLogger.h"
#import "DDFileLogger.h"

#import <MKNetworkKit/MKNetworkKit.h>

#import "GFJSONObject.h"
#import "GFCampfireUser.h"
#import "GFCampfireRoom.h"
#import "GFCampfireMessage.h"

#import "GFCampfireOperation.h"

#import "GCDAsyncSocket.h"
#import "GFCampfireCommand.h"
#import "NSString+GFJSONObject.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;
static NSString *kGFCampfireErrorDomain = @"GFCampfireErrorDomain";

enum {
	GFCampfireErrorConsoleInvalidCommand,
	GFCampfireErrorMessagingUsersNotSupported,
};

static inline void GFCampfireAddCommand(NSMutableDictionary *dict, NSString *command, NSString *help, SEL sel)
{
	[dict setObject:[GFCampfireCommand commandWithName:command helpString:help selector:sel] forKey:command];
}

static inline void GFCampfireAddBlockCommand(NSMutableDictionary *dict, NSString *command, NSString *help, void (^block)(NSString *args))
{
	[dict setObject:[GFCampfireCommand commandWithName:command helpString:help action:block] forKey:command];
}

@interface GFCampfireServicePlugIn () <GCDAsyncSocketDelegate>

- (void)updateInformationForRoom:(GFCampfireRoom *)room didJoin:(BOOL)didJoin;
- (void)getUserRooms;
- (void)getAllRooms;

- (void)getRoom:(NSString *)roomId didJoin:(BOOL)didJoin;

- (void)updateAllUsersInformation;
- (void)updateInformationForUserId:(NSString *)userKey;
- (void)updateInformationForUser:(GFCampfireUser *)user;

- (void)didJoinRoom:(NSString *)roomId;

- (void)getRecentMessagesForRoom:(NSString *)roomId sinceMessage:(NSString *)messageId;

- (void)getRemoteUserInfo:(NSString *)userId;

- (void)processHistoryMessages:(NSArray *)messages;
- (void)processHistoryMessage:(GFCampfireMessage *)message;
- (void)processStreamMessage:(GFCampfireMessage *)message;
- (void)processMessage:(GFCampfireMessage *)message historyMessage:(BOOL)isHistoryMessage streamMessage:(BOOL)isStreamMessage;

- (void)startStreamingRoom:(NSString *)roomId;
- (void)stopStreamingRoom:(NSString *)roomId;

- (NSString *)roomIdForSocket:(GCDAsyncSocket *)socket;

@property (assign, getter = isReachable) BOOL reachable;

@end

@implementation GFCampfireServicePlugIn {
	id <IMServiceApplication, IMServiceApplicationGroupListSupport, IMServiceApplicationChatRoomSupport, IMServiceApplicationInstantMessagingSupport> serviceApplication;
	NSString *_username;
	NSString *_password;
	NSString *_server;
	BOOL _useSSL;
	
	MKNetworkEngine *_networkEngine;
	
	GFCampfireUser *_me;
	
	NSMutableDictionary *_rooms;
	NSMutableDictionary *_activeRooms;
	NSMutableDictionary *_users;
	
	NSMutableDictionary *_chats;
	
	NSMutableDictionary *_commands;
}

@synthesize reachable=_reachable;

+ (void)initialize
{
	if (self == [GFCampfireServicePlugIn class]) {
//		[DDLog addLogger:[DDASLLogger sharedInstance]];
//		[DDLog addLogger:[DDTTYLogger sharedInstance]];
		NSString *appName = [[NSBundle bundleForClass:self] bundleIdentifier];//[[NSProcessInfo processInfo] processName];
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
		NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
		NSString *logsDirectory = [[basePath stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:appName];
		DDLogFileManagerDefault *fileManager = [[DDLogFileManagerDefault alloc] initWithLogsDirectory:logsDirectory];
		[DDLog addLogger:[[DDFileLogger alloc] initWithLogFileManager:fileManager]];
		[GFJSONObject registerClassPrefix:@"GFCampfire"];
	}
}

#pragma mark -
#pragma mark Command Actions

- (void)setRoom:(NSString *)roomId topic:(NSString *)topic
{
	NSDictionary *params = [NSDictionary dictionaryWithObject:topic forKey:@"topic"];
	[self updateRoom:roomId attributes:params];
}

- (void)setRoom:(NSString *)roomId name:(NSString *)name
{
	NSDictionary *params = [NSDictionary dictionaryWithObject:name forKey:@"name"];
	[self updateRoom:roomId attributes:params];
}

- (void)updateRoom:(NSString *)roomId attributes:(NSDictionary *)attributes
{
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:attributes];
	MKNetworkOperation *changeTopicOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@.json", roomId] params:params httpMethod:@"PUT" ssl:YES];
	[changeTopicOperation setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
	[changeTopicOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		GFCampfireRoom *room = [_rooms objectForKey:roomId];
		NSString *topic = [params objectForKey:@"topic"];
		NSString *name = [params objectForKey:@"name"];
		if (topic) {
			room.topic = topic;
			[serviceApplication plugInDidReceiveNotice:topic forChatRoom:roomId];
		}
		if (name) {
			room.name = name;
		}
	} onError:^(NSError *error) {
		
	}];
}

- (void)lockRoom:(NSString *)roomId
{
	GFCampfireRoom *room = [_rooms objectForKey:roomId];
	if (room && room.locked == NO) {
		MKNetworkOperation *lockOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@/lock.json", roomId]
																	   params:nil
																   httpMethod:@"POST"
																		  ssl:YES];
		[lockOperation setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
		[lockOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			room.locked = YES;
		} onError:^(NSError *error) {
			
		}];
	}
}

- (void)unlockRoom:(NSString *)roomId
{
	GFCampfireRoom *room = [_rooms objectForKey:roomId];
	if (room && room.locked == YES) {
		MKNetworkOperation *unlockOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@/unlock.json", roomId]
																		 params:nil
																	 httpMethod:@"POST"
																			ssl:YES];
		[unlockOperation setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
		[unlockOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			room.locked = NO;
		} onError:^(NSError *error) {
			
		}];
	}
}

#pragma mark -
#pragma mark IMServicePlugIn

- (IMServicePlugInMessage *)roomList
{
	NSMutableAttributedString *roomListString = [[NSMutableAttributedString alloc] init];
	for (GFCampfireRoom *room in _rooms.objectEnumerator) {
		NSString *roomString = [NSString stringWithFormat:@"%d | %@\n", room.roomId, room.name];
		NSAttributedString *attributedRoomString = [[NSAttributedString alloc] initWithString:roomString];
		[roomListString appendAttributedString:attributedRoomString];
	}
	
	IMServicePlugInMessage *message = [IMServicePlugInMessage servicePlugInMessageWithContent:roomListString];
	
	return message;
}

- (IMServicePlugInMessage *)infoMessage
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSURL *path = [bundle URLForResource:@"PluginInfo" withExtension:@"rtf"];
	NSAttributedString *info = [[NSAttributedString alloc] initWithURL:path documentAttributes:nil];
	return [IMServicePlugInMessage servicePlugInMessageWithContent:info];
}

- (id)initWithServiceApplication:(id <IMServiceApplication, IMServiceApplicationGroupListSupport, IMServiceApplicationChatRoomSupport, IMServiceApplicationInstantMessagingSupport>)aServiceApplication
{
	if ((self = [super init])) {
		serviceApplication = aServiceApplication;
		
		_rooms = [[NSMutableDictionary alloc] init];
		_activeRooms = [[NSMutableDictionary alloc] init];
		_users = [[NSMutableDictionary alloc] init];
		_chats = [[NSMutableDictionary alloc] init];
		
		_commands = [[NSMutableDictionary alloc] init];
		
		GFCampfireAddBlockCommand(_commands, @"ping", @"Pings the console", ^(NSString *args) {
			NSString *pongString = @"pong!";
			NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:pongString
																				   attributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
																														  forKey:IMAttributeItalic]];
			IMServicePlugInMessage *message = [IMServicePlugInMessage servicePlugInMessageWithContent:attributedString];
			if ([_rooms objectForKey:args]) {
				[serviceApplication plugInDidReceiveMessage:message forChatRoom:args fromHandle:@"console"];
			} else {
				[serviceApplication plugInDidReceiveMessage:message fromHandle:@"console"];	
			}
		});
		
		GFCampfireAddBlockCommand(_commands, @"list", @"List the available rooms", ^(NSString *args) {
			IMServicePlugInMessage *message = [self roomList];
			[serviceApplication plugInDidReceiveMessage:message fromHandle:@"console"];
		});
		
		GFCampfireAddBlockCommand(_commands, @"join", @"Joins the specified room(s)", ^(NSString *args) {
			NSMutableCharacterSet *separators = [NSMutableCharacterSet whitespaceCharacterSet];
			[separators addCharactersInString:@","];
			NSArray *roomIds = [args componentsSeparatedByCharactersInSet:separators];
			for (NSString *roomId in roomIds) {
				NSString *trimmedRoomId = [roomId stringByTrimmingCharactersInSet:separators];
				if ([trimmedRoomId length] > 0) {
					[self joinChatRoom:trimmedRoomId];
				}
			}
		});
		
		GFCampfireAddBlockCommand(_commands, @"leave", @"Leaves the specified room(s)", ^(NSString *args) {
			NSMutableCharacterSet *separators = [NSMutableCharacterSet whitespaceCharacterSet];
			[separators addCharactersInString:@","];
			NSArray *roomIds = [args componentsSeparatedByCharactersInSet:separators];
			for (NSString *roomId in roomIds) {
				NSString *trimmedRoomId = [roomId stringByTrimmingCharactersInSet:separators];
				if ([trimmedRoomId length] > 0) {
					[self leaveRoom:trimmedRoomId];
				}
			}
		});
		
		GFCampfireAddBlockCommand(_commands, @"lock", @"Locks the specified room(s)", ^(NSString *args) {
			NSMutableCharacterSet *separators = [NSMutableCharacterSet whitespaceCharacterSet];
			[separators addCharactersInString:@","];
			NSArray *roomIds = [args componentsSeparatedByCharactersInSet:separators];
			for (NSString *roomId in roomIds) {
				NSString *trimmedRoomId = [roomId stringByTrimmingCharactersInSet:separators];
				if ([trimmedRoomId length] > 0) {
					[self lockRoom:trimmedRoomId];
				}
			}
		});
		
		GFCampfireAddBlockCommand(_commands, @"unlock", @"Unlocks the specified room(s)", ^(NSString *args) {
			NSMutableCharacterSet *separators = [NSMutableCharacterSet whitespaceCharacterSet];
			[separators addCharactersInString:@","];
			NSArray *roomIds = [args componentsSeparatedByCharactersInSet:separators];
			for (NSString *roomId in roomIds) {
				NSString *trimmedRoomId = [roomId stringByTrimmingCharactersInSet:separators];
				if ([trimmedRoomId length] > 0) {
					[self unlockRoom:trimmedRoomId];
				}
			}
		});
		
		GFCampfireAddBlockCommand(_commands, @"topic", @"Gets or sets the topic of the room", ^(NSString *args) {
			NSRange spaceRange = [args rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
			NSString *roomId = [args substringToIndex:spaceRange.location];
			NSString *topic = [args substringFromIndex:NSMaxRange(spaceRange)];
			if ([topic length] > 0) {
				
			} else {
				
			}
		});
		
		GFCampfireAddBlockCommand(_commands, @"name", @"Gets or sets the name of the room", ^(NSString *args) {
			NSRange spaceRange = [args rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
			NSString *roomId = [args substringToIndex:spaceRange.location];
			NSString *name = [args substringFromIndex:NSMaxRange(spaceRange)];
			if ([name length] > 0) {
				
			} else {
				
			}
		});
		
		GFCampfireAddBlockCommand(_commands, @"info", @"Displays information about the plugin", ^(NSString *args) {
			IMServicePlugInMessage *message = [self infoMessage];
			[serviceApplication plugInDidReceiveMessage:message fromHandle:@"console"];
		});
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
	[_networkEngine performSelector:@selector(setCustomOperationSubclass:) withObject:[GFCampfireOperation class]];
	[_networkEngine setReachabilityChangedHandler:^(NetworkStatus status) {
		self.reachable = (status != NotReachable);
	}];
}

- (oneway void)login
{
	DDLogInfo(@"================================================================================");
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
		
		[self updateInformationForUser:_me];
		[self getAllRooms];
		[self getUserRooms];
		[serviceApplication plugInDidLogIn];
	} onError:^(NSError *error) {
		if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == 401) {
			[serviceApplication plugInDidFailToAuthenticate];
		} else {
			[serviceApplication plugInDidLogOutWithError:error reconnect:YES];
		}
	}];
	[_networkEngine enqueueOperation:loginOperation forceReload:YES];
}

- (oneway void)logout
{
	for (GCDAsyncSocket *socket in _chats.objectEnumerator) {
		[socket disconnect];
	}
	[_chats removeAllObjects];
	[serviceApplication plugInDidLogOutWithError:nil reconnect:NO];
	_me = nil;
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

- (oneway void)leaveChatRoom:(NSString *)roomId
{
	static BOOL shouldLeaveRemote = NO;
	if (shouldLeaveRemote) {
		// Only do a remote leave if user is configured to do so
		// TODO: find a way to make this a preference
		[self leaveRoom:roomId];
	}
	[self didLeaveRoom:roomId];
}

- (void)leaveRoom:(NSString *)roomId
{
	if (_me && _me.apiAuthToken) {
		MKNetworkOperation *leaveRoomOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@/leave.json", roomId] params:nil httpMethod:@"POST" ssl:_useSSL];
		[leaveRoomOperation setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
		[leaveRoomOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		} onError:^(NSError *error) {
		}];
		[_networkEngine enqueueOperation:leaveRoomOperation forceReload:YES];
	}
}

- (void)didLeaveRoom:(NSString *)roomId
{
	[self stopStreamingRoom:roomId];
	[serviceApplication plugInDidLeaveChatRoom:roomId error:nil];
	[_activeRooms removeObjectForKey:roomId];
}

- (oneway void)inviteHandles:(NSArray *)handles toChatRoom:(NSString *)roomName withMessage:(IMServicePlugInMessage *)message
{
}

- (GFCampfireCommand *)commandForMessage:(NSString *)message
{
	GFCampfireCommand *command = nil;
	if ([message hasPrefix:@"/"]) {
		message = [message substringFromIndex:1];
		NSScanner *scanner = [NSScanner scannerWithString:message];
		NSString *commandString = nil;
		NSMutableCharacterSet *c = [[NSMutableCharacterSet alloc] init];
		[c formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
		[c formUnionWithCharacterSet:[NSCharacterSet newlineCharacterSet]];
		if ([scanner scanUpToCharactersFromSet:c intoString:&commandString]) {
			command = [_commands objectForKey:commandString];
		}
	}
	return command;
}

- (NSString *)argumentsForCommand:(GFCampfireCommand *)command inMessage:(NSString *)message
{
	NSString *arguments = nil;
	NSString *commandString = [NSString stringWithFormat:@"/%@", command.command];
	if ([message hasPrefix:commandString]) {
		arguments = [message substringFromIndex:[commandString length]];
	}
	
	return arguments;
}

- (oneway void)sendMessage:(IMServicePlugInMessage *)message toChatRoom:(NSString *)roomId
{
	if (_me && _me.apiAuthToken) {
		NSString *messageBody = [message.content string];
		
		GFCampfireCommand *command = [self commandForMessage:messageBody];
		if (command) {
			NSString *args = [self argumentsForCommand:command inMessage:messageBody];
			[command performActionWithObject:self args:[NSString stringWithFormat:@"%@ %@", roomId, args]];
		} else {
			NSMutableDictionary *jsonMessage = [NSMutableDictionary dictionary];
			[jsonMessage setObject:@"TextMessage" forKey:@"type"];
			[jsonMessage setObject:messageBody forKey:@"body"];
			MKNetworkOperation *sendMessageOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@/speak.json", roomId]
																				  params:[NSMutableDictionary dictionaryWithObject:jsonMessage forKey:@"message"]
																			  httpMethod:@"POST"
																					 ssl:_useSSL];
			[sendMessageOperation setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
			[sendMessageOperation onCompletion:^(MKNetworkOperation *completedOperation) {
				id json = completedOperation.responseJSON;
				__unused GFCampfireMessage *sentMessage = [GFJSONObject objectWithDictionary:json];
				[serviceApplication plugInDidSendMessage:message toChatRoom:roomId error:nil];
			} onError:^(NSError *error) {
				[serviceApplication plugInDidSendMessage:message toChatRoom:roomId error:error];
			}];
			[_networkEngine enqueueOperation:sendMessageOperation forceReload:YES];
		}
	}
}

- (oneway void)declineChatRoomInvitation:(NSString *)roomName
{
	
}

#pragma mark -
#pragma mark IMServicePlugInGroupListHandlePictureSupport

- (oneway void)requestPictureForHandle:(NSString *)handle withIdentifier:(NSString *)identifier
{
	GFCampfireUser *user = [_users objectForKey:handle];
	if (user) {
		if ((user.avatarData == nil && user.avatarURL != nil)/* ||
			(user.avatarURL != nil && [user.avatarKey isEqualToString:identifier] == NO)*/) {
//			[_networkEngine imageAtURL:user.avatarURL onCompletion:^(NSImage *fetchedImage, NSURL *url, BOOL isInCache) {
//				
//			}];
			NSURLRequest *request = [NSURLRequest requestWithURL:user.avatarURL];
			[NSURLConnection sendAsynchronousRequest:request
											   queue:[NSOperationQueue mainQueue]
								   completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
									   if (data != nil && error == nil) {
										   user.avatarData = data;
										   [self userAvatarUpdated:user];
									   } else {
										   DDLogError(@"Error fetching avatar: %@", error);
									   }
								   }];
//			NSError *error = nil;
//			NSURLResponse *response = nil;
//			NSData *pictureData = [NSURLConnection sendSynchronousRequest:request
//														returningResponse:&response
//																	error:&error];
//			if (pictureData) {
//				user.avatarData = pictureData;
//			}
		} else {
			[self userAvatarUpdated:user];
		}
	} else if ([handle isEqualToString:@"console"]) {
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		NSURL *url = [bundle URLForImageResource:@"Campfire"];
		NSData *data = [NSData dataWithContentsOfURL:url];
		if (data) {
			NSDictionary *consoleProperties = [NSDictionary dictionaryWithObject:data forKey:IMHandlePropertyPictureData];
			[serviceApplication plugInDidUpdateProperties:consoleProperties ofHandle:handle];
		}
	}
}

- (void)userAvatarUpdated:(GFCampfireUser *)user
{
	if (user.avatarData != nil) {
		NSDictionary *userProperties = [NSDictionary dictionaryWithObject:user.avatarData forKey:IMHandlePropertyPictureData];
		[serviceApplication plugInDidUpdateProperties:userProperties ofHandle:user.userKey];
	}
}

#pragma mark -
#pragma mark IMServicePlugInGroupListSupport

- (void)sendGroupListUpdate
{
	NSMutableDictionary *campfireGroup = [NSMutableDictionary dictionary];
	[campfireGroup setObject:@"Campfire" forKey:IMGroupListNameKey];
//	[campfireGroup setObject:[NSArray array] forKey:IMGroupListPermissionsKey];
	NSMutableArray *handles = [NSMutableArray arrayWithObject:@"console"];
//	[handles addObjectsFromArray:_users.allKeys];
	[campfireGroup setObject:handles forKey:IMGroupListHandlesKey];
	[serviceApplication plugInDidUpdateGroupList:[NSArray arrayWithObject:campfireGroup] error:nil];
}

- (oneway void)requestGroupList
{
	[self sendGroupListUpdate];
	
	NSMutableDictionary *properties = [NSMutableDictionary dictionary];
	[properties setObject:[NSNumber numberWithInteger:IMHandleAvailabilityAvailable] forKey:IMHandlePropertyAvailability];
	CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
	[properties setObject:(__bridge NSString *)uuidString forKey:IMHandlePropertyPictureIdentifier];
	CFRelease(uuidString);
	CFRelease(uuidRef);
	[properties setObject:@"Execute Campfire commands here. Use /help for help." forKey:IMHandlePropertyStatusMessage];
	[properties setObject:@"Console" forKey:IMHandlePropertyAlias];
	[properties setObject:[NSArray arrayWithObjects:IMHandleCapabilityMessaging, IMHandleCapabilityHandlePicture, nil]
				   forKey:IMHandlePropertyCapabilities];
	
	[serviceApplication plugInDidUpdateProperties:properties ofHandle:@"console"];
}

#pragma mark -
#pragma mark IMServicePlugInPresenceSupport

- (oneway void)updateSessionProperties:(NSDictionary *)properties
{
}

#pragma mark -
#pragma mark IMServicePlugInInstantMessagingSupport

- (oneway void)userDidStartTypingToHandle:(NSString *)handle
{
}

- (oneway void)userDidStopTypingToHandle:(NSString *)handle
{
}

- (oneway void)sendMessage:(IMServicePlugInMessage *)message toHandle:(NSString *)handle
{
	if ([handle isEqualToString:@"console"]) {
		NSString *messageString = message.content.string;
		
		GFCampfireCommand *command = [self commandForMessage:messageString];
		if (command) {
			NSString *args = [self argumentsForCommand:command inMessage:messageString];
			[command performActionWithObject:self args:args];
		} else {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Invalid Console Command"
																 forKey:NSLocalizedDescriptionKey];
			NSError *error = [NSError errorWithDomain:kGFCampfireErrorDomain
												 code:GFCampfireErrorConsoleInvalidCommand
											 userInfo:userInfo];
			[serviceApplication plugInDidSendMessage:message toHandle:handle error:error];
		}
	} else {
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Messaging Campfire users not supported" forKey:NSLocalizedDescriptionKey];
		NSError *error = [NSError errorWithDomain:kGFCampfireErrorDomain code:GFCampfireErrorMessagingUsersNotSupported userInfo:userInfo];
		[serviceApplication plugInDidSendMessage:message toHandle:handle error:error];
	}
}

#pragma mark -
#pragma mark Helper Methods

- (void)getAllRooms
{
	if (_me && _me.apiAuthToken) {
		MKNetworkOperation *roomListOperation = [_networkEngine operationWithPath:@"rooms.json" params:nil httpMethod:@"GET" ssl:_useSSL];
		[roomListOperation setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
		[roomListOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = [completedOperation responseJSON];
			NSArray *allRooms = [GFJSONObject objectWithDictionary:json];
			
			for (GFCampfireRoom *room in allRooms) {
				for (GFCampfireUser *user in room.users) {
					[self updateInformationForUser:user];
				}
				GFCampfireRoom *existingRoom = [_rooms objectForKey:room.roomKey];
				if (existingRoom) {
					// update existing room
					[existingRoom updateWithRoom:room];
				} else {
					[_rooms setObject:room forKey:room.roomKey];
				}
			}
		} onError:^(NSError *error) {
			DDLogError(@"Error fetching rooms, %@", error);
		}];
		[_networkEngine enqueueOperation:roomListOperation forceReload:YES];
	}
}

- (void)getUserRooms
{
	if (_me && _me.apiAuthToken) {
		MKNetworkOperation *usersRooms = [_networkEngine operationWithPath:@"presence.json" params:nil httpMethod:@"GET" ssl:_useSSL];
		[usersRooms setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
		[usersRooms onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = [completedOperation responseJSON];
			NSArray *usersRooms = [GFJSONObject objectWithDictionary:json];
			
			for (GFCampfireRoom *room in usersRooms) {
//				[_activeRooms setObject:room forKey:room.roomKey];
//				[self updateInformationForRoom:room didJoin:YES];
				NSAttributedString *inviteMessage = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Join %@?", room.name]];
				IMServicePlugInMessage *message = [IMServicePlugInMessage servicePlugInMessageWithContent:inviteMessage];
				[serviceApplication plugInDidReceiveInvitation:message forChatRoom:room.roomKey fromHandle:nil/*@"console"*/];
			}
		} onError:^(NSError *error) {
			DDLogError(@"Error fetching users active rooms, %@", error);
		}];
		[_networkEngine enqueueOperation:usersRooms forceReload:YES];
	}
}

- (void)getRoom:(NSString *)roomId didJoin:(BOOL)didJoin
{
	if (_me && _me.apiAuthToken) {
		MKNetworkOperation *roomOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"room/%@.json", roomId] params:nil httpMethod:@"GET" ssl:_useSSL];
		[roomOperation setUsername:_me.apiAuthToken	password:@"X" basicAuth:YES];
		[roomOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = [completedOperation responseJSON];
			GFCampfireRoom *room = [GFJSONObject objectWithDictionary:json];
			[self updateInformationForRoom:room didJoin:didJoin];
		} onError:^(NSError *error) {
			DDLogError(@"Error fetching room %@, %@", roomId, error);
		}];
		[_networkEngine enqueueOperation:roomOperation forceReload:YES];
	}
}
- (void)didJoinRoom:(NSString *)roomId
{
	GFCampfireRoom *room = [_rooms objectForKey:roomId];
	if (room) {
		[_activeRooms setObject:room forKey:room.roomKey];
		
		[self startStreamingRoom:roomId];
		
		[self getRoom:roomId didJoin:YES];
		NSString *lastMessageKey = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"Campfire-%@", roomId]];
		[self getRecentMessagesForRoom:roomId sinceMessage:lastMessageKey];
		
		[serviceApplication plugInDidJoinChatRoom:roomId];
		[serviceApplication plugInDidReceiveNotice:room.topic forChatRoom:roomId];
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
			[self processHistoryMessages:messages];
		} onError:^(NSError *error) {
			// couldn't fetch recents, do I care?
			DDLogError(@"Error fetching recent messages for room %@ starting with message %@, %@", roomId, messageId, error);
		}];
		[_networkEngine enqueueOperation:recentMessagesOperation forceReload:YES];
	}
}

- (void)processHistoryMessages:(NSArray *)messages
{
	for (GFCampfireMessage *message in messages) {
		[self processHistoryMessage:message];
	}
}

- (void)processHistoryMessage:(GFCampfireMessage *)message
{
	[self processMessage:message historyMessage:YES streamMessage:NO];
}

- (void)processStreamMessage:(GFCampfireMessage *)message
{
	[self processMessage:message historyMessage:NO streamMessage:YES];
}

- (void)processMessage:(GFCampfireMessage *)message historyMessage:(BOOL)isHistoryMessage streamMessage:(BOOL)isStreamMessage
{
	if (message.roomId != NSNotFound) {
		NSString *roomId = [[NSNumber numberWithInteger:message.roomId] stringValue];
		NSString *userId = nil;
		if (message.userId != NSNotFound) {
			userId = [[NSNumber numberWithInteger:message.userId] stringValue];
				
			if (message.type == GFCampfireMessageTypeLeave || message.type == GFCampfireMessageTypeKick) {
				[serviceApplication handles:[NSArray arrayWithObject:userId] didLeaveChatRoom:roomId];
			} else if (message.type == GFCampfireMessageTypeEnter) {
				[serviceApplication handles:[NSArray arrayWithObject:userId] didJoinChatRoom:roomId];
				[self getRemoteUserInfo:userId];
			} else if (message.type == GFCampfireMessageTypeTopicChange) {
				[serviceApplication plugInDidReceiveNotice:message.body forChatRoom:roomId];
			} else if (message.type == GFCampfireMessageTypeText || message.type == GFCampfireMessageTypePaste) {
				if (message.body != nil) {
					NSMutableAttributedString *messageString = [[NSMutableAttributedString alloc] initWithString:message.body];
					if (message.type == GFCampfireMessageTypePaste) {
						[messageString setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:IMAttributePreformatted] range:NSMakeRange(0, [messageString length])];
					}
					IMServicePlugInMessage *pluginMessage = [IMServicePlugInMessage servicePlugInMessageWithContent:messageString];
					
					
					[self getRemoteUserInfo:userId];
					if (message.userId == _me.userId) {
//						if (!isHistoryMessage && !isStreamMessage) {
//							[serviceApplication plugInDidSendMessage:pluginMessage toChatRoom:roomId error:nil];
//						}
					} else {
						[serviceApplication plugInDidReceiveMessage:pluginMessage forChatRoom:roomId fromHandle:userId];
					}
				}
			}
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:message.messageKey forKey:[NSString stringWithFormat:@"Campfire-%@", roomId]];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (void)updateInformationForRoom:(GFCampfireRoom *)room didJoin:(BOOL)didJoin
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
		if (didJoin) {
			// on joining we will announce all users
			[serviceApplication handles:[room.users valueForKey:@"userKey"] didJoinChatRoom:room.roomKey];
		} else {
			NSArray *joinedHandles = [[joinedUsers valueForKey:@"userKey"] allObjects];
			NSArray *departedHandles = [[departedUsers valueForKey:@"userKey"] allObjects];
			
			if ([joinedHandles count] > 0) {
				[serviceApplication handles:joinedHandles didJoinChatRoom:room.roomKey];
			}
			
			if ([departedHandles count] > 0) {
				[serviceApplication handles:departedHandles didLeaveChatRoom:room.roomKey];
			}
		}
		
		for (GFCampfireUser *user in [joinedUsers setByAddingObjectsFromSet:departedUsers]) {
			[self updateInformationForUser:user];
		}
		
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
	
//	if (triggersUpdate) {
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:user.name forKey:IMHandlePropertyAlias];
		[userInfo setObject:user.emailAddress forKey:IMHandlePropertyEmailAddress];
		[userInfo setObject:[NSArray arrayWithObjects:IMHandleCapabilityHandlePicture, nil] forKey:IMHandlePropertyCapabilities];
		if (user.avatarURL) {
			CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
			CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
			
			[userInfo setObject:(__bridge NSString *)uuidString forKey:IMHandlePropertyPictureIdentifier];
			CFRelease(uuidString);
			CFRelease(uuidRef);
//			[userInfo setObject:user.avatarKey forKey:IMHandlePropertyPictureIdentifier];
		}
		
		NSInteger userStatus = IMHandleAvailabilityUnknown;
		for (GFCampfireRoom *room in _rooms.objectEnumerator) {
			if ([room.users indexOfObject:user] != NSNotFound) {
				userStatus = IMHandleAvailabilityAvailable;
				break;
			}
		}
		[userInfo setObject:[NSNumber numberWithInteger:userStatus] forKey:IMHandlePropertyAvailability];
		
		[serviceApplication plugInDidUpdateProperties:userInfo ofHandle:user.userKey];
//	}
}

- (void)updateInformationForUserId:(NSString *)userKey
{
	GFCampfireUser *user = [_users objectForKey:userKey];
	if (user) {
		[self updateInformationForUser:user];
	} else if ([userKey isEqualToString:@"console"]) {
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:@"Console" forKey:IMHandlePropertyAlias];
		[userInfo setObject:[NSArray arrayWithObjects:IMHandleCapabilityHandlePicture, IMHandleCapabilityMessaging, nil] forKey:IMHandlePropertyCapabilities];
		CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
		CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
		
		[userInfo setObject:(__bridge NSString *)uuidString forKey:IMHandlePropertyPictureIdentifier];
		CFRelease(uuidString);
		CFRelease(uuidRef);
		
		[userInfo setObject:[NSNumber numberWithInteger:IMHandleAvailabilityAvailable] forKey:IMHandlePropertyAvailability];
		
		[serviceApplication plugInDidUpdateProperties:userInfo ofHandle:user.userKey];
	}
}

- (void)getRemoteUserInfo:(NSString *)userId
{
	if (_me && _me.apiAuthToken) {
		if ([_users objectForKey:userId] == nil) {
			MKNetworkOperation *getUserOperation = [_networkEngine operationWithPath:[NSString stringWithFormat:@"users/%@.json", userId] params:nil httpMethod:@"GET" ssl:_useSSL];
			[getUserOperation setUsername:_me.apiAuthToken password:@"X" basicAuth:YES];
			[getUserOperation onCompletion:^(MKNetworkOperation *completedOperation) {
				id json = [completedOperation responseJSON];
				GFCampfireUser *user = [GFJSONObject objectWithDictionary:json];
				[self updateInformationForUser:user];
			} onError:^(NSError *error) {
				// couldn't fetch user, do I care?
				DDLogError(@"Error fetching info for user %@, %@", userId, error);
			}];
			[_networkEngine enqueueOperation:getUserOperation forceReload:YES];
		} else {
			[self updateInformationForUserId:userId];
		}
	}
}

- (void)startStreamingRoom:(NSString *)roomId
{
	NSString *host = @"streaming.campfirenow.com";
	
	__strong GCDAsyncSocket *asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	[_chats setObject:asyncSocket forKey:roomId];
	
	uint16_t port = 0;
	if (_useSSL) {
		port = 443;
	} else {
		port = 80;
	}
	
	NSError *error = nil;
	if (![asyncSocket connectToHost:host onPort:port error:&error]) {
		DDLogError(@"Error establishing stream for room %@. Could not connect to %@, %@", roomId, host, error);
	} else {
		DDLogInfo(@"Connecting to %@...", host);
	}
	
	if (_useSSL) {
		NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
															forKey:(NSString *)kCFStreamSSLValidatesCertificateChain];
		
		[asyncSocket startTLS:options];
	}
}

- (void)stopStreamingRoom:(NSString *)roomId
{
	GCDAsyncSocket *asyncSocket = [_chats objectForKey:roomId];
	if (asyncSocket) {
		[asyncSocket disconnectAfterReadingAndWriting];
	}
}

#pragma mark -
#pragma mark GCDAsyncSocketDelegate

- (void)socketDidSecure:(__unsafe_unretained GCDAsyncSocket *)socket
{
	NSString *roomId = [self roomIdForSocket:socket];
	if (roomId) {
		DDLogInfo(@"Socket secured for room %@", roomId);
	}
}

- (void)socket:(__unsafe_unretained GCDAsyncSocket *)socket didConnectToHost:(__unsafe_unretained NSString *)hostName port:(UInt16)port
{
	NSString *roomId = [self roomIdForSocket:socket];
	if (roomId) {
		NSURL *host = [NSURL URLWithString:@"https://streaming.campfirenow.com"];
		NSString *streamingPath = [NSString stringWithFormat:@"room/%@/live.json", roomId];
		NSURL *streamingURL = [host URLByAppendingPathComponent:streamingPath];
		
		CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("GET"), (__bridge CFURLRef)streamingURL, kCFHTTPVersion1_1);
		
		CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Connection"), CFSTR("Keep-Alive"));
		CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Host"), CFSTR("streaming.campfirenow.com"));
		CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Accept"), CFSTR("*/*"));
		
		CFHTTPMessageAddAuthentication(request, NULL, (__bridge CFStringRef)_me.apiAuthToken, CFSTR("X"), kCFHTTPAuthenticationSchemeBasic, false);
		
		CFDataRef requestData = CFHTTPMessageCopySerializedMessage(request);
		
		[socket writeData:(__bridge NSData *)requestData withTimeout:-1.0 tag:0];
		
		NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
		[socket readDataToData:responseTerminatorData withTimeout:-1.0 tag:0];
	}
}

- (void)socket:(__unsafe_unretained GCDAsyncSocket *)socket didReadData:(__unsafe_unretained NSData *)data withTag:(long)tag
{
	NSString *roomId = [self roomIdForSocket:socket];
	NSString *stringDataWithCRLF = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (tag == 0) {
		DDLogInfo(@"Received header for streaming room %@ - %@", roomId, stringDataWithCRLF);
		if ([stringDataWithCRLF hasSuffix:@"\r\n\r\n"]) {
			NSString *httpHeader = [stringDataWithCRLF substringToIndex:([stringDataWithCRLF length] - 4)];
			NSArray *httpHeaderParts = [httpHeader componentsSeparatedByString:@"\r\n"];
			__block CFHTTPMessageRef response = NULL;
			[httpHeaderParts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				NSString *headerPart = obj;
				if (idx == 0) {
					NSScanner *scanner = [NSScanner scannerWithString:headerPart];
					[scanner scanString:@"HTTP/" intoString:nil];
					NSString *httpVersionString = nil;
					[scanner scanUpToString:@" " intoString:&httpVersionString];
					NSInteger httpCode = 0;
					[scanner scanInteger:&httpCode];
					
					CFStringRef httpVersion = [httpVersionString isEqualToString:@"1.1"] ? kCFHTTPVersion1_1 : kCFHTTPVersion1_0;
					response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, httpCode, NULL, httpVersion);
				} else {
					NSArray *headerFieldValue = [headerPart componentsSeparatedByString:@": "];
					if ([headerFieldValue count] == 2) {
						CFHTTPMessageSetHeaderFieldValue(response, (__bridge CFStringRef)[headerFieldValue objectAtIndex:0], (__bridge CFStringRef)[headerFieldValue objectAtIndex:1]);
					}
				}
			}];
		}
	} else if (tag == 1) {
		NSString *stringData = [stringDataWithCRLF substringWithRange:NSMakeRange(0, [stringDataWithCRLF length] - 2)];
		if ([stringData hasPrefix:@"{"]) {
			// probably JSON data, could be multiple JSON dictionaries
			NSArray *jsonStrings = [stringData jsonStrings];
			for (NSString *jsonString in jsonStrings) {
				NSError *error = nil;
				
				id jsonObj = [jsonString jsonObject:&error];
				if (jsonObj != nil) {
					DDLogInfo(@"Received Message: %@", jsonString);
					if ([jsonObj isKindOfClass:[NSDictionary class]]) {
						GFCampfireMessage *campfireObj = [[GFCampfireMessage alloc] initWithDictionary:jsonObj];
						[self processStreamMessage:(GFCampfireMessage *)campfireObj];
					}
				} else if (error) {
					DDLogWarn(@"Error parsing JSON stream: %@, data=%@", error, jsonString);
				}
			}
		} else if ([stringData isEqualToString:@" "] || [stringData length] == 0) {
			// nothing of value
		} else {
			__unused NSInteger pingNumber = [stringData integerValue];
			// wtf does the campfire api expect us to do with this number?
		}
	}
	
	// XXX: CRLF could be problematic if someone sends/pastes a \r\n in the body or whatnot of their message
	[socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:5.0 tag:1];
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
	// need to attempt to re-establish connection
	return 0.0;
}

- (void)socketDidDisconnect:(__unsafe_unretained GCDAsyncSocket *)sock withError:(__unsafe_unretained NSError *)err
{
	NSString *roomId = [self roomIdForSocket:sock]; //error code = 4, domain = GCDAsyncSocketErrorDomain == timeout
	DDLogWarn(@"Socket for room %@ disconnected with error: %@", roomId, err);
	if (roomId) {
		[serviceApplication plugInDidLeaveChatRoom:roomId error:err];
		
		if (self.reachable) {
			// TODO: test/enable this
//			[self didJoinRoom:roomId];
		}
	}
}

- (NSString *)roomIdForSocket:(__unsafe_unretained GCDAsyncSocket *)socket
{
	NSString *roomId = [[_chats allKeysForObject:socket] lastObject];
	return roomId;
}

@end
