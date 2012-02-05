//
//  GFCampfireUser.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	GFCampfireUserTypeMember,
	GFCampfireUserTypeGuest,
} GFCampfireUserType;

/*
 <user>
	 <id type="integer">1</id>
	 <name>Jason Fried</name>
	 <email-address>jason@37signals.com</email-address>
	 <admin type="boolean">true</admin>
	 <created-at type="datetime">2009-11-20T16:41:39Z</created-at>
	 <type>Member</type>
	 <avatar-url>https://asset0.37img.com/global/.../avatar.png</avatar-url>
 </user>
*/

@interface GFCampfireUser : NSObject

@property (strong) NSString *name;
@property (strong) NSString *emailAddress;
@property (assign, getter = isAdmin) BOOL admin;
@property (strong) NSDate *createdAt;
@property (assign) GFCampfireUserType *type;
@property (strong) NSURL *avatar;
@property (assign) NSInteger userId;
@property (strong) NSString *apiAuthToken;

@end
