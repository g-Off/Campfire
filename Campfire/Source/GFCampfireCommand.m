//
//  GFCampfireCommand.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-19.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireCommand.h"

@interface GFCampfireCommand ()

@property (readwrite, strong) NSString *command;
@property (readwrite, strong) NSString *helpString;
@property (readwrite, assign) SEL selector;
@property (readwrite, copy) void (^block)(NSString *params);

@end

@implementation GFCampfireCommand

@synthesize command;
@synthesize helpString;
@synthesize selector;
@synthesize block;

+ (GFCampfireCommand *)commandWithName:(NSString *)command helpString:(NSString *)helpString selector:(SEL)aSelector
{
	return [[self alloc] initWithName:command helpString:helpString selector:aSelector];
}

+ (GFCampfireCommand *)commandWithName:(NSString *)command helpString:(NSString *)helpString action:(void (^)(NSString *args))block
{
	return [[self alloc] initWithName:command helpString:helpString action:block];
}

- (instancetype)initWithName:(NSString *)aCommand helpString:(NSString *)aHelpString selector:(SEL)aSelector
{
	if ((self = [super init])) {
		self.command = aCommand;
		self.helpString = aHelpString;
		self.selector = aSelector;
	}
	
	return self;
}

- (instancetype)initWithName:(NSString *)aCommand helpString:(NSString *)aHelpString action:(void (^)(NSString *args))aBlock
{
	if ((self = [super init])) {
		self.command = aCommand;
		self.helpString = aHelpString;
		self.block = aBlock;
	}
	
	return self;
}

- (void)performActionWithObject:(id)obj args:(NSString *)args
{
	args = [args stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if (self.selector) {
		[obj performSelector:self.selector withObject:args];
	} else if (self.block) {
		self.block(args);
	}
}

@end
