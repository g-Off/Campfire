//
//  GFCampfireBOOLValueTransformer.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-03-19.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireBOOLValueTransformer.h"

@implementation GFCampfireBOOLValueTransformer

+ (Class)transformedValueClass
{
	return [NSNumber class];
}

+ (BOOL)allowsReverseTransformation
{
	return NO;
}

- (id)transformedValue:(id)value
{
	NSNumber *transformedValue = nil;
	if ([value isKindOfClass:[NSString class]]) {
		BOOL boolValue = NO;
		if ([(NSString *)value isEqualToString:@"true"]) {
			boolValue = YES;
		}
		transformedValue = [NSNumber numberWithBool:boolValue];
	} else if ([value isKindOfClass:[NSNumber class]]) {
		transformedValue = value;
	}
	
	return transformedValue;
}

@end
