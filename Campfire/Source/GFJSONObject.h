//
//  GFJSONObject.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-11.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GFJSONObject : NSObject

+ (NSDictionary *)jsonMapping;
+ (NSDictionary *)valueTransformers;
+ (NSDictionary *)jsonProperties;

+ (void)registerClassPrefix:(NSString *)prefix;

+ (id)autoObjectWithDictionary:(NSDictionary *)dict;
+ (id)objectWithDictionary:(NSDictionary *)dict;
- (instancetype)initWithDictionary:(NSDictionary *)dict;

- (void)updateWithDictionary:(NSDictionary *)dict;
- (void)updateWithObject:(GFJSONObject *)obj;

- (id)JSONRepresentation;

@end
