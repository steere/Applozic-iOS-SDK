//
//  ALUserDetail.h
//  Applozic
//
//  Created by devashish on 26/11/2015.
//  Copyright © 2015 applozic Inc. All rights reserved.
//

#import <CoreData/NSManagedObject.h>
#import <Foundation/Foundation.h>
#import "ALJson.h"

@interface ALUserDetail : ALJson


@property NSString *userId;

@property BOOL connected;

@property NSNumber *lastSeenAtTime;

@property (nonatomic, strong)  NSNumber *unreadCount;

@property (nonatomic, strong) NSString *displayName;

@property(nonatomic, copy) NSManagedObjectID *userDetailDBObjectId;

-(void)setUserDetails:(NSString *)jsonString;

-(void)userDetail;

-(NSString *)getDisplayName;

-(id)initWithDictonary:(NSDictionary*)messageDictonary;

@property NSString * imageLink;
@end
