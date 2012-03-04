//
//  GFCampfireUpload.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-05.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireUpload.h"

@implementation GFCampfireUpload

@synthesize uploadId;
@synthesize name;
@synthesize roomId;
@synthesize userId;
@synthesize byteSize;
@synthesize contentType;
@synthesize fullURL;
@synthesize createdAt;

/*
{
	"upload": {
		"byte_size": 71361,
		"content_type": "image/jpeg",
		"created_at": "2012/03/01 19:57:39 +0000",
		"full_url": "https://jadedpixel.campfirenow.com/room/474752/uploads/2872718/monster-in-a-hot-tub.jpeg",
		"id": 2872718,
		"name": "monster-in-a-hot-tub.jpeg",
		"room_id": 474752,
		"user_id": 1116685,
	},
}
*/

+ (NSDictionary *)jsonMapping
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"byte_size", @"byteSize",
			@"content_type", @"contentType",
			@"created_at", @"createdAt",
			@"full_url", @"fullURL",
			@"id", @"uploadId",
			@"name", @"name",
			@"room_id", @"roomId",
			@"user_id", @"userId",
			nil];
}

+ (NSDictionary *)valueTransformers
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			@"GFJSONURLValueTransformer", @"fullURL",
			nil];
}

@end
