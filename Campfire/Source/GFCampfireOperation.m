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
	if (([method isEqualToString:@"POST"] || [method isEqualToString:@"PUT"]) && (params == nil || [params count] == 0)) {
		self.postDataEncoding = MKNKPostDataEncodingTypeJSON;
		// stupid workaround for MKNetworkKit not doing PUT/POST operations with no params
		params = [NSMutableDictionary dictionaryWithObject:@"" forKey:@""];
	}
	self = [super initWithURLString:aURLString params:params httpMethod:method];
	return self;
}

@end
