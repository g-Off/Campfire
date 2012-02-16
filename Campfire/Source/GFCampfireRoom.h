//
//  GFCampfireRoom.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GFJSONObject.h"

@interface GFCampfireRoom : GFJSONObject

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
@property (assign, getter = isLocked) BOOL locked;

- (void)updateWithRoom:(GFCampfireRoom *)room;

@end
