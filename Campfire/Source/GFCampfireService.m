//
//  GFCampfireService.m
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import "GFCampfireService.h"

@implementation GFCampfireService

@end

@implementation GFCampfireServiceParser {
	id currentObject;
	NSString *currentElementName;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	currentElementName = elementName;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	currentElementName = nil;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	
}

@end
