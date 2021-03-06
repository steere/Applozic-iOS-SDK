//
//  ALMessageService.m
//  ALChat
//
//  Copyright (c) 2015 AppLozic. All rights reserved.
//

#import "ALMessageService.h"
#import "ALRequestHandler.h"
#import "ALResponseHandler.h"
#import "ALUtilityClass.h"
#import "ALSyncMessageFeed.h"
#import "ALMessageDBService.h"
#import "ALMessageList.h"
#import "ALDBHandler.h"
#import "ALConnection.h"
#import "ALConnectionQueueHandler.h"
#import "ALUserDefaultsHandler.h"
#import "ALMessageClientService.h"
#import "ALSendMessageResponse.h"
#import "ALUserService.h"
#import "ALUserDetail.h"
#import "ALContactDBService.h"
#import "ALContactService.h"
#import "ALConversationService.h"


@implementation ALMessageService 

static ALMessageClientService *alMsgClientService;

+(void) processLatestMessagesGroupByContact
{
    
    ALMessageClientService * almessageClientService = [[ALMessageClientService alloc] init];
    
    [almessageClientService getLatestMessageGroupByContactWithCompletion:^( ALMessageList *alMessageList, NSError *error) {
        
        if(alMessageList)
        {
            ALMessageDBService *alMessageDBService = [[ALMessageDBService alloc] init];
            [alMessageDBService addMessageList:alMessageList.messageList];
            ALContactDBService *alContactDBService = [[ALContactDBService alloc] init];
            [alContactDBService addUserDetails:alMessageList.userDetailsList];
            [ALUserDefaultsHandler setBoolForKey_isConversationDbSynced:YES];
        }
    }];
    
}


+(void)getMessageListForUser:(MessageListRequest*)messageListRequest withCompletion:(void (^)(NSMutableArray *, NSError *, NSMutableArray *))completion{
    
    ALMessageDBService *almessageDBService =  [[ALMessageDBService alloc] init];
    NSMutableArray * messageList = [almessageDBService getMessageListForContactWithCreatedAt:messageListRequest.userId withCreatedAt:messageListRequest.endTimeStamp andChannelKey:messageListRequest.channelKey conversationId:messageListRequest.conversationId];
    
    //Found Record in DB itself ...if not make call to server
    if(messageList.count > 0 && ![ALUserDefaultsHandler isServerCallDoneForMSGList:messageListRequest.userId]){
       // NSLog(@"the Message List::%@",messageList);
        completion(messageList, nil, nil);
        return;
    }else {
        NSLog(@"message list is coming from DB %ld", (unsigned long)messageList.count);
    }
    ALMessageClientService *alMessageClientService =  [[ALMessageClientService alloc ]init];
    
    [alMessageClientService getMessageListForUser:messageListRequest withCompletion:^(NSMutableArray *messages, NSError *error, NSMutableArray *userDetailArray){
        
        completion(messages, error,userDetailArray);
        
    }];
}

+(void) sendMessages:(ALMessage *)alMessage withCompletion:(void(^)(NSString * message, NSError * error)) completion {
    
    //DB insert if objectID is null
    DB_Message* dbMessage;
    ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
    NSError *theError=nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateConversationTableNotification" object:alMessage userInfo:nil];
    
    if (alMessage.msgDBObjectId == nil)
    {
        NSLog(@"message not in DB new insertion.");
        dbMessage = [dbService addMessage:alMessage];
    }
    else
    {
        NSLog(@"message found in DB just getting it not inserting new one...");
        dbMessage =(DB_Message*)[dbService getMeesageById:alMessage.msgDBObjectId error:&theError];
    }
    //convert to dic
    NSDictionary * messageDict = [alMessage dictionary];
    ALMessageClientService * alMessageClientService = [[ALMessageClientService alloc]init];
    [alMessageClientService sendMessage:messageDict WithCompletionHandler:^(id theJson, NSError *theError) {
        
        NSString *statusStr=nil;
        if(!theError)
        {
            statusStr = (NSString*)theJson;
            //TODO: move to db layer
            ALSendMessageResponse  *response = [[ALSendMessageResponse alloc] initWithJSONString:statusStr ];
            
            ALDBHandler * theDBHandler = [ALDBHandler sharedInstance];

            dbMessage.key = response.messageKey;
            dbMessage.inProgress = [NSNumber numberWithBool:NO];
            dbMessage.isUploadFailed = [NSNumber numberWithBool:NO];
            dbMessage.createdAt =response.createdAt;
            dbMessage.sentToServer=[NSNumber numberWithBool:YES];
            dbMessage.status = [NSNumber numberWithInt:SENT];
            
            alMessage.key = dbMessage.key;
            alMessage.sentToServer= dbMessage.sentToServer.boolValue;
            alMessage.inProgress=dbMessage.inProgress.boolValue;
            alMessage.isUploadFailed=dbMessage.isUploadFailed.boolValue;
            alMessage.status = dbMessage.status;
        
            [theDBHandler.managedObjectContext save:nil];
        }else{
            NSLog(@" got error while sending messages");
        }
        completion(statusStr,theError);
    }];
    
}



+(void) getLatestMessageForUser:(NSString *)deviceKeyString withCompletion:(void (^)( NSMutableArray *, NSError *))completion
{
    
    if(!alMsgClientService)
    {
        alMsgClientService = [[ALMessageClientService alloc]init];
    }
    
    @synchronized(alMsgClientService) {
        
        [ alMsgClientService getLatestMessageForUser:deviceKeyString withCompletion:^(ALSyncMessageFeed * syncResponse , NSError *error) {
            NSMutableArray *messageArray = nil;
           
            if(!error){
                if (syncResponse.deliveredMessageKeys.count > 0) {
                    [ALMessageService updateDeliveredReport: syncResponse.deliveredMessageKeys withStatus:DELIVERED];
                }
                if(syncResponse.messagesList.count >0 ){
                    messageArray = [[NSMutableArray alloc] init];
                    ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
                    messageArray = [dbService addMessageList:syncResponse.messagesList];
                    [ALMessageService incrementContactUnreadCount:messageArray];
                    [ALUserService processContactFromMessages:messageArray withCompletion:^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NEW_MESSAGE_NOTIFICATION object:messageArray userInfo:nil];
                        completion(messageArray,error);
                    }];
                    
                }
                
                [ALUserDefaultsHandler setLastSyncTime:syncResponse.lastSyncTime];
                ALMessageClientService *messageClientService = [[ALMessageClientService alloc] init];
                [messageClientService updateDeliveryReports:syncResponse.messagesList];
                
            }else{
                completion(messageArray,error);
            }
            
        }];
    }
    
}

+(void)incrementContactUnreadCount:(NSArray*)messagesArray
{
    
    for(ALMessage * message in messagesArray)
    {
        if([message.status isEqualToNumber:[NSNumber numberWithInt:DELIVERED_AND_READ]] ||
           (message.groupId && message.contentType == 10) || [message.type isEqualToString:@"5"])
        {
            return;
        }
        
        if(message.groupId)
        {
            NSNumber * groupId = message.groupId;
            ALChannelDBService * channelDBService =[[ALChannelDBService alloc] init];
            ALChannel * channel = [channelDBService loadChannelByKey:groupId];
            channel.unreadCount = [NSNumber numberWithInt:channel.unreadCount.intValue+1];
            [channelDBService updateUnreadCountChannel:message.groupId unreadCount:channel.unreadCount];
        }
        else
        {
            NSString * contactId = message.contactIds;
            ALContactService * contactService=[[ALContactService alloc] init];
            ALContact * contact =[contactService loadContactByKey:@"userId" value:contactId];
            contact.unreadCount=[NSNumber numberWithInt:[contact.unreadCount intValue]+1];
            [contactService addContact:contact];
            [contactService updateContact:contact];
        }
        if(message.conversationId)
        [self fetchTopicDetails:message.conversationId];
        
    }
}

+(void)fetchTopicDetails :(NSNumber *)conversationId
{
    if(conversationId)
    {
        ALConversationService * alConversationService = [[ALConversationService alloc] init];
        [alConversationService fetchTopicDetails:conversationId];
    }
}

+(void) updateDeliveredReport: (NSArray *) deliveredMessageKeys withStatus:(int)status
{
    for (id key in deliveredMessageKeys)
    {
        ALMessageDBService* messageDBService = [[ALMessageDBService alloc] init];
        [messageDBService updateMessageDeliveryReport:key withStatus:status];
    }
}

+(void )deleteMessage:( NSString * ) keyString andContactId:( NSString * )contactId withCompletion:(void (^)(NSString *, NSError *))completion{
    
    //db
    ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
    DB_Message* dbMessage=(DB_Message*)[dbService getMessageByKey:@"key" value:keyString];
    [dbMessage setDeletedFlag:[NSNumber numberWithBool:YES]];
    NSError *error;
    if (![[dbMessage managedObjectContext] save:&error])
    {
        NSLog(@"Delete Flag Not Set");
    }
    
    ALMessageDBService * dbService2 = [[ALMessageDBService alloc]init];
    DB_Message* dbMessage2=(DB_Message*)[dbService2 getMessageByKey:@"key" value:keyString];
    NSArray *keys = [[[dbMessage2 entity] attributesByName] allKeys];
    NSDictionary *dict = [dbMessage2 dictionaryWithValuesForKeys:keys];
    NSLog(@"DB Message In Del: %@",dict);
    
    
    ALMessageClientService *alMessageClientService =  [[ALMessageClientService alloc]init];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        
        [alMessageClientService deleteMessage:keyString andContactId:contactId
                               withCompletion:^(NSString * response, NSError *error) {
                                   if(!error){
                                       //none error then delete from DB.
                                       [dbService deleteMessageByKey:keyString];
                                   }
                                   completion(response,error);
                               }];
        
    });
    
    
}


+(void)deleteMessageThread:( NSString * ) contactId orChannelKey:(NSNumber *)channelKey withCompletion:(void (^)(NSString *, NSError *))completion
{
    
    ALMessageClientService *alMessageClientService =  [[ALMessageClientService alloc]init];
    [alMessageClientService deleteMessageThread:contactId orChannelKey:channelKey
                                 withCompletion:^(NSString * response, NSError *error) {
                                     if (!error){
                                         //delete sucessfull
                                         NSLog(@"sucessfully deleted !");
                                         ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
                                         [dbService deleteAllMessagesByContact:contactId orChannelKey:channelKey];
                                         
                                         if(channelKey)
                                         {
                                             [ALChannelService setUnreadCountZeroForGroupID:channelKey];
                                         }
                                         else
                                         {
                                             [ALUserService setUnreadCountZeroForContactId:contactId];
                                         }
                                         
                                     }
                                     completion(response,error);
                                 }];
}




+(void) proessUploadImageForMessage:(ALMessage *)message databaseObj:(DB_FileMetaInfo *)fileMetaInfo uploadURL:(NSString *)uploadURL withdelegate:(id)delegate{
    
    
    NSString * docDirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString * timestamp = message.imageFilePath;
    NSString * filePath = [docDirPath stringByAppendingPathComponent:timestamp];
    NSLog(@"FILE_PATH : %@",filePath);
    NSMutableURLRequest * request = [ALRequestHandler createPOSTRequestWithUrlString:uploadURL paramString:nil];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        //Create boundary, it can be anything
        NSString *boundary = @"------ApplogicBoundary4QuqLuM1cE5lMwCy";
        // set Content-Type in HTTP header
        NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
        [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
        // post body
        NSMutableData *body = [NSMutableData data];
        //Populate a dictionary with all the regular values you would like to send.
        NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
        // add params (all params are strings)
        for (NSString *param in parameters) {
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", param] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"%@\r\n", [parameters objectForKey:param]] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        NSString *FileParamConstant = @"files[]";
        NSData *imageData = [[NSData alloc]initWithContentsOfFile:filePath];
        NSLog(@"%f",imageData.length/1024.0);
        //Assuming data is not nil we add this to the multipart form
        if (imageData)
        {
            [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", FileParamConstant,message.fileMeta.name] dataUsingEncoding:NSUTF8StringEncoding]];
            
            [body appendData:[[NSString stringWithFormat:@"Content-Type:%@\r\n\r\n", message.fileMeta.contentType] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:imageData];
            [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        //Close off the request with the boundary
        [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        // setting the body of the post to the request
        [request setHTTPBody:body];
        // set URL
        [request setURL:[NSURL URLWithString:uploadURL]];
        NSMutableArray * theCurrentConnectionsArray = [[ALConnectionQueueHandler sharedConnectionQueueHandler] getCurrentConnectionQueue];
        NSArray * theFiletredArray = [theCurrentConnectionsArray filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"keystring == %@", message.key]];
        
        if( theFiletredArray.count>0 ){
            NSLog(@"upload is already running .....not starting new one ....");
            return;
        }
        ALConnection * connection = [[ALConnection alloc] initWithRequest:request delegate:delegate startImmediately:YES];
        connection.keystring = message.key;
        connection.connectionType = @"Image Posting";
        [[[ALConnectionQueueHandler sharedConnectionQueueHandler] getCurrentConnectionQueue] addObject:connection];
        NSLog(@"CONNECTION_BEFORE_MQTT : %@",connection.mData);
    }
    
}

+(void) processImageDownloadforMessage:(ALMessage *) message withdelegate:(id)delegate
{
    NSString * urlString = [NSString stringWithFormat:@"%@/rest/ws/aws/file/%@",KBASE_FILE_URL,message.fileMeta.blobKey];
    NSMutableURLRequest * theRequest = [ALRequestHandler createGETRequestWithUrlString:urlString paramString:nil];
    ALConnection * connection = [[ALConnection alloc] initWithRequest:theRequest delegate:delegate startImmediately:YES];
    connection.keystring = message.key;
    connection.connectionType = @"Image Downloading";
    [[[ALConnectionQueueHandler sharedConnectionQueueHandler] getCurrentConnectionQueue] addObject:connection];
}

+(ALMessage*) processFileUploadSucess: (ALMessage *) message{
    
    ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
    DB_Message *dbMessage =  (DB_Message*)[dbService getMessageByKey:@"key" value:message.key];
    
    dbMessage.fileMetaInfo.blobKeyString = message.fileMeta.blobKey;
    dbMessage.fileMetaInfo.contentType = message.fileMeta.contentType;
    dbMessage.fileMetaInfo.createdAtTime = message.fileMeta.createdAtTime;
    dbMessage.fileMetaInfo.key = message.fileMeta.key;
    dbMessage.fileMetaInfo.name = message.fileMeta.name;
    dbMessage.fileMetaInfo.size = message.fileMeta.size;
    dbMessage.fileMetaInfo.suUserKeyString = message.fileMeta.userKey;
    message.fileMetaKey = message.fileMeta.key;
    [[ALDBHandler sharedInstance].managedObjectContext save:nil];
    return message;
}

+(void)processPendingMessages
{
    ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
    NSMutableArray * pendingMessageArray = [dbService getPendingMessages];
    NSLog(@"service called....%lu",(unsigned long)pendingMessageArray.count);
    
    for(ALMessage *msg  in pendingMessageArray )
    {
        
        if((!msg.fileMeta && !msg.pairedMessageKey))
        {
            NSLog(@"RESENDING_MESSAGE : %@", msg.message);
            [self sendMessages:msg withCompletion:^(NSString *message, NSError *error) {
                if(error)
                {
                    NSLog(@"PENDING_MESSAGES_NO_SENT : %@", error);
                    return ;
                }
                NSLog(@"SENT_SUCCESSFULLY....MARKED_AS_DELIVERED : %@", message);
                [[NSNotificationCenter defaultCenter] postNotificationName:@"UPDATE_MESSAGE_SEND_STATUS" object:msg];
            }];
        }
        else if(msg.contentType == ALMESSAGE_CONTENT_VCARD)
        {
            NSLog(@"REACH_PRESENT");
            NSError *THE_ERROR;
            DB_Message *dbMessage = (DB_Message*)[dbService getMeesageById:msg.msgDBObjectId error:&THE_ERROR];
            NSLog(@"ERROR_IF_ANY : %@", THE_ERROR);
            dbMessage.inProgress = [NSNumber numberWithBool:YES];
            dbMessage.isUploadFailed = [NSNumber numberWithBool:NO];
            [[ALDBHandler sharedInstance].managedObjectContext save:nil];
            
            ALMessageClientService * clientService = [ALMessageClientService new];
            NSDictionary *info = [msg dictionary];
            [clientService sendPhotoForUserInfo:info withCompletion:^(NSString *message, NSError *error) {
                
                if(!error)
                {
                    ALMessageService *alMessageService = [ALMessageService new];
                    [ALMessageService proessUploadImageForMessage:msg databaseObj:dbMessage.fileMetaInfo uploadURL:message withdelegate:alMessageService];
                }
            }];
        }
        else
        {
            NSLog(@"FILE_META_PRESENT : %@",msg.fileMeta );
        }
    }
}

+(ALMessage*)getMessagefromKeyValuePair:(NSString*)key andValue:(NSString*)value
{    
    ALMessageDBService * dbService = [[ALMessageDBService alloc]init];
    DB_Message *dbMessage =  (DB_Message*)[dbService getMessageByKey:key value:value];
    return [dbService createMessageEntity:dbMessage];
}

-(void)getMessageInformationWithMessageKey:(NSString *)messageKey withCompletionHandler:(void(^)(ALMessageInfoResponse *msgInfo, NSError *theError))completion
{
    ALMessageClientService *msgClient = [ALMessageClientService new];
    [msgClient getCurrentMessageInformation:messageKey withCompletionHandler:^(ALMessageInfoResponse *msgInfo, NSError *theError) {
        
        if(theError)
        {
            NSLog(@"ERROR IN MSG INFO RESPONSE : %@", theError);
        }
        else
        {
            completion(msgInfo, theError);
        }
    }];
}

+(void)getMessageSENT:(ALMessage*)alMessage  withCompletion:(void (^)( NSMutableArray *, NSError *))completion{
    
    ALMessage * localMessage = [ALMessageService getMessagefromKeyValuePair:@"key" andValue:alMessage.key];
    if(localMessage.key ==  nil){
        [ALMessageService getLatestMessageForUser:[ALUserDefaultsHandler getDeviceKeyString] withCompletion:^(NSMutableArray *message, NSError *error) {
            completion (message,error);
        }];
    }

}
#pragma mark - Multi Receiver API
//================================

+(void)multiUserSendMessage:(ALMessage *)alMessage toContacts:(NSMutableArray*)contactIdsArray toGroups:(NSMutableArray*)channelKeysArray withCompletion:(void(^)(NSString * json, NSError * error)) completion{
    
    [ALUserClientService multiUserSendMessage:[alMessage dictionary] toContacts:contactIdsArray
                                     toGroups:channelKeysArray withCompletion:^(NSString *json, NSError *error) {
        
        if(error)
        {
            NSLog(@"SERVICE_ERROR: Multi User Send Message : %@", error);
        }
        
        completion(json, error);
    }];
}

-(void)connectionDidFinishLoading:(ALConnection *)connection
{
    [[[ALConnectionQueueHandler sharedConnectionQueueHandler] getCurrentConnectionQueue] removeObject:connection];
    ALMessageDBService * dbService = [[ALMessageDBService alloc] init];
    if ([connection.connectionType isEqualToString:@"Image Posting"])
    {
        DB_Message * dbMessage = (DB_Message*)[dbService getMessageByKey:@"key" value:connection.keystring];
        ALMessage * message = [dbService createMessageEntity:dbMessage];
        NSError * theJsonError = nil;
        NSDictionary *theJson = [NSJSONSerialization JSONObjectWithData:connection.mData options:NSJSONReadingMutableLeaves error:&theJsonError];
        NSDictionary *fileInfo = [theJson objectForKey:@"fileMeta"];
        [message.fileMeta populate:fileInfo];
        ALMessage * almessage =  [ALMessageService processFileUploadSucess:message];
        [ALMessageService sendMessages:almessage withCompletion:^(NSString *message, NSError *error) {
            
            if(error)
            {
                NSLog(@"REACH_SEND_ERROR : %@",error);
                return;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:@"UPDATE_MESSAGE_SEND_STATUS" object:almessage];
        }];
    }
}

-(void)connection:(ALConnection *)connection didSendBodyData:(NSInteger)bytesWritten
totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
//    NSLog(@"didSendBodyData..");
}

-(void)connection:(ALConnection *)connection didReceiveData:(NSData *)data
{
    [connection.mData appendData:data];
    if ([connection.connectionType isEqualToString:@"Image Posting"])
    {
        NSLog(@"FILE_POSTING_MSG_SERVICE");
        return;
    }
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSLog(@"OFFLINE_FAILED_TO_UPLOAD : %@", error);
}

@end
