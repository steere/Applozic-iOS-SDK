//
//  ALApplozicSettings.h
//  Applozic
//
//  Created by devashish on 20/11/2015.
//  Copyright © 2015 applozic Inc. All rights reserved.
//

#define USER_PROILE_PROPERTY @"USER_PROILE_PROPERTY"
#define SEND_MSG_COLOUR @"SEND_MSG_COLOUR"
#define RECEIVE_MSG_COLOUR @"RECEIVE_MSG_COLOUR"
#define NAVIGATION_BAR_COLOUR @"NAVIGATION_BAR_COLOUR"
#define NAVIGATION_BAR_ITEM_COLOUR @"NAVIGATION_BAR_ITEM_COLOUR"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ALApplozicSettings : NSObject

+(void)setUserProfileHidden: (BOOL)flag;

+(BOOL)isUserProfileHidden;

+(void)setColourForSendMessages:(UIColor *)sendMsgColour ;

+(void)setColourForReceiveMessages:(UIColor *)receiveMsgColour;

+(UIColor *)getSendMsgColour;

+(UIColor *)getReceiveMsgColour;

+(void)setColourForNavigation:(UIColor *)barColour;

+(UIColor *)getColourForNavigation;

+(void)setColourForNavigationItem:(UIColor *)barItemColour;

+(UIColor *)getColourForNavigationItem;

+(void) clearAllSettings;

@end
