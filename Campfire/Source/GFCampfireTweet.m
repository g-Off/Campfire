//
//  GFCampfireTweet.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-03-16.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireTweet.h"

@implementation GFCampfireTweet

/*
{
	"tweet": {
		"author_avatar_url": "http://a0.twimg.com/profile_images/1857890926/Photo_on_2010-02-02_at_09.59__3_normal.jpg",
		"author_username": "laurenleto",
		"id": 180755860962820097,
		"message": "RT @max_read: in case you missed it -- THAT FUCKIN GUY FROM THE KONY MOVIE GOT ARRESTED FOR TOUCHIN HIS DONG OUTSIDE SEA WORLD",
	},
}
*/

@synthesize authorAvatarURL;
@synthesize authorUsername;
@synthesize tweetId;
@synthesize message;

+ (NSDictionary *)jsonMapping
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"author_avatar_url", @"authorAvatarURL",
			@"author_username", @"authorUsername",
			@"id", @"tweetId",
			@"message", @"message",
			nil];
}

+ (NSDictionary *)valueTransformers
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"GFJSONURLValueTransformer", @"authorAvatarURL",
			nil];
}

@end
