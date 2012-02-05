//
//  GFCampfireUpload.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-05.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
<upload>
	<id type="integer">1</id>
	<name>picture.jpg</name>
	<room-id type="integer">1</room-id>
	<user-id type="integer">1</user-id>
	<byte-size type="integer">10063</byte-size>
	<content-type>image/jpeg</content-type>
	<full-url>https://account.campfirenow.com/room/1/uploads/1/picture.jpg</full-url>
	<created-at type="datetime">2009-11-20T23:25:14Z</created-at>
</upload>
 */

@interface GFCampfireUpload : NSObject

@property (assign) NSInteger uploadId;
@property (strong) NSString *name;
@property (assign) NSInteger roomId;
@property (assign) NSInteger userId;
@property (assign) NSInteger byteSize;
@property (strong) NSString *contentType;
@property (strong) NSURL *fullURL;
@property (strong) NSDate *createdAt;

@end
