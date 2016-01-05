//
//  ALChannelDBService.m
//  Applozic
//
//  Created by devashish on 28/12/2015.
//  Copyright © 2015 applozic Inc. All rights reserved.
//

#import "ALChannelDBService.h"

@interface ALChannelDBService ()

@end

@implementation ALChannelDBService

-(void)insertChannel:(NSMutableArray *)channelList
{
    NSMutableArray *channelArray = [[NSMutableArray alloc] init];
    ALDBHandler *theDBHandler = [ALDBHandler sharedInstance];
    
    for(ALChannel *channel in channelList)
    {
        DB_CHANNEL *dbChannel = [self createChannelEntity:channel];
        // IT MIGHT BE USED IN FUTURE
        [theDBHandler.managedObjectContext save:nil];
        //channel.channelDBObjectId = dbChannel.objectID;
        [channelArray addObject:channel];
    }
    
    
    NSError *error = nil;
    [theDBHandler.managedObjectContext save:&error];
    if(error)
    {
        NSLog(@"ERROR IN insertChannel METHOD %@",error);
    }
}

-(DB_CHANNEL *)createChannelEntity:(ALChannel *)channel
{
    ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
    DB_CHANNEL * theChannelEntity = [NSEntityDescription insertNewObjectForEntityForName:@"DB_CHANNEL" inManagedObjectContext:theDBHandler.managedObjectContext];
    
    if(channel)
    {
        theChannelEntity.channelDisplayName = channel.name;
        theChannelEntity.channelKey = channel.key;
        if(channel.userCount)
        {
            theChannelEntity.userCount = channel.userCount;
        }
        theChannelEntity.type = channel.type;
        theChannelEntity.adminId = channel.adminKey;
        theChannelEntity.unreadCount = channel.unreadCount;
    }
    
    return theChannelEntity;
}

-(void)insertChannelUserX:(NSMutableArray *)channelUserXList
{
    NSMutableArray *channelUserXArray = [[NSMutableArray alloc] init];
    ALDBHandler *theDBHandler = [ALDBHandler sharedInstance];
    for(ALChannelUserX *channelUserX in channelUserXList)
    {
        DB_CHANNEL_USER_X *dbChannelUserX = [self createChannelUserXEntity:channelUserX];
        // IT MIGHT BE USED IN FUTURE
        [theDBHandler.managedObjectContext save:nil];
        //channelUserX.channelDBObjectId = dbChannelUserX.objectID;
        [channelUserXArray addObject:channelUserX];
    }
    
    NSError *error = nil;
    [theDBHandler.managedObjectContext save:&error];
    if(error)
    {
        NSLog(@"ERROR IN insertChannelUserX METHOD %@",error);
    }
    
}

-(DB_CHANNEL_USER_X *)createChannelUserXEntity:(ALChannelUserX *)channelUserX
{
    ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
    DB_CHANNEL_USER_X * theChannelUserXEntity = [NSEntityDescription insertNewObjectForEntityForName:@"DB_CHANNEL_USER_X" inManagedObjectContext:theDBHandler.managedObjectContext];
    
    if(channelUserX)
    {
        theChannelUserXEntity.channelKey = channelUserX.key;
        theChannelUserXEntity.userId = channelUserX.userKey;
        //        theChannelUserXEntity.status = channelUserX.status;
    }
    
    return theChannelUserXEntity;
}

-(NSMutableArray *)getChannelMembersList:(NSNumber *)channelKey
{
    NSMutableArray *memberList = [[NSMutableArray alloc] init];    
    ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DB_CHANNEL_USER_X" inManagedObjectContext:theDBHandler.managedObjectContext];
    [fetchRequest setPropertiesToFetch:[NSArray arrayWithObject:@"userId"]];
    [fetchRequest setEntity:entity];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"channelKey = %@", channelKey];
    [fetchRequest setPredicate:predicate];
    
    NSError *error = nil;
    NSArray *fetchedObjects = [theDBHandler.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
    {
        NSLog(@"ERROR IN FETCH MEMBER LIST");
    }
    else
    {
        memberList = [NSMutableArray arrayWithArray:fetchedObjects];
    }
   
    return memberList;
}

-(ALChannel *)loadChannelByKey:(NSNumber *)key
{
    DB_CHANNEL *dbChannel = [self getChannelByKey:key];
    ALChannel *alChannel = [[ALChannel alloc] init];
    
    if (!alChannel)
    {
        return nil;
    }
    
    alChannel.name = dbChannel.channelDisplayName;
    alChannel.unreadCount = dbChannel.unreadCount;

    return alChannel;
}

-(DB_CHANNEL *)getChannelByKey:(NSNumber *)key
{
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DB_CHANNEL" inManagedObjectContext:dbHandler.managedObjectContext];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"channelKey = %@",key];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    
    NSError *fetchError = nil;
    NSArray *result = [dbHandler.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    
    if (result.count)
    {
        DB_CHANNEL *dbChannel = [result objectAtIndex:0];
        return dbChannel;
    }
    else
    {
        return nil;
    }
}

-(NSMutableArray *)getListOfAllUsersInChannel:(NSNumber *)key
{
    NSMutableArray *memberList = [[NSMutableArray alloc] init];
    ALDBHandler * dbHandler = [ALDBHandler sharedInstance];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DB_CHANNEL_USER_X" inManagedObjectContext:dbHandler.managedObjectContext];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"channelKey = %@",key];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    
    NSError *fetchError = nil;
    NSArray *resultArray = [dbHandler.managedObjectContext executeFetchRequest:fetchRequest error:&fetchError];
    NSLog(@"ERROR (IF ANY) : %@", fetchError);
    
    if (resultArray.count)
    {
        for(DB_CHANNEL_USER_X *dbChannelUserX in resultArray)
        {
            [memberList addObject:dbChannelUserX.userId];
        }
        
        return memberList;
    }
    else
    {
        return nil;
    }
    
}

-(NSString *)stringFromChannelUserList:(NSNumber *)key
{
    NSString *listString = @"";
    NSString *str = @"";
    NSMutableArray *listArray = [NSMutableArray array];
    listArray = [NSMutableArray arrayWithArray:[self getListOfAllUsersInChannel:key]];
    listString = [listString stringByAppendingString:listArray[0]];
    listString = [listString stringByAppendingString:@", "];
    listString = [listString stringByAppendingString:listArray[1]];
    
    if(listArray.count > 2)
    {
        int counter = (int)listArray.count;
        counter = counter - 2;
        str = [NSString stringWithFormat:@" and %d",counter];
        str = [str stringByAppendingString:@" Other"];
        listString = [listString stringByAppendingString:str];
    }
    return listString;
}

-(ALChannel *)checkChannelEntity:(NSNumber *)channelKey
{
    DB_CHANNEL *dbChannel = [self getChannelByKey:channelKey];
    ALChannel *channel  = [[ALChannel alloc] init];
    
    if(dbChannel)
    {
        channel.name = dbChannel.channelDisplayName;
        return channel;
    }
    else
    {
        return nil;
    }
}

@end