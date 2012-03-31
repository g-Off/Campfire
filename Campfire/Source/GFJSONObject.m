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

+ (NSDictionary *)jsonProperties
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

+ (id)newObjectOfClass:(Class)cls fromObject:(id)obj
{
	id returnObj = nil;
	
	if ([obj isKindOfClass:[NSArray class]]) {
		NSArray *objArray = obj;
		NSMutableArray *objects = [NSMutableArray arrayWithCapacity:[objArray count]];
		for (id jsonObj in objArray) {
			if ([jsonObj isKindOfClass:[NSDictionary class]]) {
				NSDictionary *objectDict = jsonObj;
				[objects addObject:[[cls alloc] initWithDictionary:objectDict]];
			}
		}
		
		returnObj = objects;
	} else if ([obj isKindOfClass:[NSDictionary class]]) {
		NSDictionary *objectDict = obj;
		returnObj = [[cls alloc] initWithDictionary:objectDict];
	}
	
	return returnObj;
}

+ (id)autoObjectWithDictionary:(NSDictionary *)dict
{
	__block id returnObj = nil;
	[dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if ([key isKindOfClass:[NSString class]]) {
			NSString *keyString = key;
			Class objectClass = [self classForType:keyString];
			returnObj = [self newObjectOfClass:objectClass fromObject:obj];
		}
	}];
	
	return returnObj;
}

+ (id)objectWithDictionary:(NSDictionary *)dict
{
	__block id returnObj = nil;
	[dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if ([key isKindOfClass:[NSString class]]) {
			Class objectClass = [self class];
			returnObj = [self newObjectOfClass:objectClass fromObject:obj];
		}
	}];
	
	return returnObj;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
	if ((self = [super init])) {
		[self updateWithDictionary:dict];
	}
	
	return self;
}

- (void)updateWithDictionary:(NSDictionary *)dict
{
	// TODO: the following 3 dictionaries need to be created by walking class hierarchy from GFJSONObject
	// down to actual class and creating a combined dictionary mapping (in case there are multiple layers
	// of subclasses)
	NSDictionary *nameMapping = [[self class] jsonMapping];
	NSDictionary *valueTransformers = [[self class] valueTransformers];
	NSDictionary *jsonProperties = [[self class] jsonProperties];
	
	[dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
		NSString *jsonKey = key;
		NSString *propertyName = [[nameMapping allKeysForObject:jsonKey] lastObject];
		if (propertyName) {
			// treat NSNull as nil
			if ([obj isEqual:[NSNull null]]) {
				obj = nil;
			}
			
			// Now, translate the json object according to the JSON mapping
			id jsonMappingObject = [jsonProperties objectForKey:propertyName];
			Class cls = Nil;
			if ([jsonMappingObject isKindOfClass:[NSString class]]) {
				cls = NSClassFromString(jsonMappingObject);
			} else {
				cls = jsonMappingObject;
			}
			
			if (cls != Nil && [cls isSubclassOfClass:[GFJSONObject class]]) {
				if ([obj isKindOfClass:[NSArray class]]) {
					NSArray *objArray = obj;
					NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:[objArray count]];
					for (id arrayObj in objArray) {
						if ([arrayObj isKindOfClass:[NSDictionary class]]) {
							NSDictionary *arrayObjDict = arrayObj;
							GFJSONObject *jsonObject = [(GFJSONObject *)[cls alloc] initWithDictionary:arrayObjDict];
							[tempArray addObject:jsonObject];
						} else if ([arrayObj isKindOfClass:cls]) {
							// will this case ever get hit (for any reason) ?
							[tempArray addObject:arrayObj];
						} else {
							// not a JSON dictionary
						}
					}
					obj = [tempArray copy];
				} else if ([obj isKindOfClass:[NSDictionary class]]) {
					// TODO (?): either need to convert the dictionary into GFJSONObjects OR
					// it is a dictionary containing GFJSONObjects as values...
					NSDictionary *dictObj = obj;
					GFJSONObject *jsonObject = [(GFJSONObject *)[cls alloc] initWithDictionary:dictObj];
					obj = jsonObject;
				}
			}
			
			// Use any value transformers on the object
			NSString *transformerName = [valueTransformers objectForKey:propertyName];
			if (transformerName) {
				NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:transformerName];
				if (transformer) {
					obj = [transformer transformedValue:obj];
				}
			}
			
			// Use KVC to actually set the value
			[self setValue:obj forKey:propertyName];
		}
	}];
}

- (id)JSONRepresentation
{
	NSMutableDictionary *JSONRepresentation = [[NSMutableDictionary alloc] init];
	
	NSDictionary *nameMapping = [[self class] jsonMapping];
	NSDictionary *valueTransformers = [[self class] valueTransformers];
	
	[nameMapping enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		NSString *propertyName = key;
		NSString *jsonKeyName = obj;
		
		id value = [self valueForKey:propertyName];
		if (value) {
			// Use any value transformers (in reverse if supported) on the object
			NSString *transformerName = [valueTransformers objectForKey:propertyName];
			if (transformerName) {
				NSValueTransformer *transformer = [NSValueTransformer valueTransformerForName:transformerName];
				if (transformer) {
					if ([[transformer class] allowsReverseTransformation]) {
						value = [transformer reverseTransformedValue:value];
					} else {
						value = nil;
					}
				}
			}
			
			if ([value isKindOfClass:[GFJSONObject class]]) {
				// reverse the JSON transformation
			} else if ([value isKindOfClass:[NSArray class]]) {
				NSArray *valueArray = value;
				NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:[valueArray count]];
				for (id obj in valueArray) {
					id transformedObj = obj; // TODO
					
					[tempArray addObject:transformedObj];
				}
			} else if ([value isKindOfClass:[NSDictionary class]]) {
				// TODO (?)
			}
		}
		
		if (value == nil) {
			value = [NSNull null]; // do we want to do this in all cases?
		}
		
		// value must be: NSString, NSNumber, NSNull, NSArray, NSDictionary, ... ?
		
		[JSONRepresentation setObject:value forKey:jsonKeyName];
	}];
	
	return [JSONRepresentation copy];
}

- (void)updateWithObject:(GFJSONObject *)__unused obj
{
	
}

@end
