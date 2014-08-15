//
//  ReactiveEventsViewController.m
//  libPusher
//
//  Created by Luke Redpath on 27/11/2013.
//
//

#import "ReactiveEventsViewController.h"
#import "PTPusherAPI.h"
#import "Constants.h"
#import "Pusher.h"
#import "PTPusherChannel+ReactiveExtensions.h"

#import "JSBadgeView.h"



#define UIColorFromRGBHexValue(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

//@implementation OGButton
//
//@synthesize name;
//
//@end

void runOnMainQueue(void(^block)(void))
{
    if([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}



@interface ReactiveEventsViewController ()
@property (nonatomic, weak) IBOutlet UITextField *textField;
@property (nonatomic, strong) PTPusherAPI *api;
@end

@implementation ReactiveEventsViewController


@synthesize nameField, inputTextField, textView, onlineTableView;
@synthesize  sentName;

- (void)viewDidLoad
{
    [super viewDidLoad];
  
    self.api = [[PTPusherAPI alloc] initWithKey:PUSHER_API_KEY appID:PUSHER_APP_ID secretKey:PUSHER_API_SECRET];
    
    
    self.onlineArray = [NSMutableArray array];
    
    self.userP2PDict = [NSMutableDictionary dictionary];
    
    // subscribe to the channel
    PTPusherChannel *colorChannel = [self.pusher subscribeToChannelNamed:PUSHER_CHANNEL];
  
  // Create a signal by mapping a channel events to a UIColor, converting the color string then a UIColor value
//  RACSignal *colorSignal = [[colorChannel eventsOfType:@"color"] map:^id(PTPusherEvent *event) {
//    NSScanner *scanner = [NSScanner scannerWithString:event.data[@"color"]];
//    unsigned long long hexValue;
//    [scanner scanHexLongLong:&hexValue];
//    return UIColorFromRGBHexValue(hexValue);
//  }];
//  
//  // Bind the view's background color to colors as the arrivecol
//  RAC(self.view, backgroundColor) = colorSignal;
  
  
  // log all events received on the channel using the allEvents signal
    [[[colorChannel allEvents] takeUntil:[self rac_willDeallocSignal]] subscribeNext:^(PTPusherEvent *event) {
      
      [self handleIncomingPusherEvent:event];

      NSLog(@"[pusher] Received p2p event %@", event);
      
    }];
}

- (void)handleIncomingPusherEvent:(PTPusherEvent *)event
{
    //      NSString *tmp = event.data[@"trash"];
//    NSString *eventName= event.name;
    if ([event.name isEqualToString:PUSHER_EVENT_LEAVE]) {
        
        NSString *leaveName = event.data[@"name"];
        
        if ([self.onlineArray containsObject:leaveName]) {
            [self.onlineArray removeObject:leaveName];
            [self.onlineTableView reloadData];
        }
    }
    else if ([event.name isEqualToString:PUSHER_EVENT_ENTER])
    {
        NSString *enterName = event.data[@"name"];

        if (enterName) {

            if ([self.onlineArray containsObject:enterName]==false)
            {
                if ([enterName isEqualToString:self.sentName]==false) {
                    [self sendEnterChatRoom:self.sentName];
                }

                //add
                [self.onlineArray addObject:enterName];
                [self.onlineTableView reloadData];
            }
        }
    }
    else if ([event.name isEqualToString:PUSHER_EVENT_CHAT])
    {
        NSString *content = event.data[PUSHER_DATA_CONTENT];
        NSString *fromName = event.data[PUSHER_DATA_FROM];

        if (self.sentName) {
            
            NSDateFormatter *objDateformat = [[NSDateFormatter alloc] init];
           // [objDateformat setDateFormat:@"yyyy-MM-dd"];
            [objDateformat setDateFormat:@"MM-dd HH:mm:ss"];

            NSString *currentTime = [objDateformat stringFromDate:[NSDate date]];
            
//            NSString *currentTime =[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970] * 1000];

            self.textView.text = [NSString stringWithFormat:@"%@\n%@(%@):%@",self.textView.text,fromName,currentTime, content];
            
//            CGPoint p = [self.textView contentOffset];
//            [self.textView setContentOffset:p animated:NO];
            [self.textView scrollRangeToVisible:NSMakeRange([self.textView.text length], 0)];
        }
        
//        [self.api triggerEvent:@"chat" onChannel:@"p2p" data:@{@"content": text, @"from": self.sentName} socketID:nil];
        
    }
    else if ([event.name isEqualToString:PUSHER_EVENT_P2P_INVITE])
    {
        NSString *toName = event.data[PUSHER_DATA_TO];
        if ([toName isEqualToString:self.sentName]==false) {
            return;
        }
        
        NSString *fromName = event.data[PUSHER_DATA_FROM];
        NSString *mappedIP = event.data[PUSHER_DATA_MAPPEDIP];
        NSString *mappedPort = event.data[PUSHER_DATA_MAPPEDPORT];
        NSString *localIP = event.data[PUSHER_DATA_LOCALIP];
        NSString *localPort = event.data[PUSHER_DATA_LOCALPORT];

        [self mk_receiveInvite:fromName mappedIP:mappedIP mappedPort:mappedPort localIP:localIP localPort:localPort];
        
    }
    else if ([event.name isEqualToString:PUSHER_EVENT_P2P_INVITE_RESPONSE])
    {
        NSString *toName = event.data[PUSHER_DATA_TO];
        if ([toName isEqualToString:self.sentName]==false) {
            return;
        }
        
        NSString *fromName = event.data[PUSHER_DATA_FROM];
        NSString *mappedIP = event.data[PUSHER_DATA_MAPPEDIP];
        NSString *mappedPort = event.data[PUSHER_DATA_MAPPEDPORT];
        NSString *localIP = event.data[PUSHER_DATA_LOCALIP];
        NSString *localPort = event.data[PUSHER_DATA_LOCALPORT];
        
        [self mk_receiveInviteResponse:fromName mappedIP:mappedIP mappedPort:mappedPort localIP:localIP localPort:localPort];
    }
    else if ([event.name isEqualToString:PUSHER_EVENT_P2P_CLOSE])
    {
        NSString *toName = event.data[PUSHER_DATA_TO];
        if ([toName isEqualToString:self.sentName]==false) {
            return;
        }
        
        NSString *fromName = event.data[PUSHER_DATA_FROM];

        [self mk_receiveCloseSession:fromName];
    }
}

//- (IBAction)tappedSendButton:(id)sender
//{
  // we set the socket ID to nil here as we want to receive our own events
//  [self.api triggerEvent:@"color" onChannel:@"p2p" data:@{@"color": self.textField.text, @"trash": @"123"} socketID:nil];    
//}

- (IBAction)changeNamePress:(id)sender;
{
    [self hideKeyboard];

    if (nameField.text != nil && nameField.text.length > 0){// && [nameField.text isEqualToString:self.sentName]==false) {
        
        if (self.sentName!=nil) {
            [self sendLeaveChatRoom:self.sentName];
        }
        
        [self sendEnterChatRoom:nameField.text];
        
        self.sentName = [NSString stringWithFormat:@"%@",nameField.text];
    }
}



- (IBAction)sendTextPress:(id)sender
{
    [self hideKeyboard];

    if (inputTextField.text != nil && inputTextField.text.length>0 )
    {
        [self sendText:inputTextField.text];
    }
}

-(void)sendEnterChatRoom:(NSString*)name
{
    if (name==nil) {
        return;
    }
    
    //同時也變成上線
    [self.api triggerEvent:PUSHER_EVENT_ENTER onChannel:PUSHER_CHANNEL data:@{PUSHER_DATA_NAME: name} socketID:nil];
}

-(void)sendText:(NSString*)text
{
    if (self.sentName) {
        [self.api triggerEvent:PUSHER_EVENT_CHAT onChannel:PUSHER_CHANNEL data:@{PUSHER_DATA_CONTENT: text, PUSHER_DATA_FROM: self.sentName} socketID:nil];
    }
}

-(void)sendLeaveChatRoom:(NSString*)name
{
    [self.api triggerEvent:PUSHER_EVENT_LEAVE onChannel:PUSHER_CHANNEL data:@{PUSHER_DATA_NAME: name} socketID:nil];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    //must more or equal than the maximal section index in the self.foldableDataArray
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
//    int count =3; //including "OPU","START","END"
    
    
    if (self.onlineArray) {
        return self.onlineArray.count;
    }
    
    return 0;
    
//    count+=[self numberOfExpandedRowForSection:section];
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self hideKeyboard];
    return YES;
}

- (void)touchesEnded: (NSSet *)touches withEvent: (UIEvent *)event
{
    [self hideKeyboard];
}

- (void)hideKeyboard
{
    if([self.inputTextField isFirstResponder])
    {
        [self.inputTextField resignFirstResponder];
    }
    if([self.nameField isFirstResponder])
    {
        [self.nameField resignFirstResponder];
    }
}

- (int)tryGetSuccessCount:(NSString*)remotename
{
    NSString *holePunchingID = [NSString stringWithFormat:@"%@;msg",remotename];
    
    NSMutableDictionary *userDict = [self.userP2PDict objectForKey:holePunchingID];
    
    if (userDict)
    {
        int count = [[userDict objectForKey:KEY_P2PSUCCESSCOUNT] intValue];
        
        return count;
    }
    else
    {
        return 0;
    }
}

- (int)tryGetTryCount:(NSString*)remotename
{
    NSString *holePunchingID = [NSString stringWithFormat:@"%@;msg",remotename];
    
    NSMutableDictionary *userDict = [self.userP2PDict objectForKey:holePunchingID];
    
    if (userDict)
    {
        int tryCount = [[userDict objectForKey:KEY_P2PTRYCOUNT] intValue];

        return tryCount;
    }
    else
    {
        return 0;
    }
}

- (NSString*)tryGetStatusText:(NSString*)remotename
{
    NSString *holePunchingID = [NSString stringWithFormat:@"%@;msg",remotename];
    
    NSMutableDictionary *userDict = [self.userP2PDict objectForKey:holePunchingID];

    if (userDict) {
        int statusCode = [[userDict objectForKey:KEY_P2PSTATUS] intValue];

        NSString *statusStr= nil;
        switch (statusCode) {
            case P2P_NONE:
                return nil;
                break;
            case P2P_ACTIVE_WAITING_RESPONSE:
                statusStr = [NSString stringWithFormat:@"P2P_ACTIVE_WAITING_RESPONSE"];
                break;
            case P2P_ACTIVE_SENDING_INVITE:
                statusStr = [NSString stringWithFormat:@"P2P_ACTIVE_SENDING_INVITE"];
                break;
            case P2P_ACTIVE_HOLE_PUNCHING:
                statusStr = [NSString stringWithFormat:@"P2P_ACTIVE_HOLE_PUNCHING"];
                break;
            case P2P_PASSIVE_WAITING_RESPONSE:
                statusStr = [NSString stringWithFormat:@"P2P_PASSIVE_WAITING_RESPONSE"];
                break;
            case P2P_PASSIVE_HOLE_PUNCHING:
                statusStr = [NSString stringWithFormat:@"P2P_PASSIVE_HOLE_PUNCHING"];
                break;
            case P2P_SUCCESS:
                statusStr = [NSString stringWithFormat:@"P2P_SUCCESS"];
                break;
            case P2P_FAIL:
                statusStr = [NSString stringWithFormat:@"P2P_FAIL"];
                break;
                
            default:
                break;
        }
        
        return statusStr;
    }
    else
    {
        return nil;
    }
    

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    NSString *cellID = nil;
    
    cellID = @"nameID";
    
    cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell==nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
    }
    
    cell.textLabel.text = [self.onlineArray objectAtIndex:indexPath.row];
    
    if (true)//[cell.textLabel.text isEqualToString:self.sentName]==false)
    {
        cell.detailTextLabel.text = [self tryGetStatusText:cell.textLabel.text];//@"p2p disconnected";

        int tryCount = [self tryGetTryCount:cell.textLabel.text];
        NSString *tryCountStr = [NSString stringWithFormat:@"%d",tryCount];
        JSBadgeView *badge =  (JSBadgeView *)[cell.contentView viewWithTag:2];
        if (!badge) {
            
            badge = [[JSBadgeView alloc] initWithParentView:cell.contentView alignment:JSBadgeViewAlignmentCenterLeft];
            
            [badge setTag:2];
        }
        int size = [tryCountStr sizeWithFont:[UIFont systemFontOfSize:17.0]].width;
        CGPoint shiftPoint = CGPointMake(size+180,0);
        [badge setBadgePositionAdjustment:shiftPoint];
        badge.badgeText = tryCountStr;

        int successCount = [self tryGetSuccessCount:cell.textLabel.text];
        NSString *trySuccessStr = [NSString stringWithFormat:@"%d",successCount];
        JSBadgeView *badge3 =  (JSBadgeView *)[cell.contentView viewWithTag:3];

        if (!badge3) {
            
            badge3 = [[JSBadgeView alloc] initWithParentView:cell.contentView alignment:JSBadgeViewAlignmentCenterLeft];
//            [badge3 setTintColor:[UIColor purpleColor]];
//            [badge3 setBadgeShadowColor:[UIColor yellowColor]];
//            [badge3 setBadgeStrokeColor:[UIColor blueColor]];
            [badge3 setBadgeTextColor:[UIColor purpleColor]];
//            [badge3 setBackgroundColor:[UIColor blackColor]];
//            [badge3 setBadgeTextShadowColor:[UIColor blackColor]];
//            [badge3 setBadgeOverlayColor:[UIColor blackColor]];
            [badge3 setTag:3];
        }
        int size3 = [trySuccessStr sizeWithFont:[UIFont systemFontOfSize:17.0]].width;
        CGPoint shiftPoint3 = CGPointMake(size3+155,0);
        [badge3 setBadgePositionAdjustment:shiftPoint3];
        badge3.badgeText = trySuccessStr;
        
        
        UIButton *p2pBtn=[UIButton buttonWithType:UIButtonTypeRoundedRect];
        [p2pBtn setFrame:CGRectMake(200,5, 120, 40)];
        p2pBtn.tag=indexPath.row;
        [p2pBtn setTitle:@"send p2p msg" forState:UIControlStateNormal];

        p2pBtn.accessibilityHint =[NSString stringWithFormat:@"%@",cell.textLabel.text];
        
        [p2pBtn addTarget:self action:@selector(mk_start_stun_msg:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:p2pBtn];
        
    }

    return cell;
    
}

// p2p thread
void mk_punching_result(const char* hole_punching_id, pj_status_t status,void *user_data)
{
    
    NSString *holePunchingID= [NSString stringWithUTF8String:hole_punching_id];

//    NSString *holePunchingID = [NSString stringWithFormat:@"%@;msg",remotename];
    
    ReactiveEventsViewController *selfController = (__bridge ReactiveEventsViewController*)user_data;
    
    NSMutableDictionary *userDict = [selfController.userP2PDict objectForKey:holePunchingID];
    
    if (userDict==nil) {
        return; //應該不會發生,
    }
    
    if (status ==PJ_SUCCESS) {
        
        //hanlde success
        int successCount = [[userDict objectForKey:KEY_P2PSUCCESSCOUNT] intValue];
        
        successCount++;
        
        NSNumber *successNewNum = [NSNumber numberWithInt:successCount];
        [userDict setObject:successNewNum forKey:KEY_P2PSUCCESSCOUNT];
        
        NSLog(@"set success ++");

        
        NSString *message = [userDict objectForKey:KEY_MESSAGE];
        
        NSNumber *statusnumber = [NSNumber numberWithInt:P2P_SUCCESS];
        [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
        
//        if (message)
//        {
            //send remaining p2p message

        const char *sentdata= [message UTF8String];
        
        [userDict removeObjectForKey:KEY_MESSAGE];

        runOnMainQueue( ^{

            mk_sendata(hole_punching_id, sentdata, message.length);
            
            [selfController.onlineTableView reloadData];

        });
//        }
        
        
    }
    else
    {
        //fail ?? maybe timeout
        
    }
    
//    runOnMainQueue( ^{
//        [selfController.onlineTableView reloadData];
//    });
    
    
//    if (userDict)
//    {
//        int tryCount = [[userDict objectForKey:KEY_P2PTRYCOUNT] intValue];
//        
//        return tryCount;
//    }
//    else
//    {
//        
//        
//        
//        if ([userDict objectForKey:KEY_P2PTRYCOUNT]) {
//            int tryCount = [[userDict objectForKey:KEY_P2PTRYCOUNT] intValue];
//            tryCount++;
//            NSNumber *tryCountNewNum = [NSNumber numberWithInt:tryCount];
//            [userDict setObject:tryCountNewNum forKey:KEY_P2PTRYCOUNT];

    
}

// p2p thread
void mk_receive_data(const char* hole_punching_id, unsigned char *data, int datalen, void *user_data)
{
    //convert to string and append in the textfield
//    NSString *content = event.data[PUSHER_DATA_CONTENT];
//    NSString *fromName = event.data[PUSHER_DATA_FROM];
    
    NSString *holePunchingID= [NSString stringWithUTF8String:hole_punching_id];

    ReactiveEventsViewController *selfController = (__bridge ReactiveEventsViewController*)user_data;
    
    NSMutableDictionary *userDict = [selfController.userP2PDict objectForKey:holePunchingID];
    
    if (userDict==nil) {
        return; //應該不會發生,
    }
    
    if (selfController.sentName) {
        
        NSString *content = [NSString stringWithUTF8String:(char*)data];
        
        runOnMainQueue( ^{

            selfController.textView.text = [NSString stringWithFormat:@"%@\n%@",selfController.textView.text,content];
            
            //            CGPoint p = [self.textView contentOffset];
            //            [self.textView setContentOffset:p animated:NO];
            [selfController.textView scrollRangeToVisible:NSMakeRange([selfController.textView.text length], 0)];
        });        
    }
}

// p2p thread
void mk_binding_result(const char* hole_punching_id,
                       char *mapp_addr,
                       char *local_addr,
                       pj_status_t status, void *inUserData)
{
    printf("in %s\n", __func__);
 
    NSString *holePunchingID= [NSString stringWithUTF8String:hole_punching_id];
    
    ReactiveEventsViewController *selfController = (__bridge ReactiveEventsViewController*)inUserData;
    
    NSMutableDictionary *userDict = [selfController.userP2PDict objectForKey:holePunchingID];

    if (userDict==nil) {
        return; //應該不會發生,
    }
    
    int statusCode= [[userDict objectForKey:KEY_P2PSTATUS] intValue];

    NSArray *nameItems = [holePunchingID componentsSeparatedByString:@";"];
    NSString *remoteName=nil;
    if (nameItems.count>0) {
        remoteName = [nameItems objectAtIndex:0];
    }
    
    NSString *mappAddr = [NSString stringWithUTF8String:mapp_addr];
    NSArray *mapAddrItems = [mappAddr componentsSeparatedByString:@":"];
    NSString *mapIp=nil;
    NSString *mapPort=nil;
    if (mapAddrItems.count>1) {
        mapIp = [mapAddrItems objectAtIndex:0];
        mapPort = [mapAddrItems objectAtIndex:1];
    }
    
    NSString *localAddr = [NSString stringWithUTF8String:local_addr];
    NSArray *localAddrItems = [localAddr componentsSeparatedByString:@":"];
    NSString *localIp=nil;
    NSString *localPort=nil;
    
    if (localAddrItems.count>1) {
        localIp = [localAddrItems objectAtIndex:0];
        localPort = [localAddrItems objectAtIndex:1];
    }
    
    if (status == PJ_SUCCESS)
    {
//        [userDict setObject:mapIp forKey:KEY_SELFMAPIP];
        
        if (statusCode == P2P_ACTIVE_WAITING_RESPONSE) {
            
            //發invite給對方
            if (remoteName && mapIp && mapPort && localIp && localPort) {
                [selfController mk_sendInvite:remoteName mappedIP:mapIp mappedPort:mapPort localIP:localIp localPort:localPort];
            }
            
            NSNumber *statusnumber = [NSNumber numberWithInt:P2P_ACTIVE_SENDING_INVITE];
            [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
        }
        else if (statusCode==P2P_PASSIVE_WAITING_RESPONSE)
        {
            //發invite response給對方
            if (remoteName && mapIp && mapPort && localIp && localPort) {
                [selfController mk_sendInviteResponse:remoteName mappedIP:mapIp mappedPort:mapPort localIP:localIp localPort:localPort];
            }
            
            NSNumber *statusnumber = [NSNumber numberWithInt:P2P_PASSIVE_HOLE_PUNCHING];
            [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];

            NSString *remotemapIP = [userDict objectForKey:KEY_REMOTEMAPIP];
            NSString *remotemapPort = [userDict objectForKey:KEY_REMOTEMAPPORT];
            
            NSString *remotelocalIP = [userDict objectForKey:KEY_REMOTELOCALIP];
            NSString *remotelocalPort = [userDict objectForKey:KEY_REMOTELOCALPORT];
            
            if (remotemapIP && remotemapPort && remotelocalIP && remotelocalPort) {
                //開始hole punching
                
                runOnMainQueue( ^{

                    mk_start_hole_punching(hole_punching_id, [remotemapIP UTF8String],[remotemapPort intValue],[remotelocalIP UTF8String],[remotelocalPort intValue],   mk_punching_result,  inUserData);
                });
            }

        }
    }
    else
    {
        NSNumber *statusnumber = [NSNumber numberWithInt:P2P_FAIL];
        [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
        
        //1. 關掉
        
        runOnMainQueue( ^{
            mk_close_sock([holePunchingID UTF8String]);
        });

        if (statusCode == P2P_PASSIVE_WAITING_RESPONSE) {
            
            //2. 如果對方invite過, 發close
            if (remoteName) {
                [selfController mk_sendCloseSession:remoteName];
            }

        }
    }
    
    runOnMainQueue( ^{
        [selfController.onlineTableView reloadData];
    });
    
    return;
    
}

- (void)mk_sendInvite:(NSString*)remotename mappedIP:(NSString*)mappedIP mappedPort:(NSString*)mappedPort localIP:(NSString*)localIP localPort:(NSString*)localPort
{
    if (self.sentName) {
        
        [self.api triggerEvent:PUSHER_EVENT_P2P_INVITE onChannel:PUSHER_CHANNEL data:@{PUSHER_DATA_FROM:self.sentName, PUSHER_DATA_TO:remotename,
                      PUSHER_DATA_MAPPEDIP:mappedIP,
                      PUSHER_DATA_MAPPEDPORT:mappedPort,
                      PUSHER_DATA_LOCALIP:localIP,
                      PUSHER_DATA_LOCALPORT:localPort                                                                                       } socketID:nil];

    }
}

- (void)mk_receiveInvite:(NSString*)remotename mappedIP:(NSString*)mappedIP mappedPort:(NSString*)mappedPort localIP:(NSString*)localIP localPort:(NSString*)localPort
{
    NSString *holePunchingID = [NSString stringWithFormat:@"%@;msg",remotename];
    
    NSMutableDictionary *userDict = [self.userP2PDict objectForKey:holePunchingID];
    
    if (userDict ==nil) {

        userDict = [NSMutableDictionary dictionary];
        [self.userP2PDict setObject:userDict forKey:holePunchingID];
        
        NSNumber *statusnumber = [NSNumber numberWithInt:P2P_NONE];
        [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
    }
    
    int statusCode = [[userDict objectForKey:KEY_P2PSTATUS] intValue];

    if (statusCode == P2P_NONE ||
        statusCode == P2P_FAIL ||
        statusCode == P2P_SUCCESS) //success 可能是對方沒send close上一次的
    {
        NSNumber *statusnumber = [NSNumber numberWithInt:P2P_PASSIVE_WAITING_RESPONSE];
        [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
        
        NSString *message = nil;
        
        NSDateFormatter *objDateformat = [[NSDateFormatter alloc] init];
        [objDateformat setDateFormat:@"MM-dd HH:mm:ss"];
        NSString *currentTime = [objDateformat stringFromDate:[NSDate date]];
        
//        if (inputTextField.text != nil && inputTextField.text.length>0 )
//        {
//            message = [NSString stringWithFormat:@"%@(%@,P2P):%@",self.sentName,currentTime, inputTextField.text];
//        }
//        else
//        {
        message = [NSString stringWithFormat:@"%@(%@,P2P):default reply",self.sentName,currentTime];
//        }
        
        if (statusCode !=P2P_NONE) {
            mk_close_sock([holePunchingID UTF8String]);
        }
        
    //    try binding
        [self mk_start_stun_binding:message userDict:userDict holePunchingID:holePunchingID];
        
        [userDict setObject:mappedIP forKey:KEY_REMOTEMAPIP];
        [userDict setObject:mappedPort forKey:KEY_REMOTEMAPPORT];
        [userDict setObject:localIP forKey:KEY_REMOTELOCALIP];
        [userDict setObject:localPort forKey:KEY_REMOTELOCALPORT];

    }
    else if (statusCode == P2P_ACTIVE_WAITING_RESPONSE)
    {
        NSNumber *statusnumber = [NSNumber numberWithInt:P2P_PASSIVE_WAITING_RESPONSE];
        [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
    }
    else if (statusCode == P2P_PASSIVE_WAITING_RESPONSE)
    {
        //可能對方重複invite, 先ignore
    }
    else if (statusCode == P2P_PASSIVE_HOLE_PUNCHING) //也可能是對方發起新的了!!
    {
        //對方inviter沒收到reponse? 再reponse 一次? 但就要記得自己的ip資訊了
    }
    else if (statusCode == P2P_ACTIVE_SENDING_INVITE)
    {
        //兩邊同時invite, 送ip等info在invite_reponse回去, 要記得自己的ip資訊

        //直接變active hole punching
    }
    else if (statusCode == P2P_ACTIVE_HOLE_PUNCHING)
    {
        //ignore, 某些步驟跳太多了
        
        //但有可能左邊還在active_hole_punching時,  右邊發起新的invite(兩次發起的人不同) !!! 碰到了,左邊公司網路一直沒有送upd包到中華電信另一個區網(右邊)
    }
    
    runOnMainQueue( ^{
        [self.onlineTableView reloadData];
    });
}

- (void)mk_sendInviteResponse:(NSString*)remotename mappedIP:(NSString*)mappedIP mappedPort:(NSString*)mappedPort localIP:(NSString*)localIP localPort:(NSString*)localPort
{
    if (self.sentName) {
        
        [self.api triggerEvent:PUSHER_EVENT_P2P_INVITE_RESPONSE onChannel:PUSHER_CHANNEL data:@{PUSHER_DATA_FROM:self.sentName, PUSHER_DATA_TO:remotename,
                    PUSHER_DATA_MAPPEDIP:mappedIP,
                   PUSHER_DATA_MAPPEDPORT:mappedPort,
                 PUSHER_DATA_LOCALIP:localIP,
                   PUSHER_DATA_LOCALPORT:localPort                                                                                       } socketID:nil];
        
    }
}

- (void)mk_receiveInviteResponse:(NSString*)remotename mappedIP:(NSString*)mappedIP mappedPort:(NSString*)mappedPort localIP:(NSString*)localIP localPort:(NSString*)localPort
{
    NSString *holePunchingID = [NSString stringWithFormat:@"%@;msg",remotename];
    
    NSMutableDictionary *userDict = [self.userP2PDict objectForKey:holePunchingID];
    if (userDict==nil) {
        return; //應不會發生
    }
    
    int statusCode = [[userDict objectForKey:KEY_P2PSTATUS] intValue];

    if (statusCode ==P2P_ACTIVE_SENDING_INVITE) {
        
        NSNumber *statusnumber = [NSNumber numberWithInt:P2P_ACTIVE_HOLE_PUNCHING];
        [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
        
        runOnMainQueue( ^{
            [self.onlineTableView reloadData];
        });
        
//        NSString *remotemapIP = [userDict objectForKey:KEY_REMOTEMAPIP];
//        NSString *remotemapPort = [userDict objectForKey:KEY_REMOTEMAPPORT];
//        
//        NSString *remotelocalIP = [userDict objectForKey:KEY_REMOTELOCALIP];
//        NSString *remotelocalPort = [userDict objectForKey:KEY_REMOTELOCALPORT];
//
//        NSString *self_mapIP =[userDict objectForKey:KEY_SELFMAPIP];
        
        if (mappedIP && mappedPort && localIP && localPort) {
            //開始hole punching
            mk_start_hole_punching([holePunchingID UTF8String],[mappedIP UTF8String],[mappedPort       intValue],[localIP UTF8String],[localPort intValue], mk_punching_result, (__bridge void *)(self));
        }
    }
}

- (void)mk_sendCloseSession:(NSString*)remotename
{
    if (self.sentName) {
        [self.api triggerEvent:PUSHER_EVENT_P2P_CLOSE onChannel:PUSHER_CHANNEL data:@{PUSHER_DATA_FROM:self.sentName, PUSHER_DATA_TO:remotename                                                                                      } socketID:nil];
    }
}

- (void)mk_receiveCloseSession:(NSString*)remotename
{
    NSString *holePunchingID = [NSString stringWithFormat:@"%@;msg",remotename];
    
    NSMutableDictionary *userDict = [self.userP2PDict objectForKey:holePunchingID];

    if (userDict) {
        NSNumber *statusnumber = [NSNumber numberWithInt:P2P_FAIL];
        [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
    }
    
    runOnMainQueue( ^{
        [self.onlineTableView reloadData];
    });
    
    mk_close_sock([holePunchingID UTF8String]);
}



- (void)mk_start_stun_msg:(id)sender
{
//    static int kk = 0;
//    
//    kk++;
//    
//    if (kk==1) {
//        test_startTimer();
//    }
//    else
//    {
//        test_stopTimer();
//    }
//    
//    return;
    
    
    UIButton* p2pButton = (UIButton*)sender;
    NSString  *remoteName = p2pButton.accessibilityHint;
    
    NSString *message = nil;
    
    NSDateFormatter *objDateformat = [[NSDateFormatter alloc] init];
    [objDateformat setDateFormat:@"MM-dd HH:mm:ss"];
    NSString *currentTime = [objDateformat stringFromDate:[NSDate date]];
    
    if (inputTextField.text != nil && inputTextField.text.length>0 )
    {
//        self.textView.text = [NSString stringWithFormat:@"%@\n%@(%@):%@",self.textView.text,fromName, currentTime, content];
        
        message = [NSString stringWithFormat:@"%@(%@,P2P):%@",self.sentName,currentTime, inputTextField.text];
    }
    else
    {
        message = [NSString stringWithFormat:@"%@(%@,P2P):default msg",self.sentName,currentTime];
    }

    NSString *holePunchingID = [NSString stringWithFormat:@"%@;msg",remoteName];

    NSMutableDictionary *userDict = [self.userP2PDict objectForKey:holePunchingID];

    
    //        1. call誰, sessionID: targetName+type, 裡面存id, 一堆東西
    //        2. 從server返回 socket跟public ip, 傳到這裡public ip 跟sessionID, 丟給對方
    //        3. 對方收到是誰要call我, 也去跟server溝通, 溝通完, 再丟回去, 同時hole punching
    
    
    if (userDict==nil)
    {
        userDict = [NSMutableDictionary dictionary];
        [self.userP2PDict setObject:userDict forKey:holePunchingID];
        
        NSNumber *statusnumber = [NSNumber numberWithInt:P2P_NONE];
        [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
    }
    
    int statusCode = [[userDict objectForKey:KEY_P2PSTATUS] intValue];
    
    BOOL needHolePunching = false;
    
    if (statusCode==P2P_NONE)
    {
        needHolePunching=true;
    }
    else if (statusCode==P2P_PASSIVE_WAITING_RESPONSE) //假設這兩個都做很快且幾乎都成功,可不中斷重試, 等到他們成功
    {
        //do nothing
    }
    else if (statusCode == P2P_ACTIVE_WAITING_RESPONSE)
    {
        //do nothing
    }
    else if (statusCode == P2P_ACTIVE_SENDING_INVITE ||
             statusCode == P2P_ACTIVE_HOLE_PUNCHING ||
             statusCode == P2P_PASSIVE_HOLE_PUNCHING ||
             statusCode == P2P_SUCCESS ||
             statusCode == P2P_FAIL)
    {
        mk_close_sock([holePunchingID UTF8String]);
        
        needHolePunching=true;
    }
    
    if(needHolePunching)
    {
        NSNumber *statusnumber = [NSNumber numberWithInt:P2P_ACTIVE_WAITING_RESPONSE];
        [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];

        [self mk_start_stun_binding:message userDict:userDict holePunchingID:holePunchingID];
        
//        if ([userDict objectForKey:KEY_P2PTRYCOUNT]) {
//            int tryCount = [[userDict objectForKey:KEY_P2PTRYCOUNT] intValue];
//            tryCount++;
//            NSNumber *tryCountNewNum = [NSNumber numberWithInt:tryCount];
//            [userDict setObject:tryCountNewNum forKey:KEY_P2PTRYCOUNT];
//        }
//        else
//        {
//            int tryCount = 1;
//            NSNumber *tryCountNewNum = [NSNumber numberWithInt:tryCount];
//            [userDict setObject:tryCountNewNum forKey:KEY_P2PTRYCOUNT];
//        }
//        
//        [userDict setObject:message forKey:KEY_MESSAGE];
//        
//        ///由沒有得過對方的ip判斷現在要幹嘛<-改用status, ui層判斷, 但還是刪好了
//        [userDict removeObjectForKey:KEY_REMOTEIP];
//        [userDict removeObjectForKey:KEY_REMOTEPORT];
//        
//        mk_create_sock([holePunchingID UTF8String],mk_binding_result, (__bridge void *)(self));
    }
    
    [self.onlineTableView reloadData];

}

- (void)mk_start_stun_binding:(NSString*)message userDict:(NSMutableDictionary*)userDict holePunchingID:(NSString*)holePunchingID
{
    if ([userDict objectForKey:KEY_P2PTRYCOUNT]) {
        int tryCount = [[userDict objectForKey:KEY_P2PTRYCOUNT] intValue];
        tryCount++;
        NSNumber *tryCountNewNum = [NSNumber numberWithInt:tryCount];
        [userDict setObject:tryCountNewNum forKey:KEY_P2PTRYCOUNT];
    }
    else
    {
        int tryCount = 1;
        NSNumber *tryCountNewNum = [NSNumber numberWithInt:tryCount];
        [userDict setObject:tryCountNewNum forKey:KEY_P2PTRYCOUNT];
        
        int successCount = 0;
        NSNumber *successNewNum = [NSNumber numberWithInt:successCount];
        [userDict setObject:successNewNum forKey:KEY_P2PSUCCESSCOUNT];
        
        NSLog(@"set success = 0");
    }
    
    [userDict setObject:message forKey:KEY_MESSAGE];
    
    ///由沒有得過對方的ip判斷現在要幹嘛<-改用status, ui層判斷, 但還是刪好了
//    [userDict removeObjectForKey:KEY_SELFMAPIP];
//    [userDict removeObjectForKey:KEY_REMOTEMAPIP];
//    [userDict removeObjectForKey:KEY_REMOTEMAPPORT];
//    [userDict removeObjectForKey:KEY_REMOTELOCALIP];
//    [userDict removeObjectForKey:KEY_REMOTELOCALPORT];
    
    mk_create_sock([holePunchingID UTF8String],mk_binding_result, mk_receive_data, (__bridge void *)(self));
}

//-(void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
//{
//    int kkk=0;
//}


//- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    
//}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    if (self.sentName) {
        
        //清空
        [self sendLeaveChatRoom:self.sentName];
        self.sentName =nil;
        self.nameField.text =nil;
    }
    
    
}


- (void)dealloc
{
//    int kkk=0;
}


@end
