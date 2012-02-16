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

+ (NSString *)propertyNameForKey:(NSString *)key
{
	unsigned int propertyCount = 0;
	objc_property_t *properties = class_copyPropertyList(self, &propertyCount);
	
	for (unsigned int i = 0; i < propertyCount; ++i) {
		objc_property_t property = properties[i];
		const char *propertyName = property_getName(property);
		
		//class_getProperty(self, name)
		
		
	}
	
	if ([key isEqualToString:@"id"]) {
		__block NSString *idPrefix = nil;
		[[self registeredClassPrefixes] enumerateObjectsUsingBlock:^(NSString *classPrefix, BOOL *stop) {
			if ([NSStringFromClass(self) hasPrefix:classPrefix]) {
				idPrefix = [NSStringFromClass(self) substringFromIndex:[classPrefix length]];
				*stop = YES;
			}
		}];
		
		if (idPrefix) {
			[idPrefix stringByAppendingString:@"Id"];
			[idPrefix stringByAppendingString:@"ID"];
			[idPrefix stringByAppendingString:@"Identifier"];
		}
	} else {
		NSCharacterSet *seperatorCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"-_"];
		NSArray *components = [key componentsSeparatedByCharactersInSet:seperatorCharacterSet];
		if ([components count] > 1) {
			NSMutableString *combinedKey = [NSMutableString stringWithCapacity:[key length]];
			[components enumerateObjectsUsingBlock:^(NSString *keyComponent, NSUInteger idx, BOOL *stop) {
				if (idx > 0) {
					[combinedKey appendString:keyComponent];
				} else {
					[combinedKey appendString:[[keyComponent substringToIndex:1] uppercaseString]];
					[combinedKey appendString:[keyComponent substringFromIndex:1]];
				}
			}];
		} else {
			
		}
	}
	
//	objc_property_t property = class_getProperty(self, <#const char *name#>)
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
	[dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
		
	}];
}

@end
