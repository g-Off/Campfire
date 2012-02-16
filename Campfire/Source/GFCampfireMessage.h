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
	GFCampfireMessageTypeSystem,
	GFCampfireMessageTypeTimestamp,
	GFCampfireMessageTypeTopicChange,
	GFCampfireMessageTypeUnidle,
	GFCampfireMessageTypeUnlock,
	GFCampfireMessageTypeUpload,
} GFCampfireMessageType;

/*
<message>
	<id type="integer">1</id>
	<room-id type="integer">1</room-id>
	<user-id type="integer">2</user-id>
	<body>Hello Room</body>
	<created-at type="datetime">2009-11-22T23:46:58Z</created-at>
	<type>#{TextMessage || PasteMessage || SoundMessage || AdvertisementMessage ||
		AllowGuestsMessage || DisallowGuestsMessage || IdleMessage || KickMessage ||
		LeaveMessage || SystemMessage || TimestampMessage || TopicChangeMessage ||
		UnidleMessage || UnlockMessage || UploadMessage}</type>
	<starred>true</starred>
</message>
*/

@interface GFCampfireMessage : GFJSONObject

@property (assign) NSInteger messageId;
@property (assign) NSInteger roomId;
@property (assign) NSInteger userId;
@property (strong) NSString *body;
@property (strong) NSDate *createdAt;
@property (assign) GFCampfireMessageType type;
@property (assign, getter = isStarred) BOOL starred;

- (void)updateWithMessage:(GFCampfireMessage *)message;

@end
