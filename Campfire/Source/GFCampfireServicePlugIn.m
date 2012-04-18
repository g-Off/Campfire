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

#import "LoggerClient.h"

#import <MKNetworkKit/MKNetworkKit.h>

#import "GFJSONObject.h"
#import "GFCampfireUser.h"
#import "GFCampfireRoom.h"
#import "GFCampfireMessage.h"
#import "GFCampfireUpload.h"

#import "GFCampfireOperation.h"

#import "GCDAsyncSocket.h"
#import "GFCampfireCommand.h"
#import "NSString+GFJSONObject.h"

static const int ddLogLevel = LOG_LEVEL_VERBOSE;
static NSString *kGFCampfireErrorDomain = @"GFCampfireErrorDomain";

typedef enum {
	GFCampfireLogLevelError,
	GFCampfireLogLevelWarning,
	GFCampfireLogLevelInfo,
	GFCampfireLogLevelDebug,
} GFCampfireLogLevel;

#define LOG_MESSAGE(level, domain, ...) LogMessageF(__FILE__, __LINE__, __FUNCTION__, domain, level, __VA_ARGS__)
#define LOG_IMAGE(level, domain, data) LogImageDataF(__FILE__, __LINE__, __FUNCTION__, domain, level, 0, 0, data)

static NSString *kGFCampfireLogDomainAvatar		= @"avatar";
static NSString *kGFCampfireLogDomainUser		= @"user";
static NSString *kGFCampfireLogDomainChat		= @"chat";
static NSString *kGFCampfireLogDomainConsole	= @"console";
static NSString *kGFCampfireLogDomainNetwork	= @"network";

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
	NSMutableSet *_activeRooms;
	NSMutableDictionary *_users;
	NSMutableDictionary *_chatStreams;
	NSMutableDictionary *_commands;
	NSMutableDictionary *_roomData;
	
	NSCache *_avatarCache;
	
	NSString *_consoleHandle;
}

static NSString *kGFCampfireRoomLastMessage = @"GFCampfireRoomLastMessage";

@synthesize reachable=_reachable;

+ (void)initialize
{
	if (self == [GFCampfireServicePlugIn class]) {
		NSString *appName = [[NSBundle bundleForClass:self] bundleIdentifier];
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
		NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
		NSString *logsDirectory = [[basePath stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:appName];
		DDLogFileManagerDefault *fileManager = [[DDLogFileManagerDefault alloc] initWithLogsDirectory:logsDirectory];
		[DDLog addLogger:[[DDFileLogger alloc] initWithLogFileManager:fileManager]];
		[GFJSONObject registerClassPrefix:@"GFCampfire"];
	}
}

#pragma mark -
#pragma mark IMServicePlugIn

- (id)initWithServiceApplication:(id <IMServiceApplication, IMServiceApplicationGroupListSupport, IMServiceApplicationChatRoomSupport, IMServiceApplicationInstantMessagingSupport>)aServiceApplication
{
	if ((self = [super init])) {
		serviceApplication = aServiceApplication;
		
		_rooms = [[NSMutableDictionary alloc] init];
		_activeRooms = [[NSMutableSet alloc] init];
		_users = [[NSMutableDictionary alloc] init];
		_chatStreams = [[NSMutableDictionary alloc] init];
		
		_roomData = [[NSMutableDictionary alloc] init];
		
		_avatarCache = [[NSCache alloc] init];
		
		[self addCommands];
		
		LoggerSetupBonjour(NULL, NULL, NULL);
	}
	
	return self;
}

- (oneway void)updateAccountSettings:(NSDictionary *)accountSettings
{
	_server = [accountSettings objectForKey:IMAccountSettingServerHost];
	_username = [accountSettings objectForKey:IMAccountSettingLoginHandle];
	_password = [accountSettings objectForKey:IMAccountSettingPassword];
	_useSSL = [[accountSettings objectForKey:IMAccountSettingUsesSSL] boolValue];
	
	_consoleHandle = [[NSString alloc] initWithFormat:@"console@%@", [_server lowercaseString]];
	
	_networkEngine = [[MKNetworkEngine alloc] initWithHostName:_server customHeaderFields:nil];
	[_networkEngine performSelector:@selector(setCustomOperationSubclass:) withObject:[GFCampfireOperation class]];
	[_networkEngine setReachabilityChangedHandler:^(NetworkStatus status) {
		self.reachable = (status != NotReachable);
	}];
}

- (oneway void)login
{
	DDLogInfo(@"================================================================================");
	LogMarker([NSString stringWithFormat:@"Beginning new session for %@", _username]);
	MKNetworkOperation *loginOperation = [_networkEngine operationWithPath:@"users/me.json" params:nil httpMethod:@"GET" ssl:_useSSL];
	[loginOperation setUsername:_username password:_password basicAuth:YES];
	[loginOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		GFCampfireUser *newMe = [GFCampfireUser objectWithDictionary:json];
		if (_me && [_me isEqual:newMe]) {
			[_me updateWithUser:newMe];
		} else {
			_me = newMe;
		}
		
		[self addUser:_me];
//		[self updateInformationForUser:_me];
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
	[self enqueueOperation:loginOperation forceReload:YES];
}

- (oneway void)logout
{
	for (GCDAsyncSocket *socket in _chatStreams.objectEnumerator) {
		[socket disconnect];
	}
	[_chatStreams removeAllObjects];
	[serviceApplication plugInDidLogOutWithError:nil reconnect:NO];
	LogMarker([NSString stringWithFormat:@"Ending session for %@", _username]);
	_me = nil;
}

#pragma mark -
#pragma mark Network Operation

- (MKNetworkOperation *)operationWithPath:(NSString *)path params:(NSMutableDictionary *)params httpMethod:(NSString *)method
{
	MKNetworkOperation *operation = nil;
	if (_me && _me.apiAuthToken) {
		operation = [_networkEngine operationWithPath:path params:params httpMethod:method];
		[operation setUsername:_me.apiAuthToken	password:@"X" basicAuth:YES];
	}
	
	return operation;
}

- (void)enqueueOperation:(MKNetworkOperation *)operation
{
	[self enqueueOperation:operation forceReload:NO];
}

- (void)enqueueOperation:(MKNetworkOperation *)operation forceReload:(BOOL)forceReload
{
	LOG_MESSAGE(GFCampfireLogLevelDebug, kGFCampfireLogDomainNetwork, @"Performing request: %@", [operation curlCommandLineString]);
	[_networkEngine enqueueOperation:operation forceReload:forceReload];
}

#pragma mark -
#pragma mark IMServicePlugInChatRoomSupport

- (oneway void)joinChatRoom:(NSString *)roomId
{
	if ([_activeRooms containsObject:roomId] == NO) {
		MKNetworkOperation *joinRoomOperation = [self operationWithPath:[NSString stringWithFormat:@"room/%@/join.json", roomId] params:nil httpMethod:@"POST"];
		[joinRoomOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			[self didJoinRoom:roomId];
		} onError:^(NSError *error) {
			if ([_activeRooms containsObject:roomId]) {
				[self didJoinRoom:roomId];
			} else {
				[serviceApplication plugInDidLeaveChatRoom:roomId error:error];
			}
		}];
		[self enqueueOperation:joinRoomOperation forceReload:YES];
	} else {
		[self didJoinRoom:roomId];
	}
}

- (oneway void)leaveChatRoom:(NSString *)roomId
{
	static BOOL shouldLeaveRemote = YES;
	if (shouldLeaveRemote) {
		// Only do a remote leave if user is configured to do so
		// TODO: find a way to make this a preference
		[self leaveRoom:roomId];
	}
	[self didLeaveRoom:roomId];
}

- (void)leaveRoom:(NSString *)roomId
{
	MKNetworkOperation *leaveRoomOperation = [self operationWithPath:[NSString stringWithFormat:@"room/%@/leave.json", roomId] params:nil httpMethod:@"POST"];
	[leaveRoomOperation onCompletion:^(MKNetworkOperation *completedOperation) {
	} onError:^(NSError *error) {
	}];
	[self enqueueOperation:leaveRoomOperation forceReload:YES];
}

- (void)didLeaveRoom:(NSString *)roomId
{
	[self stopStreamingRoom:roomId];
	[serviceApplication plugInDidLeaveChatRoom:roomId error:nil];
	[_activeRooms removeObject:roomId];
}

- (oneway void)inviteHandles:(NSArray *)handles toChatRoom:(NSString *)roomName withMessage:(IMServicePlugInMessage *)message
{
}

- (oneway void)sendMessage:(IMServicePlugInMessage *)message toChatRoom:(NSString *)roomId
{
	NSString *messageBody = [message.content string];
	
	GFCampfireCommand *command = [self commandForMessage:messageBody];
	if (command) {
		NSString *args = [self argumentsForCommand:command inMessage:messageBody];
		[command performActionWithObject:self args:[NSString stringWithFormat:@"%@ %@", roomId, args]];
	} else {
		NSMutableDictionary *jsonMessage = [NSMutableDictionary dictionary];
		[jsonMessage setObject:@"TextMessage" forKey:@"type"];
		[jsonMessage setObject:messageBody forKey:@"body"];
		MKNetworkOperation *sendMessageOperation = [self operationWithPath:[NSString stringWithFormat:@"room/%@/speak.json", roomId]
																	params:[NSMutableDictionary dictionaryWithObject:jsonMessage forKey:@"message"]
																httpMethod:@"POST"];
		[sendMessageOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = completedOperation.responseJSON;
			__unused GFCampfireMessage *sentMessage = [GFCampfireMessage objectWithDictionary:json];
			[serviceApplication plugInDidSendMessage:message toChatRoom:roomId error:nil];
		} onError:^(NSError *error) {
			[serviceApplication plugInDidSendMessage:message toChatRoom:roomId error:error];
		}];
		[self enqueueOperation:sendMessageOperation forceReload:YES];
	}
}

- (NSString *)campfireMessageFromIMServiceMessage:(IMServicePlugInMessage *)serviceMessage
{
	// Campfire messages need to be in plain-text format so replace all "link" attributes with the actual URL value
	NSAttributedString *serviceMessageBody = [serviceMessage content];
	NSMutableString *message = [[serviceMessageBody string] mutableCopy];
	
	__block NSUInteger offset = 0;
	[serviceMessageBody enumerateAttribute:IMAttributeLink inRange:NSMakeRange(0, [serviceMessageBody length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
		NSURL *url = value;
		NSString *urlString = [url absoluteString];
		NSRange replacementRange = NSMakeRange(offset + range.location, range.length);
		[message replaceCharactersInRange:replacementRange withString:urlString];
		offset += range.length - [urlString length];
	}];
	
	return [message copy];
}

- (oneway void)declineChatRoomInvitation:(NSString *)roomName
{
}

#pragma mark -
#pragma mark IMServicePlugInGroupListHandlePictureSupport

- (oneway void)requestPictureForHandle:(NSString *)handle withIdentifier:(NSString *)identifier
{
	DDLogInfo(@"Avatar with identifier %@ requested for handle %@", identifier, handle);
	LOG_MESSAGE(GFCampfireLogLevelDebug, kGFCampfireLogDomainAvatar, @"requesting identifier %@ for handle %@", identifier, handle);
	
	NSData *avatarData = nil;
	
	if ([handle isEqualToString:_consoleHandle]) {
		NSURL *avatarURL = [[NSBundle bundleForClass:[self class]] URLForImageResource:@"Campfire"];
		avatarData = [_avatarCache objectForKey:avatarURL];
		if (avatarData == nil) {
			avatarData = [NSData dataWithContentsOfURL:avatarURL];
			[_avatarCache setObject:avatarData forKey:avatarURL];
		}
	} else {
		GFCampfireUser *user = [_users objectForKey:handle];
		if (user && user.avatarURL != nil) {
			avatarData = [_avatarCache objectForKey:user.avatarURL];
			if (avatarData == nil) {
				NSURLRequest *request = [NSURLRequest requestWithURL:user.avatarURL];
				[NSURLConnection sendAsynchronousRequest:request
												   queue:[NSOperationQueue mainQueue]
									   completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
										   if (data != nil && error == nil) {
											   [_avatarCache setObject:data forKey:user.avatarURL];
											   [self userId:handle avatarUpdatedWithData:data withIdentifier:identifier];
										   } else {
											   DDLogError(@"Error fetching avatar: %@", error);
											   LOG_MESSAGE(GFCampfireLogLevelError, kGFCampfireLogDomainAvatar, @"failed requesting identifier %@ for handle %@ with error %@", identifier, handle, error);
										   }
									   }];
			}
		}
	}
	
	if (avatarData) {
		[self userId:handle avatarUpdatedWithData:avatarData withIdentifier:identifier];
	}
}

- (void)userId:(NSString *)userId avatarUpdatedWithData:(NSData *)data withIdentifier:(NSString *)identifier
{
	if ([userId length] == 0) {
		LOG_MESSAGE(GFCampfireLogLevelError, kGFCampfireLogDomainAvatar, @"userId cannot be nil or 0-length");
		DDLogError(@"Avatar update failed: userId cannot be nil or 0-length");
	} else if ([data length] == 0) {
		LOG_MESSAGE(GFCampfireLogLevelError, kGFCampfireLogDomainAvatar, @"data cannot be nil or 0-length");
		DDLogError(@"Avatar update failed: data cannot be nil or 0-length");
	} else if ([identifier length] == 0) {
		LOG_MESSAGE(GFCampfireLogLevelError, kGFCampfireLogDomainAvatar, @"identifier cannot be nil or 0-length");
		DDLogError(@"Avatar update failed: identifier cannot be nil or 0-length");
	} else {
		NSDictionary *userProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										data, IMHandlePropertyPictureData,
										identifier, IMHandlePropertyPictureIdentifier,
										nil];
		DDLogInfo(@"Avatar updated: user=%@, identifier=%@", userId, identifier);
		LOG_MESSAGE(GFCampfireLogLevelInfo, kGFCampfireLogDomainAvatar, @"updating avatar for user %@ with identifier %@", userId, identifier);
		LOG_IMAGE(GFCampfireLogLevelInfo, kGFCampfireLogDomainAvatar, data);
		[serviceApplication plugInDidUpdateProperties:userProperties ofHandle:userId];
	}
}

#pragma mark -
#pragma mark IMServicePlugInGroupListSupport

- (oneway void)requestGroupList
{
	NSDictionary *group = [self userGroup];
	DDLogInfo(@"Group List Updated: %@", group);
	LOG_MESSAGE(GFCampfireLogLevelInfo, kGFCampfireLogDomainUser, @"updating group list %@", group);
	[serviceApplication plugInDidUpdateGroupList:[NSArray arrayWithObject:group] error:nil];
	
	[self sendPropertiesOfHandle:_consoleHandle];
}

- (NSDictionary *)userGroup
{
	NSMutableDictionary *campfireGroup = [NSMutableDictionary dictionary];
	[campfireGroup setObject:@"Campfire" forKey:IMGroupListNameKey];
	NSArray *handles = [self userList];
	[campfireGroup setObject:handles forKey:IMGroupListHandlesKey];
	
	return [campfireGroup copy];
}

- (NSArray *)userList
{
	NSMutableArray *userList = [NSMutableArray arrayWithObject:_consoleHandle];
	[userList addObjectsFromArray:[_users allKeys]];
	[userList removeObject:_me.userKey];
	return [userList copy];
}

- (void)sendPropertiesOfHandle:(NSString *)handle
{
	NSDictionary *handleProperties = [self propertiesOfHandle:handle];
	[serviceApplication plugInDidUpdateProperties:handleProperties ofHandle:handle];
}

- (void)sendPropertiesOfHandles:(NSArray *)handles
{
	[handles enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		[self sendPropertiesOfHandle:obj];
	}];
}

- (NSDictionary *)propertiesOfHandle:(NSString *)handle
{
	NSMutableDictionary *properties = [NSMutableDictionary dictionary];
	
	if ([handle isEqualToString:_consoleHandle]) {
		[properties setObject:@"Console" forKey:IMHandlePropertyAlias];
		[properties setObject:[NSArray arrayWithObjects:IMHandleCapabilityMessaging, IMHandleCapabilityHandlePicture, nil]
					   forKey:IMHandlePropertyCapabilities];
		[properties setObject:_consoleHandle forKey:IMHandlePropertyPictureIdentifier];
		[properties setObject:[NSNumber numberWithInteger:IMHandleAvailabilityAvailable] forKey:IMHandlePropertyAvailability];
		[properties setObject:@"Execute Campfire commands here. Use /help for help." forKey:IMHandlePropertyStatusMessage];
	} else {
		GFCampfireUser *user = [_users objectForKey:handle];
		
		[properties setObject:user.name forKey:IMHandlePropertyAlias];
		[properties setObject:user.emailAddress forKey:IMHandlePropertyEmailAddress];
		[properties setObject:[NSArray arrayWithObjects:IMHandleCapabilityHandlePicture, nil] forKey:IMHandlePropertyCapabilities];
		if (user.avatarURL) {
			[properties setObject:user.avatarKey forKey:IMHandlePropertyPictureIdentifier];
		}
		
		NSMutableString *statusMessage = [NSMutableString string];
		if ([user isAdmin]) {
			[statusMessage appendString:@"Admin/"];
		}
		if (user.type == GFCampfireUserTypeGuest) {
			[statusMessage appendString:@"Guest"];
		} else if (user.type == GFCampfireUserTypeMember) {
			[statusMessage appendString:@"Member"];
		}
		[properties setObject:statusMessage forKey:IMHandlePropertyStatusMessage];
		
		NSInteger userStatus = IMHandleAvailabilityUnknown;
		for (GFCampfireRoom *room in _rooms.objectEnumerator) {
			if ([room.users indexOfObject:user] != NSNotFound) {
				userStatus = IMHandleAvailabilityAvailable;
				break;
			}
		}
		[properties setObject:[NSNumber numberWithInteger:userStatus] forKey:IMHandlePropertyAvailability];
	}
	
	DDLogInfo(@"User %@ updated: %@", handle, properties);
	LOG_MESSAGE(GFCampfireLogLevelInfo, kGFCampfireLogDomainUser, @"updating user %@ with properties %@", handle, properties);
	return [properties copy];
}

#pragma mark -
#pragma mark IMServicePlugInPresenceSupport

- (oneway void)updateSessionProperties:(NSDictionary *)properties {}

#pragma mark -
#pragma mark IMServicePlugInInstantMessagingSupport

- (oneway void)userDidStartTypingToHandle:(NSString *)handle {}
- (oneway void)userDidStopTypingToHandle:(NSString *)handle {}

- (oneway void)sendMessage:(IMServicePlugInMessage *)message toHandle:(NSString *)handle
{
	if ([handle isEqualToString:_consoleHandle]) {
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

- (BOOL)userIsOnline:(NSString *)userId
{
	BOOL online = NO;
	for (GFCampfireRoom *room in _rooms.objectEnumerator) {
		NSUInteger userIndex = [room.users indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
			GFCampfireUser *user = obj;
			return [user.key isEqualToString:userId];
		}];
		if (userIndex != NSNotFound) {
			online = YES;
			break;
		}
	}
	
	return online;
}

- (void)getUploadFromMessage:(GFCampfireMessage *)message
{
	NSAssert(message.type == GFCampfireMessageTypeUpload, @"Message Type must be an Upload");
	
	NSInteger roomId = message.roomId;
	NSInteger messageId = message.messageId;
	
	NSString *path = [NSString stringWithFormat:@"room/%ld/messages/%ld/upload.json", roomId, messageId];
	MKNetworkOperation *operation = [self operationWithPath:path params:nil httpMethod:@"GET"];
	[operation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		__unused GFCampfireUpload *upload = [GFCampfireUpload objectWithDictionary:json];
	} onError:^(NSError *error) {
		
	}];
	[self enqueueOperation:operation];
}

- (void)addUser:(GFCampfireUser *)user
{
	GFCampfireUser *existingUser = [_users objectForKey:user.userKey];
	if (existingUser) {
		[existingUser updateWithUser:user];
	} else {
		[_users setObject:user forKey:user.userKey];
		
		NSDictionary *group = [self userGroup];
		[serviceApplication plugInDidUpdateGroupList:[NSArray arrayWithObject:group] error:nil];
	}
	
	[self sendPropertiesOfHandle:user.userKey];
}

- (void)addRoom:(GFCampfireRoom *)room
{
	NSMutableArray *joinedUsers = [NSMutableArray array];
	NSMutableArray *departedUsers = [NSMutableArray array];
	NSMutableArray *newUsers = [NSMutableArray array];
	
	// first sub any existing users into the given rooms list of users
	NSMutableArray *users = [NSMutableArray arrayWithCapacity:[room.users count]];
	for (GFCampfireUser *user in room.users) {
		GFCampfireUser *existingUser = [_users objectForKey:user.userKey];
		if (existingUser) {
			[users addObject:existingUser];
		} else {
			[users addObject:user];
			[newUsers addObject:user];
			[self addUser:user];
		}
	}
	
	room.users = [users copy];
	
	GFCampfireRoom *existingRoom = [_rooms objectForKey:room.roomKey];
	if (existingRoom) {
		NSMutableSet *existingUserIds = [existingRoom.users valueForKey:@"userKey"];
		NSMutableSet *roomUserIds = [room.users valueForKey:@"userKey"];
		
		for (GFCampfireUser *user in existingRoom.users) {
			if ([room.users containsObject:user] == NO) {
				[departedUsers addObject:user];
			}
		}
		[existingRoom updateWithRoom:room];
	} else {
		[_rooms setObject:room forKey:room.roomKey];
	}
	
//	[serviceApplication plugInDidUpdateGroupList:<#(NSArray *)#> error:<#(NSError *)#>];
	
	if ([joinedUsers count] > 0) {
		NSArray *joinedHandles = [[joinedUsers valueForKey:@"userKey"] allObjects];
		[serviceApplication handles:joinedHandles didJoinChatRoom:room.roomKey];
	}
	
	if ([departedUsers count] > 0) {
		NSArray *departedHandles = [[departedUsers valueForKey:@"userKey"] allObjects];
		[serviceApplication handles:departedHandles didLeaveChatRoom:room.roomKey];
	}
}

- (void)getAllRooms
{
	MKNetworkOperation *roomListOperation = [self operationWithPath:@"rooms.json" params:nil httpMethod:@"GET"];
	[roomListOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		NSArray *allRooms = [GFCampfireRoom objectWithDictionary:json];
		
		for (GFCampfireRoom *room in allRooms) {
			[self addRoom:room];
		}
	} onError:^(NSError *error) {
		DDLogError(@"Error fetching rooms, %@", error);
	}];
	[self enqueueOperation:roomListOperation forceReload:YES];
}

- (void)getUserRooms
{
	MKNetworkOperation *usersRooms = [self operationWithPath:@"presence.json" params:nil httpMethod:@"GET"];
	[usersRooms onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		NSArray *usersRooms = [GFCampfireRoom objectWithDictionary:json];
		
		for (GFCampfireRoom *room in usersRooms) {
			[self addRoom:room];
//			[_activeRooms setObject:room forKey:room.roomKey];
//			[self updateInformationForRoom:room didJoin:YES];
//			NSAttributedString *inviteMessage = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Join %@?", room.name]];
//			IMServicePlugInMessage *message = [IMServicePlugInMessage servicePlugInMessageWithContent:inviteMessage];
//			[serviceApplication plugInDidReceiveInvitation:message forChatRoom:room.roomKey fromHandle:nil/*_consoleHandle*/];
		}
	} onError:^(NSError *error) {
		DDLogError(@"Error fetching users active rooms, %@", error);
	}];
	[self enqueueOperation:usersRooms forceReload:YES];
}

- (void)getRoom:(NSString *)roomId didJoin:(BOOL)didJoin
{
	MKNetworkOperation *roomOperation = [self operationWithPath:[NSString stringWithFormat:@"room/%@.json", roomId] params:nil httpMethod:@"GET"];
	[roomOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		GFCampfireRoom *room = [GFCampfireRoom objectWithDictionary:json];
		[self updateInformationForRoom:room didJoin:didJoin];
	} onError:^(NSError *error) {
		DDLogError(@"Error fetching room %@, %@", roomId, error);
	}];
	[self enqueueOperation:roomOperation forceReload:YES];
}

- (void)getRoomWithId:(NSString *)roomId
{
	MKNetworkOperation *roomOperation = [self operationWithPath:[NSString stringWithFormat:@"room/%@.json", roomId] params:nil httpMethod:@"GET"];
	[roomOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		GFCampfireRoom *room = [GFCampfireRoom objectWithDictionary:json];
	} onError:^(NSError *error) {
		DDLogError(@"Error fetching room %@, %@", roomId, error);
	}];
	[self enqueueOperation:roomOperation forceReload:YES];
}

- (void)didJoinRoom:(NSString *)roomId
{
	GFCampfireRoom *room = [_rooms objectForKey:roomId];
	if (room) {
		[_activeRooms addObject:room.roomKey];
		
		if ([_chatStreams objectForKey:roomId] == nil) {
			[self startStreamingRoom:roomId];
		}
		
		[self getRoom:roomId didJoin:YES];
		
		NSString *lastMessageKey = [self lastMessageIdForRoomId:roomId];
		[self getRecentMessagesForRoom:roomId sinceMessage:lastMessageKey];
		
		[serviceApplication plugInDidJoinChatRoom:roomId];
		[serviceApplication plugInDidReceiveNotice:room.topic forChatRoom:roomId];
	}
}


- (void)user:(NSString *)userId didJoinRoom:(NSString *)roomId
{
	
}

- (void)user:(NSString *)userId didLeaveRoom:(NSString *)roomId
{
	
}

- (void)getRecentMessagesForRoom:(NSString *)roomId sinceMessage:(NSString *)messageId
{
	NSMutableDictionary *params = nil;
	if (messageId) {
		params = [NSMutableDictionary dictionaryWithObject:messageId forKey:@"since_message_id"];
	}
	MKNetworkOperation *recentMessagesOperation = [self operationWithPath:[NSString stringWithFormat:@"room/%@/recent.json", roomId] params:params httpMethod:@"GET"];
	[recentMessagesOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		id json = [completedOperation responseJSON];
		NSArray *messages = [GFCampfireMessage objectWithDictionary:json];
		[self processHistoryMessages:messages];
	} onError:^(NSError *error) {
		// couldn't fetch recents, do I care?
		DDLogError(@"Error fetching recent messages for room %@ starting with message %@, %@", roomId, messageId, error);
	}];
	[self enqueueOperation:recentMessagesOperation forceReload:YES];
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
	/* Tweet Message Format:
	2012/03/16 16:51:56:476  Received Message: {"room_id":474752,"created_at":"2012/03/16 20:51:55 +0000","starred":"false","body":"--- \n:author_username: laurenleto\n:author_avatar_url: http://a0.twimg.com/profile_images/1857890926/Photo_on_2010-02-02_at_09.59__3_normal.jpg\n:message: \"RT @max_read: in case you missed it -- THAT FUCKIN GUY FROM THE KONY MOVIE GOT ARRESTED FOR TOUCHIN HIS DONG OUTSIDE SEA WORLD\"\n:id: 180755860962820097\n","id":524107769,"user_id":1115268,"type":"TweetMessage","tweet":{"author_avatar_url":"http://a0.twimg.com/profile_images/1857890926/Photo_on_2010-02-02_at_09.59__3_normal.jpg","author_username":"laurenleto","id":180755860962820097,"message":"RT @max_read: in case you missed it -- THAT FUCKIN GUY FROM THE KONY MOVIE GOT ARRESTED FOR TOUCHIN HIS DONG OUTSIDE SEA WORLD"}}
	*/
	if (message.roomId != NSNotFound) {
		NSString *roomId = [[NSNumber numberWithInteger:message.roomId] stringValue];
		NSString *userId = nil;
		if (message.userId != NSNotFound) {
			userId = [[NSNumber numberWithInteger:message.userId] stringValue];
			
			if (message.type == GFCampfireMessageTypeLeave || message.type == GFCampfireMessageTypeKick) {
				if (isHistoryMessage == NO) {
					[serviceApplication handles:[NSArray arrayWithObject:userId] didLeaveChatRoom:roomId];
				}
			} else if (message.type == GFCampfireMessageTypeEnter) {
				if (isHistoryMessage == NO) {
					[serviceApplication handles:[NSArray arrayWithObject:userId] didJoinChatRoom:roomId];
				}
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
			} else if (message.type == GFCampfireMessageTypeUpload) {
				[self processUploadMessage:message];
			}
		}
		
		[self setLastMessageId:message.messageKey forRoomId:roomId];
	}
}

- (void)processUploadMessage:(GFCampfireMessage *)message
{
	//	NSCachesDirectory
	
	NSString *path = [NSString stringWithFormat:@"room/%d/messages/%d/upload.json", message.roomId, message.messageId];
	MKNetworkOperation *uploadMessageOperation = [self operationWithPath:path params:nil httpMethod:@"GET"];
	[uploadMessageOperation onCompletion:^(MKNetworkOperation *completedOperation) {
		
	} onError:^(NSError *error) {
		
	}];
	//	NSURL *fileURL = [NSURL fileURLWithPath:<#(NSString *)#>];
	//	NSOutputStream *fileOutputStream = [NSOutputStream outputStreamWithURL:fileURL append:<#(BOOL)#>];
	//	[uploadMessageOperation addDownloadStream:fileOutputStream];
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
			[self addUser:user];
		}
	}
	
	[self updateAllUsersInformation];
}

- (void)setRoom:(NSString *)roomId topic:(NSString *)topic
{
	NSDictionary *params = [NSDictionary dictionaryWithObject:topic forKey:@"topic"];
	[self updateRoomWithId:roomId attributes:params];
}

- (void)setRoom:(NSString *)roomId name:(NSString *)name
{
	NSDictionary *params = [NSDictionary dictionaryWithObject:name forKey:@"name"];
	[self updateRoomWithId:roomId attributes:params];
}

- (void)updateRoomWithId:(NSString *)roomId attributes:(NSDictionary *)attributes
{
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:attributes];
	MKNetworkOperation *changeTopicOperation = [self operationWithPath:[NSString stringWithFormat:@"room/%@.json", roomId] params:params httpMethod:@"PUT"];
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
		MKNetworkOperation *lockOperation = [self operationWithPath:[NSString stringWithFormat:@"room/%@/lock.json", roomId]
															 params:nil
														 httpMethod:@"POST"];
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
		MKNetworkOperation *unlockOperation = [self operationWithPath:[NSString stringWithFormat:@"room/%@/unlock.json", roomId]
															   params:nil
														   httpMethod:@"POST"];
		[unlockOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			room.locked = NO;
		} onError:^(NSError *error) {
			
		}];
	}
}

- (void)updateAllUsersInformation
{
	for (GFCampfireUser *user in _users.objectEnumerator) {
		[self updateInformationForUserId:user.userKey];
	}
}

- (void)updateInformationForUserId:(NSString *)userKey
{
	GFCampfireUser *user = [_users objectForKey:userKey];
	if (user) {
		[self sendPropertiesOfHandle:userKey];
	} else if ([userKey isEqualToString:_consoleHandle]) {
		[self sendPropertiesOfHandle:_consoleHandle];
	}
}

- (void)getRemoteUserInfo:(NSString *)userId
{
	if ([_users objectForKey:userId] == nil) {
		MKNetworkOperation *getUserOperation = [self operationWithPath:[NSString stringWithFormat:@"users/%@.json", userId] params:nil httpMethod:@"GET"];
		[getUserOperation onCompletion:^(MKNetworkOperation *completedOperation) {
			id json = [completedOperation responseJSON];
			GFCampfireUser *user = [GFCampfireUser objectWithDictionary:json];
			[self addUser:user];
		} onError:^(NSError *error) {
			// couldn't fetch user, do I care?
			DDLogError(@"Error fetching info for user %@, %@", userId, error);
		}];
		[self enqueueOperation:getUserOperation forceReload:YES];
	} else {
		[self updateInformationForUserId:userId];
	}
}

- (void)startStreamingRoom:(NSString *)roomId
{
	NSString *host = @"streaming.campfirenow.com";
	
	__strong GCDAsyncSocket *asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	[_chatStreams setObject:asyncSocket forKey:roomId];
	
	uint16_t port = _useSSL ? 443 : 80;
	
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
	GCDAsyncSocket *asyncSocket = [_chatStreams objectForKey:roomId];
	if (asyncSocket) {
		[asyncSocket disconnect];
	}
	[_chatStreams removeObjectForKey:roomId];
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

enum {
	GFCampfireRoomStreamHeaderTag,
	GFCampfireRoomStreamMessageTag,
};

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
		
		[socket writeData:(__bridge NSData *)requestData withTimeout:-1.0 tag:GFCampfireRoomStreamHeaderTag];
		
		NSData *responseTerminatorData = [@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
		[socket readDataToData:responseTerminatorData withTimeout:-1.0 tag:GFCampfireRoomStreamHeaderTag];
	}
}

- (void)socketStream:(__unsafe_unretained GCDAsyncSocket *)socket receivedHeader:(CFHTTPMessageRef)header forRoomId:(NSString *)roomId
{
	if (header) {
		// check validity of the header and if all is good continue reading stream
		CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(header);
		if (statusCode >= 200 && statusCode < 300) {
			// TODO: this is where I should fetch all history messages
			[self readNextMessageFromStreamingSocket:socket];
		}
		// XXX: what to do if failure here?
		// saw a 401 Unauthorized in logs
	}
}

- (void)processHeader:(NSString *)header forSocketStream:(__unsafe_unretained GCDAsyncSocket *)socket
{
	__block CFHTTPMessageRef response = NULL;
	
	if ([header hasSuffix:@"\r\n\r\n"]) {
		NSString *httpHeader = [header substringToIndex:([header length] - 4)];
		NSArray *httpHeaderParts = [httpHeader componentsSeparatedByString:@"\r\n"];
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
	
	[self socketStream:socket receivedHeader:response forRoomId:[self roomIdForSocket:socket]];
}

- (void)processMessage:(NSString *)message forSocketStream:(__unsafe_unretained GCDAsyncSocket *)socket
{
	NSString *stringData = [message substringWithRange:NSMakeRange(0, [message length] - 2)];
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
	
	[self readNextMessageFromStreamingSocket:socket];
}

- (void)readNextMessageFromStreamingSocket:(__unsafe_unretained GCDAsyncSocket *)socket
{
	// XXX: CRLF could be problematic if someone sends/pastes a \r\n in the body or whatnot of their message
	[socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:10.0 tag:GFCampfireRoomStreamMessageTag];
}

- (void)socket:(__unsafe_unretained GCDAsyncSocket *)socket didReadData:(__unsafe_unretained NSData *)data withTag:(long)tag
{
	NSString *roomId = [self roomIdForSocket:socket];
	NSString *stringDataWithCRLF = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (tag == GFCampfireRoomStreamHeaderTag) {
		DDLogInfo(@"Received header for streaming room %@ - %@", roomId, stringDataWithCRLF);
		[self processHeader:stringDataWithCRLF forSocketStream:socket];
	} else if (tag == GFCampfireRoomStreamMessageTag) {
		[self processMessage:stringDataWithCRLF forSocketStream:socket];
	}
}

- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
	// need to attempt to re-establish connection
	return 0.0;
}

- (void)socketDidDisconnect:(__unsafe_unretained GCDAsyncSocket *)sock withError:(__unsafe_unretained NSError *)err
{
	NSString *roomId = [self roomIdForSocket:sock];
	DDLogWarn(@"Socket for room %@ disconnected with error: %@", roomId, err);
	if (roomId) {
		BOOL reconnecting = NO;
		if (self.reachable) {
			NSString *errorDomain = [err domain];
			NSInteger errorCode = [err code];
			if ([errorDomain isEqualToString:GCDAsyncSocketErrorDomain]) {
				if (errorCode == GCDAsyncSocketReadTimeoutError || errorCode == GCDAsyncSocketClosedError) {
					[self startStreamingRoom:roomId];
					reconnecting = YES;
				}
			} else if ([errorDomain isEqualToString:@"kCFStreamErrorDomainSSL"] && errorCode == errSSLClosedGraceful) {
				[self startStreamingRoom:roomId];
				reconnecting = YES;
			} else if ([errorDomain isEqualToString:NSPOSIXErrorDomain] && errorCode == ETIMEDOUT) {
				// Operation Timed Out
				[self startStreamingRoom:roomId];
				reconnecting = YES;
			}
			
			//Socket for room 474752 disconnected with error: Error Domain=GCDAsyncSocketErrorDomain Code=7 "Socket closed by remote peer" UserInfo=0x7f8c60d59d40 {NSLocalizedDescription=Socket closed by remote peer}
		}
		
		if (!reconnecting) {
			[serviceApplication plugInDidLeaveChatRoom:roomId error:err];
		}	
	}
}

- (NSString *)roomIdForSocket:(__unsafe_unretained GCDAsyncSocket *)socket
{
	NSString *roomId = [[_chatStreams allKeysForObject:socket] lastObject];
	return roomId;
}

#pragma mark -
#pragma mark Caching

- (NSURL *)cachePathForRoom:(NSString *)roomId
{
	NSString *appName = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	NSString *cacheDirectory = [basePath stringByAppendingPathComponent:appName];
	NSString *roomCacheDirectory = [[cacheDirectory stringByAppendingPathComponent:@"rooms"] stringByAppendingPathComponent:roomId];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDir = NO;
	BOOL fileExists = [fileManager fileExistsAtPath:roomCacheDirectory isDirectory:&isDir];
	
	NSURL *roomCacheDirectoryURL = [NSURL fileURLWithPath:roomCacheDirectory isDirectory:YES];
	if (fileExists == NO || isDir == NO) {
		NSError *error = nil;
		BOOL created = [fileManager createDirectoryAtURL:roomCacheDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
		if (created == NO && error != nil) {
			roomCacheDirectoryURL = nil;
			DDLogError(@"Error: failed to create cache directory for room %@. %@", roomId, error);
		}
	}
	
	return roomCacheDirectoryURL;
}

- (NSURL *)roomDataURLForRoomId:(NSString *)roomId
{
	NSURL *roomURL = [self cachePathForRoom:roomId];
	NSURL *fileURL = [roomURL URLByAppendingPathComponent:@"RoomData.plist"];
	return fileURL;
}

- (void)saveDataForRoomId:(NSString *)roomId
{
	NSMutableDictionary *roomData = [self roomDataForRoomId:roomId];
	NSURL *fileURL = [self roomDataURLForRoomId:roomId];
	
	if ([roomData writeToURL:fileURL atomically:YES] == NO) {
		DDLogError(@"Error attempting to save data for room %@.", roomId);
	}
}

- (NSMutableDictionary *)roomDataForRoomId:(NSString *)roomId
{
	NSMutableDictionary *roomData = [_roomData objectForKey:roomId];
	if (roomData == nil) {
		NSURL *fileURL = [self roomDataURLForRoomId:roomId];
		NSDictionary *existingRoomData = [NSDictionary dictionaryWithContentsOfURL:fileURL];
		if (existingRoomData) {
			roomData = [[NSMutableDictionary alloc] initWithDictionary:existingRoomData];
		} else {
			roomData = [[NSMutableDictionary alloc] init];
		}
		[_roomData setObject:roomData forKey:roomId];
	}
	
	return roomData;
}

- (NSString *)lastMessageIdForRoomId:(NSString *)roomId
{
	NSString *messageId = nil;
	
	NSMutableDictionary *roomData = [self roomDataForRoomId:roomId];
	messageId = [roomData objectForKey:kGFCampfireRoomLastMessage];
	
	return messageId;
}

- (void)setLastMessageId:(NSString *)lastMessageId forRoomId:(NSString *)roomId
{
	NSMutableDictionary *roomData = [self roomDataForRoomId:roomId];
	[roomData setObject:lastMessageId forKey:kGFCampfireRoomLastMessage];
	[self saveDataForRoomId:roomId];
}

#pragma mark -
#pragma mark Command Actions

- (void)addCommands
{
	_commands = [[NSMutableDictionary alloc] init];
	
	GFCampfireAddBlockCommand(_commands, @"ping", @"Pings the console", ^(NSString *args) {
		NSString *pongString = @"pong!";
		NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:pongString
																			   attributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
																													  forKey:IMAttributeItalic]];
		IMServicePlugInMessage *message = [IMServicePlugInMessage servicePlugInMessageWithContent:attributedString];
		if ([_rooms objectForKey:args]) {
			[serviceApplication plugInDidReceiveMessage:message forChatRoom:args fromHandle:_consoleHandle];
		} else {
			[serviceApplication plugInDidReceiveMessage:message fromHandle:_consoleHandle];	
		}
	});
	
	GFCampfireAddBlockCommand(_commands, @"list", @"List the available rooms", ^(NSString *args) {
		IMServicePlugInMessage *message = [self roomList];
		[serviceApplication plugInDidReceiveMessage:message fromHandle:_consoleHandle];
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
			[self setRoom:roomId topic:topic];
		} else {
			
		}
	});
	
	GFCampfireAddBlockCommand(_commands, @"name", @"Gets or sets the name of the room", ^(NSString *args) {
		NSRange spaceRange = [args rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
		NSString *roomId = [args substringToIndex:spaceRange.location];
		NSString *name = [args substringFromIndex:NSMaxRange(spaceRange)];
		if ([name length] > 0) {
			[self setRoom:roomId name:name];
		} else {
			
		}
	});
	
	GFCampfireAddBlockCommand(_commands, @"info", @"Displays information about the plugin", ^(NSString *args) {
		IMServicePlugInMessage *message = [self infoMessage];
		[serviceApplication plugInDidReceiveMessage:message fromHandle:_consoleHandle];
	});
	
	GFCampfireAddBlockCommand(_commands, @"settings", @"Displays all settings or a single setting when key is supplied, sets the value of a setting (key=value)", ^(NSString *args) {
		if ([args length] == 0) {
			// all settings
		} else {
			NSArray *kvPair = [args componentsSeparatedByString:@"="];
			if ([kvPair count] == 1) {
				// getter
			} else if ([kvPair count] == 2) {
				//setter
			} else {
				// invalid
			}
		}
	});
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

#pragma mark -
#pragma mark Action Messages

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

@end
