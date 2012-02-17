//
//  GFJSONObject.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-11.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GFJSONObject : NSObject

+ (void)registerClassPrefix:(NSString *)prefix;

+ (id)objectWithDictionary:(NSDictionary *)dict;

- (id)initWithDictionary:(NSDictionary *)dict;

- (void)updateWithDictionary:(NSDictionary *)dict;

- (void)updateWithObject:(GFJSONObject *)obj;

- (id)JSONRepresentation;

@end
