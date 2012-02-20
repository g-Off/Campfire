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

@end

@implementation GFCampfireCommand

@synthesize command;
@synthesize helpString;
@synthesize selector;

+ (GFCampfireCommand *)commandWithName:(NSString *)command helpString:(NSString *)helpString selector:(SEL)aSelector
{
	return [[self alloc] initWithName:command helpString:helpString selector:aSelector];
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

- (void)performActionWithObject:(id)obj args:(NSString *)args
{
	args = [args stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	[obj performSelector:self.selector withObject:args];
}

@end
