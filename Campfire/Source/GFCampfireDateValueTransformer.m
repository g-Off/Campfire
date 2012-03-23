//
//  GFCampfireDateValueTransformer.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-03-22.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireDateValueTransformer.h"

@implementation GFCampfireDateValueTransformer {
	NSDateFormatter *_dateFormatter;
}

+ (Class)transformedValueClass
{
	return [NSDate class];
}

+ (BOOL)allowsReverseTransformation
{
	return NO;
}

- (id)init
{
	if ((self = [super init])) {
		_dateFormatter = [[NSDateFormatter alloc] init];
		[_dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss Z"];
	}
	
	return self;
}

- (id)transformedValue:(id)value
{
	NSDate *transformedValue = nil;
	if ([value isKindOfClass:[NSString class]]) {
		transformedValue = [_dateFormatter dateFromString:value];
	}
	
	return transformedValue;
}

@end
