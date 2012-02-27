//
//  GFJSONURLValueTransformer.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-26.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFJSONURLValueTransformer.h"

@implementation GFJSONURLValueTransformer

+ (Class)transformedValueClass
{
	return [NSURL class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (id)transformedValue:(id)value
{
	NSURL *transformedValue = nil;
	if ([value isKindOfClass:[NSString class]]) {
		transformedValue = [NSURL URLWithString:(NSString *)value];
	}
	
	return transformedValue;
}

- (id)reverseTransformedValue:(id)value
{
	NSString *transformedValue = nil;
	if ([value isKindOfClass:[NSURL class]]) {
		transformedValue = [(NSURL *)value absoluteString];
	}
	
	return transformedValue;
}

@end
