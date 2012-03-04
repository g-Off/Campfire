//
//  GFCampfireService.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GFCampfireRoom, GFCampfireUser;
@class MKNetworkEngine;

@protocol GFCampfireServiceDelegate;

@interface GFCampfireService : NSObject

@property (readonly) NSMutableDictionary *rooms;
@property (readonly) NSMutableDictionary *activeRooms;
@property (readonly) NSMutableDictionary *users;
@property (readonly) NSMutableDictionary *avatars;
@property (readonly) NSMutableDictionary *chats;
@property (readonly) NSMutableDictionary *commands;
@property (readonly) NSMutableDictionary *roomCommands;

@property (readonly) MKNetworkEngine *networkEngine;

@property (copy) NSString *username;
@property (copy) NSString *password;
@property (copy) NSString *server;
@property (assign) BOOL useSSL;

@property (readonly) GFCampfireUser *me;

@property (assign) id <GFCampfireServiceDelegate> delegate;

- (void)login;
- (void)logout;

- (void)joinRoom:(NSString *)roomId;

@end

@protocol GFCampfireServiceDelegate <NSObject>

@optional
- (void)serviceDidLogin:(GFCampfireService *)service;
- (void)serviceDidFailLogin:(GFCampfireService *)service error:(NSError *)error;
- (void)serviceDidLogout:(GFCampfireService *)service;

- (void)service:(GFCampfireService *)service didJoinRoom:(NSString *)roomId;
- (void)service:(GFCampfireService *)service didLeaveRoom:(NSString *)roomId error:(NSError *)error;

@end