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

      NSLog(@"[pusher] Received color event %@", event);
      
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
            if ([enterName isEqualToString:self.sentName]) {
                return;
            }
            else if ([self.onlineArray containsObject:enterName]==false)
            {
                [self sendEnterChatRoom:self.sentName];

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
            self.textView.text = [NSString stringWithFormat:@"%@\n%@:%@",self.textView.text,fromName,content];
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

    if (nameField.text != nil && nameField.text.length > 0 && [nameField.text isEqualToString:self.sentName]==false) {
        
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
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
        
    }
    
    cell.textLabel.text = [self.onlineArray objectAtIndex:indexPath.row];
    
    return cell;
    
}

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
    int kkk=0;
}

//- (void)viewDidDisappear:(BOOL)animated
//{
//}


@end
