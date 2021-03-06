//
//  ViewController.h
//  ChatApp
//
//  Copyright (c) 2015 AppLozic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ALChatViewController.h"
#import "ALContactCell.h"


@interface ALMessagesViewController : UIViewController

@property(nonatomic,strong) ALChatViewController * detailChatViewController;

-(void)createDetailChatViewController: (NSString *) contactIds;

-(void) syncCall:(ALMessage *) alMessage andMessageList:(NSMutableArray *)messageArray;

-(void)pushNotificationhandler:(NSNotification *) notification;

-(void)displayAttachmentMediaType:(ALMessage *)message andContactCell:(ALContactCell *)contactCell;

@property (weak, nonatomic) IBOutlet UITableView *mTableView;

-(UIView *)setCustomBackButton:(NSString *)text;

-(void)createAndLaunchChatView;

-(void) callLastSeenStatusUpdate;

@property (strong, nonatomic) NSString * userIdToLaunch;
@property (strong, nonatomic) NSNumber *channelKey;
@property (strong, nonatomic) NSNumber * conversationId;

@end

