//
//  NSString+GFJSONObject.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-26.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (GFJSONObject)

- (id)jsonObject:(NSError **)error;

@end
