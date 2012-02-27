//
//  GFCampfireCommand.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-19.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GFCampfireCommand : NSObject

@property (readonly, strong) NSString *command;
@property (readonly, strong) NSString *helpString;
@property (readonly, assign) SEL selector;
@property (readonly, copy) void (^block)(NSString *args);

+ (GFCampfireCommand *)commandWithName:(NSString *)command helpString:(NSString *)helpString selector:(SEL)aSelector;
+ (GFCampfireCommand *)commandWithName:(NSString *)command helpString:(NSString *)helpString action:(void (^)(NSString *args))block;
- (instancetype)initWithName:(NSString *)command helpString:(NSString *)helpString selector:(SEL)aSelector;
- (instancetype)initWithName:(NSString *)command helpString:(NSString *)helpString action:(void (^)(NSString *args))aBlock;

- (void)performActionWithObject:(id)obj args:(NSString *)args;

@end
