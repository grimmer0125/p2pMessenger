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


#define UIColorFromRGBHexValue(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

//@implementation OGButton
//
//@synthesize name;
//
//@end


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
    PTPusherChannel *colorChannel = [self.pusher subscribeToChannelNamed:@"p2p"];
  
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
      
      [self handleIncomingP2PEvent:event];

      NSLog(@"[pusher] Received p2p event %@", event);
      
    }];
}

- (void)handleIncomingP2PEvent:(PTPusherEvent *)event
{
    //      NSString *tmp = event.data[@"trash"];
//    NSString *eventName= event.name;
    if ([event.name isEqualToString:@"leave"]) {
        
        NSString *leaveName = event.data[@"name"];
        
        if ([self.onlineArray containsObject:leaveName]) {
            [self.onlineArray removeObject:leaveName];
            [self.onlineTableView reloadData];
        }
    }
    else if ([event.name isEqualToString:@"enter"])
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
    else if ([event.name isEqualToString:@"chat"])
    {
        NSString *content = event.data[@"content"];
        NSString *fromName = event.data[@"from"];

        if (self.sentName) {
            
            NSDateFormatter *objDateformat = [[NSDateFormatter alloc] init];
           // [objDateformat setDateFormat:@"yyyy-MM-dd"];
            [objDateformat setDateFormat:@"MM-dd HH:mm:ss"];

            NSString *currentTime = [objDateformat stringFromDate:[NSDate date]];
            
//            NSString *currentTime =[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970] * 1000];

            self.textView.text = [NSString stringWithFormat:@"%@\n%@(%@):%@",self.textView.text,fromName,currentTime, content];
        }
        
//        [self.api triggerEvent:@"chat" onChannel:@"p2p" data:@{@"content": text, @"from": self.sentName} socketID:nil];
        
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

-(void)sendLeaveChatRoom:(NSString*)name
{
    [self.api triggerEvent:@"leave" onChannel:@"p2p" data:@{@"name": name} socketID:nil];
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
    [self.api triggerEvent:@"enter" onChannel:@"p2p" data:@{@"name": name} socketID:nil];
}

-(void)sendText:(NSString*)text
{
    if (self.sentName) {
        [self.api triggerEvent:@"chat" onChannel:@"p2p" data:@{@"content": text, @"from": self.sentName} socketID:nil];
    }
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
    
    if ([cell.textLabel.text isEqualToString:self.sentName]==false)
    {
        cell.detailTextLabel.text = @"p2p disconnected";
//        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        UIButton *p2pBtn=[UIButton buttonWithType:UIButtonTypeRoundedRect];
        [p2pBtn setFrame:CGRectMake(200,5, 120, 40)];
        p2pBtn.tag=indexPath.row;
//        [deletebtn setImage:[UIImage imageNamed:@"log_delete_touch.png"] forState:UIControlStateNormal];
        [p2pBtn setTitle:@"send p2p msg" forState:UIControlStateNormal];
//         [button setTitle:@"Baha'i" forState:UIControlStateNormal]

//        p2pBtn.name = [NSString stringWithFormat:@"%@",cell.textLabel.text];
//        NSString *myData = @"This could be any object type";
////        NSString *myDataKey = @"name";
//        static char myDataKey;
//        objc_setAssociatedObject(p2pBtn, &myDataKey, myData,
//                                  OBJC_ASSOCIATION_RETAIN);
        p2pBtn.accessibilityHint =[NSString stringWithFormat:@"%@",cell.textLabel.text];
        
        [p2pBtn addTarget:self action:@selector(testP2P:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:p2pBtn];
        
    }

    return cell;
    
}

- (void)testP2P:(id)sender
{
    UIButton* p2pButton = (UIButton*)sender;
    NSString  *contactName = p2pButton.accessibilityHint;
    
    NSString *message = nil;

    
    if (inputTextField.text != nil && inputTextField.text.length>0 )
    {
        message = [NSString stringWithFormat:@"%@",inputTextField.text];
        
        //            NSNumber *typenumber = [NSNumber numberWithInt:payLoadType];
        //            [info setObject:typenumber  forKey:C4MI_TYPE];
        //            int mediaType = [[userInfo objectForKey:C4MI_TYPE] intValue];
    }
    
    
    NSMutableDictionary *userDict = [self.userP2PDict objectForKey:contactName];
    NSString *holePunchingID = [NSString stringWithFormat:@"%@;msg",contactName];

    if (userDict)
    {
        //把status重設,
        //reload
        //把前一個socket關掉, 建新的,
        


        mk_closeSock([holePunchingID UTF8String]);
        
        
//        1. call誰, sessionID: targetName+type, 裡面存id vs 一堆東西
//        2. 從server返回 socket跟public ip, 傳到這裡public ip 跟sessionID, 丟給對方
//        3. 對方收到是誰要call我, 也去跟server溝通, 溝通完, 再丟回去, 同時hole punching
        
    }
    else
    {
        userDict = [NSMutableDictionary dictionary];
        
    }
    
    NSNumber *statusnumber = [NSNumber numberWithInt:P2P_WAITTING];
    [userDict setObject:statusnumber forKey:KEY_P2PSTATUS];
    
    mk_createSock([holePunchingID UTF8String]);

    
    [userDict setObject:message forKey:KEY_MESSAGE];
    
    [self.onlineTableView reloadData];

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

//- (void)viewDidDisappear:(BOOL)animated
//{
//}


@end
