//
//  GFCampfireRoom.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
<room>
	<id type="integer">1</id>
	<name>North May St.</name>
	<topic>37signals HQ</topic>
	<membership-limit type="integer">60</membership-limit>
	<full type="boolean">false</full>
	<open-to-guests type="boolean">true</open-to-guests>
	<active-token-value>#{ 4c8fb -- requires open-to-guests is true}</active-token-value>
	<updated-at type="datetime">2009-11-17T19:41:38Z</updated-at>
	<created-at type="datetime">2009-11-17T19:41:38Z</created-at>
	<users type="array">
		...
	</users>
</room>
*/

@interface GFCampfireRoom : NSObject

@property (assign) NSInteger roomId;
@property (strong) NSString *name;
@property (strong) NSString *topic;
@property (assign) NSInteger membershipLimit;
@property (assign, getter = isFull) BOOL full;
@property (assign, getter = isOpenToGuests) BOOL openToGuests;
@property (strong) NSString *activeTokenValue;
@property (strong) NSDate *updatedAt;
@property (strong) NSDate *createdAt;
@property (strong) NSArray *users;

@end
