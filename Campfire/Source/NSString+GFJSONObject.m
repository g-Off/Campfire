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

- (NSArray *)jsonStrings
{
	NSUInteger rootJSONIndex = 0;
	BOOL inRootJSON = NO;
	NSUInteger braceCount = 0;
	NSMutableArray *jsonStrings = [NSMutableArray array];
	for (NSUInteger i = 0; i < [self length]; ++i) {
		unichar c = [self characterAtIndex:i];
		if (c == '{') {
			if (inRootJSON == NO) {
				rootJSONIndex = i;
			}
			inRootJSON = YES;
			++braceCount;
		} else if (c == '}') {
			--braceCount;
		}
		
		if (braceCount == 0 && inRootJSON) {
			inRootJSON = NO;
			NSString *jsonString = [self substringWithRange:NSMakeRange(rootJSONIndex, i - rootJSONIndex + 1)];
			[jsonStrings addObject:jsonString];
		}
	}
	
	return [jsonStrings copy];
}

@end
