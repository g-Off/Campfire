//
//  GFCampfireServicePlugIn.h
//  Campfire
//
//  Created by Geoffrey Foster on 12-02-04.
//  Copyright (c) 2012 g-Off.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IMServicePlugIn/IMServicePlugIn.h>

@interface GFCampfireServicePlugIn : NSObject <IMServicePlugIn,
IMServicePlugInGroupListSupport,
IMServicePlugInGroupListHandlePictureSupport,
IMServicePlugInChatRoomSupport,
IMServicePlugInPresenceSupport>

@end
