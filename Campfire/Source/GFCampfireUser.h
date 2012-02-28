//
//  GFCampfireUser.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GFJSONObject.h"

typedef enum {
	GFCampfireUserTypeMember,
	GFCampfireUserTypeGuest,
} GFCampfireUserType;

@interface GFCampfireUser : GFJSONObject

@property (strong) NSString *name;
@property (strong) NSString *emailAddress;
@property (assign, getter = isAdmin) BOOL admin;
@property (strong) NSDate *createdAt;
@property (assign) GFCampfireUserType *type;
@property (strong) NSURL *avatarURL;
@property (strong) NSData *avatarData;
@property (assign) NSInteger userId;
@property (strong) NSString *apiAuthToken;

- (void)updateWithUser:(GFCampfireUser *)user;

- (NSString *)userKey;
- (NSString *)avatarKey;

@end
