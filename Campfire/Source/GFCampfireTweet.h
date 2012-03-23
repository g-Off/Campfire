//
//  GFCampfireTweet.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-03-16.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFJSONObject.h"

@interface GFCampfireTweet : GFJSONObject

@property (strong) NSURL *authorAvatarURL;
@property (strong) NSString *authorUsername;
@property (assign) NSUInteger tweetId;
@property (strong) NSString *message;

@end
