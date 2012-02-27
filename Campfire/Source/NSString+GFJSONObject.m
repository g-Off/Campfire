//
//  NSString+GFJSONObject.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-26.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "NSString+GFJSONObject.h"

@implementation NSString (GFJSONObject)

- (id)jsonObject:(NSError **)error
{
	NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
	return [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
}

@end
