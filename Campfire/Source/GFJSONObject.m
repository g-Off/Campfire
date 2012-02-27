//
//  GFJSONObject.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-11.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFJSONObject.h"

#import <objc/runtime.h>

@interface GFJSONObject ()

+ (Class)classForType:(NSString *)type;
+ (NSMutableSet *)registeredClassPrefixes;

@end

@implementation GFJSONObject

+ (NSDictionary *)jsonMapping
{
	return nil;
}

+ (NSDictionary *)valueTransformers
{
	return nil;
}

+ (Class)classForType:(NSString *)type
{
	Class cls = Nil;
	for (NSString *prefix in [self registeredClassPrefixes]) {
		NSString *noPrefixName = [[[type substringToIndex:1] uppercaseString] stringByAppendingString:[type substringFromIndex:1]];
		
		NSString *potentialClassName = [NSString stringWithFormat:@"%@%@", prefix, noPrefixName];
		Class potentialClass = NSClassFromString(potentialClassName);
		if (potentialClass != Nil && [potentialClass isSubclassOfClass:self]) {
			cls = potentialClass;
			break;
		}
	}
	
	if (cls == Nil && [type hasSuffix:@"s"]) {
		NSString *nonPluralType = [type substringToIndex:([type length] - 1)];
		cls = [self classForType:nonPluralType];
	}
	
	return cls;
}

+ (NSMutableSet *)registeredClassPrefixes
{
	static NSMutableSet *prefixes = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		prefixes = [[NSMutableSet alloc] init];
	});
	
	return prefixes;
}

+ (void)registerClassPrefix:(NSString *)prefix
{
	[[self registeredClassPrefixes] addObject:prefix];
}

+ (id)objectWithDictionary:(NSDictionary *)dict
{
	__block id returnObj = nil;
	[dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if ([key isKindOfClass:[NSString class]]) {
			NSString *keyString = key;
			Class objectClass = [self classForType:keyString];
			
			if ([obj isKindOfClass:[NSArray class]]) {
				NSArray *objArray = obj;
				NSMutableArray *objects = [NSMutableArray arrayWithCapacity:[objArray count]];
				for (id jsonObj in objArray) {
					if ([jsonObj isKindOfClass:[NSDictionary class]]) {
						NSDictionary *objectDict = jsonObj;
						[objects addObject:[[objectClass alloc] initWithDictionary:objectDict]];
					}
				}
				
				returnObj = objects;
			} else if ([obj isKindOfClass:[NSDictionary class]]) {
				NSDictionary *objectDict = obj;
				returnObj = [[objectClass alloc] initWithDictionary:objectDict];
			}
		}
	}];
	
	return returnObj;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
	if ((self = [super init])) {
		[self updateWithDictionary:dict];
	}
	
	return self;
}

- (void)updateWithDictionary:(NSDictionary *)dict
{
	NSDictionary *nameMapping = [[self class] jsonMapping];
	NSDictionary *valueTransformers = [[self class] valueTransformers];
	[dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
		NSString *jsonKey = key;
		NSString *propertyName = [[nameMapping allKeysForObject:jsonKey] lastObject];
		if (propertyName) {		
			if ([obj isEqual:[NSNull null]]) {
				obj = nil;
			}
			
			NSString *transformerName = [valueTransformers objectForKey:propertyName];
			if (transformerName) {
				NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:transformerName];
				if (transformer) {
					obj = [transformer transformedValue:obj];
				}
			}
			[self setValue:obj forKey:propertyName];
		}
	}];
}

- (id)JSONRepresentation
{
	return nil;
}

@end
