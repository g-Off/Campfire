//
//  GFCampfireMessage.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-05.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GFJSONObject.h"

typedef enum {
	GFCampfireMessageTypeUnknown = -1,
	GFCampfireMessageTypeText,
	GFCampfireMessageTypePaste,
	GFCampfireMessageTypeSound,
	GFCampfireMessageTypeAdvertisement,
	GFCampfireMessageTypeAllowGuests,
	GFCampfireMessageTypeDisallowGuests,
	GFCampfireMessageTypeIdle,
	GFCampfireMessageTypeKick,
	GFCampfireMessageTypeLeave,
	GFCampfireMessageTypeEnter,
	GFCampfireMessageTypeSystem,
	GFCampfireMessageTypeTimestamp,
	GFCampfireMessageTypeTopicChange,
	GFCampfireMessageTypeUnidle,
	GFCampfireMessageTypeUnlock,
	GFCampfireMessageTypeUpload,
} GFCampfireMessageType;

@class GFCampfireTweet;

@interface GFCampfireMessage : GFJSONObject

@property (assign) NSInteger messageId;
@property (assign) NSInteger roomId;
@property (assign) NSInteger userId;
@property (strong) NSString *body;
@property (strong) NSDate *createdAt;
@property (assign) GFCampfireMessageType type;
@property (assign, getter = isStarred) BOOL starred;
@property (strong) GFCampfireTweet *tweet;

- (void)updateWithMessage:(GFCampfireMessage *)message;

- (NSString *)messageKey;

@end

@interface GFCampfireMessageTypeValueTransformer : NSValueTransformer

@end
