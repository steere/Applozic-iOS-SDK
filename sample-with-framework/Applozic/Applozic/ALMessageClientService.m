//
//  ALMessageClientService.m
//  ChatApp
//
//  Created by devashish on 02/10/2015.
//  Copyright (c) 2015 AppLogic. All rights reserved.
//

#import "ALMessageClientService.h"
#import "ALConstant.h"
#import "ALRequestHandler.h"
#import "ALResponseHandler.h"
#import "ALMessage.h"
#import "ALUserDefaultsHandler.h"
#import "ALMessageDBService.h"
#import "ALDBHandler.h"
#import "ALChannelService.h"
#import "ALSyncMessageFeed.h"
#import "ALUtilityClass.h"
#import "ALConversationService.h"
#import "MessageListRequest.h"
#import "ALUserBlockResponse.h"
#import "ALUserService.h"

@implementation ALMessageClientService

-(void) updateDeliveryReports:(NSMutableArray *) messages
{
    for (ALMessage * theMessage in messages) {
        if ([theMessage.type isEqualToString: @"4"]) {
            [self updateDeliveryReport:theMessage.pairedMessageKey];
        }
    }
}

-(void) updateDeliveryReport: (NSString *) key
{
    NSLog(@"updating delivery report for: %@", key);
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/delivered",KBASE_URL];
    NSString *theParamString=[NSString stringWithFormat:@"userId=%@&key=%@",[ALUserDefaultsHandler getUserId],key];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"DEILVERY_REPORT" WithCompletionHandler:^(id theJson, NSError *theError) {
        NSLog(@"server response received for delivery report %@", theJson);
        
        if (theError) {
            
            //completion(nil,theError);
            
            return ;
        }
        
        //completion(response,nil);
        
    }];

}

-(void) addWelcomeMessage:(NSNumber *)channelKey
{
    ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];
    ALMessageDBService* messageDBService = [[ALMessageDBService alloc]init];
    
    ALMessage * theMessage = [ALMessage new];
    
    
    theMessage.contactIds = @"applozic";//1
    theMessage.to = @"applozic";//2
    theMessage.createdAtTime = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970] * 1000];
    theMessage.deviceKey = [ALUserDefaultsHandler getDeviceKeyString];
    theMessage.sendToDevice = NO;
    theMessage.shared = NO;
    theMessage.fileMeta = nil;
    theMessage.status = [NSNumber numberWithInt:READ];
    theMessage.key = @"welcome-message-temp-key-string";
    theMessage.delivered=NO;
    theMessage.fileMetaKey = @"";//4
    theMessage.contentType = 0;
    theMessage.status = [NSNumber numberWithInt:DELIVERED_AND_READ];
    if(channelKey!=nil) //Group's Welcome
    {
        theMessage.type=@"101";
        theMessage.message=@"You have created a new group, Say something!!";
        theMessage.groupId = channelKey;
    }
    else //Individual's Welcome
    {
        theMessage.type = @"4";
         theMessage.message = @"Welcome to Applozic! Drop a message here or contact us at devashish@applozic.com for any queries. Thanks";//3
        theMessage.groupId = nil;
    }
    [messageDBService createMessageEntityForDBInsertionWithMessage:theMessage];
    [theDBHandler.managedObjectContext save:nil];
    
}


-(void) getLatestMessageGroupByContactWithCompletion:(void(^)(ALMessageList * alMessageList, NSError * error)) completion{
    
    NSLog(@"calling new contact groupcode ....");
    
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/list",KBASE_URL];
    
    NSString * theParamString = [NSString stringWithFormat:@"startIndex=%@",@"0"];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"GET MESSAGES GROUP BY CONTACT" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
        
        ALMessageList *messageListResponse =  [[ALMessageList alloc] initWithJSONString:theJson] ;
        
        completion(messageListResponse,nil); 
        NSLog(@"message list response THE JSON %@",theJson);
        ALChannelService *channelService = [[ALChannelService alloc] init];
        [channelService callForChannelServiceForDBInsertion:theJson];
        //        [ALUserService processContactFromMessages:[messageListResponse messageList]];
        
        //USER BLOCK SYNC CALL
        ALUserService *userService = [ALUserService new];
        [userService blockUserSync: [ALUserDefaultsHandler getUserBlockLastTimeStamp]];
        
    }];
    
}

-(void) getMessagesListGroupByContactswithCompletion:(void(^)(NSMutableArray * messages, NSError * error)) completion {
    
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/list",KBASE_URL];
    
    NSString * theParamString = [NSString stringWithFormat:@"startIndex=%@",@"0"];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"GET MESSAGES GROUP BY CONTACT" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
        
        ALMessageList *messageListResponse =  [[ALMessageList alloc] initWithJSONString:theJson] ;
        
        completion(messageListResponse.messageList,nil);
//        NSLog(@"getMessagesListGroupByContactswithCompletion message list response THE JSON %@",theJson);
        //        [ALUserService processContactFromMessages:[messageListResponse messageList]];
        
        //====== NEED CHECK  DB QUERY AND CALLING METHODS
        
        ALChannelService *channelService = [[ALChannelService alloc] init];
        [channelService callForChannelServiceForDBInsertion:theJson];
        
        //=========
    }];
    
}

-(void) getMessageListForUser:(MessageListRequest*) messageListRequest withCompletion:(void (^)(NSMutableArray *, NSError *, NSMutableArray *))completion
{
    
   NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/list",KBASE_URL];
   NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:messageListRequest.getParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"GET MESSAGES LIST FOR USERID" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            completion(nil, theError, nil);
            return ;
        }
        if(messageListRequest.channelKey){
            [ALUserDefaultsHandler setServerCallDoneForMSGList:true forContactId:[messageListRequest.channelKey stringValue]];
        }else{
            [ALUserDefaultsHandler setServerCallDoneForMSGList:true forContactId:messageListRequest.userId];
        }
        if(messageListRequest.conversationId){
            [ALUserDefaultsHandler setServerCallDoneForMSGList:true forContactId:[messageListRequest.conversationId stringValue]];
        }
        ALMessageList *messageListResponse =  [[ALMessageList alloc] initWithJSONString:theJson andWithUserId:messageListRequest.userId andWithGroup:messageListRequest.channelKey];
        
        ALMessageDBService *almessageDBService =  [[ALMessageDBService alloc] init];
        [almessageDBService addMessageList:messageListResponse.messageList];
        ALConversationService * alConversationService  = [[ALConversationService alloc] init];
        [alConversationService addConversations:messageListResponse.conversationPxyList];
        
        completion(messageListResponse.messageList, nil, messageListResponse.userDetailsList);
//        NSLog(@"getMessageListForUser message list response THE JSON %@",theJson);
        
    }];
    
}


-(void) sendPhotoForUserInfo:(NSDictionary *)userInfo withCompletion:(void(^)(NSString * message, NSError *error)) completion {
    
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/aws/file/url",KBASE_FILE_URL];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:nil];
    
    [ALResponseHandler processRequest:theRequest andTag:@"CREATE FILE URL" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
        
        NSString *imagePostingURL = (NSString *)theJson;
        
        completion(imagePostingURL,nil);
        
    }];
}

-(void) getLatestMessageForUser:(NSString *)deviceKeyString withCompletion:(void (^)( ALSyncMessageFeed *, NSError *))completion{
    //@synchronized(self) {
        NSString *lastSyncTime =[ALUserDefaultsHandler getLastSyncTime];
        if ( lastSyncTime == NULL ){
            lastSyncTime = @"0";
        }
        NSLog(@"last syncTime in call %@", lastSyncTime);
        NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/sync",KBASE_URL];
        
        NSString * theParamString = [NSString stringWithFormat:@"lastSyncTime=%@",lastSyncTime];
        
        NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
        
        [ALResponseHandler processRequest:theRequest andTag:@"SYNC LATEST MESSAGE URL" WithCompletionHandler:^(id theJson, NSError *theError) {
            
            if (theError) {
                
                completion(nil,theError);
                return ;
            }
             ALSyncMessageFeed *syncResponse =  [[ALSyncMessageFeed alloc] initWithJSONString:theJson];
            completion(syncResponse,nil);
            NSLog(@"LatestMessage Json: %@", theJson);
        }];
        
    //}
    
}

-(void )deleteMessage:( NSString * ) keyString andContactId:( NSString * )contactId withCompletion:(void (^)(NSString *, NSError *))completion{
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/delete",KBASE_URL];
    NSString * theParamString = [NSString stringWithFormat:@"key=%@&userId=%@",keyString,contactId];
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"DELETE_MESSAGE" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            
            completion(nil,theError);
            
            return ;
        }
        else{
            //delete sucessfull/reponse
            NSLog(@"Response of delete: %@", (NSString *)theJson);
            completion((NSString *)theJson,nil);
        }
    }];
}


-(void)deleteMessageThread:( NSString * ) contactId orChannelKey:(NSNumber *)channelKey withCompletion:(void (^)(NSString *, NSError *))completion
{
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/delete/conversation",KBASE_URL];
    NSString * theParamString;
    if(channelKey != nil)
    {
        theParamString = [NSString stringWithFormat:@"groupId=%@",channelKey];
    }
    else
    {
        theParamString = [NSString stringWithFormat:@"userId=%@",contactId];
    }
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"DELETE_MESSAGE" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError)
        {
            completion(nil,theError);
            NSLog(@"theError");
            return ;
        }
        else
        {
            //delete sucessfull
            NSLog(@"sucessfully deleted !");
            ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
            [dbService deleteAllMessagesByContact:contactId orChannelKey:channelKey];
            
        }
        
        NSLog(@"Response of delete: %@", (NSString *)theJson);
        completion((NSString *)theJson,nil);
    }];
}


-(void)sendMessage: (NSDictionary *) userInfo WithCompletionHandler:(void(^)(id theJson, NSError *theError))completion {
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/send",KBASE_URL];
    NSString * theParamString = [ALUtilityClass generateJsonStringFromDictionary:userInfo];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createPOSTRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"SEND MESSAGE" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError) {
            completion(nil,theError);
            return ;
        }
        completion(theJson,nil);
    }];

}

-(void)getCurrentMessageInformation:(NSString *)messageKey withCompletionHandler:(void(^)(ALMessageInfoResponse *msgInfo, NSError *theError))completion
{
    NSString * theUrlString = [NSString stringWithFormat:@"%@/rest/ws/message/info", KBASE_URL];
    NSString * theParamString = [NSString stringWithFormat:@"key=%@", messageKey];
    
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:theUrlString paramString:theParamString];
    
    [ALResponseHandler processRequest:theRequest andTag:@"MESSSAGE_INFORMATION" WithCompletionHandler:^(id theJson, NSError *theError) {
        
        if (theError)
        {
            NSLog(@"ERROR IN MESSAGE INFORMATION API RESPONSE : %@", theError);
        }
        else
        {
            NSLog(@"RESPONSE MESSSAGE_INFORMATION API JSON : %@", (NSString *)theJson);
            ALMessageInfoResponse *msgInfoObject = [[ALMessageInfoResponse alloc] initWithJSONString:(NSString *)theJson];
            completion(msgInfoObject, theError);
        }
    }];

}

@end
