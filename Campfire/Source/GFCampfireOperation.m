//
//  GFCampfireOperation.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-16.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireOperation.h"

@implementation GFCampfireOperation

- (id)initWithURLString:(NSString *)aURLString
                 params:(NSMutableDictionary *)params
             httpMethod:(NSString *)method
{
	self.postDataEncoding = MKNKPostDataEncodingTypeJSON;
	self = [super initWithURLString:aURLString params:params httpMethod:method];
	return self;
}

@end
