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
	if ([method isEqualToString:@"POST"] || [method isEqualToString:@"PUT"]) {
		self.postDataEncoding = MKNKPostDataEncodingTypeJSON;
		// stupid workaround for MKNetworkKit not doing PUT/POST operations with no params
		if (params == nil || [params count] == 0) {
			params = [NSMutableDictionary dictionaryWithObject:@"" forKey:@""];
		}
	}
	self = [super initWithURLString:aURLString params:params httpMethod:method];
	
	// hack to remove all the accept languages
	NSMutableURLRequest *theRequest = [self valueForKey:@"request"];
	[theRequest setValue:nil forHTTPHeaderField:@"Accept-Language"];
	
	return self;
}

@end
