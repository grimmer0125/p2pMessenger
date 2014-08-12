//
//  ReactiveEventsViewController.h
//  libPusher
//
//  Created by Luke Redpath on 27/11/2013.
//
//

#import <UIKit/UIKit.h>
#import "stun_hole_puncher.h"


typedef enum {
//    TCP_P2P = 0,
    UDP_P2P = 1,
    TCP_SR = 2,
//    UDP_SR = 3,
} C4miConnectionType;

typedef enum {
    P2P_NONE =0,
    P2P_SUCCESS = 1,
    P2P_FAIL = 2,
    P2P_WAITTING = 3,
} P2PStatus;

NSString *KEY_P2PLOCALSOCKET = @"KEY_P2PLOCALSOCKET";
NSString *KEY_P2PSTATUS = @"KEY_P2PSTATUS";
NSString *KEY_MESSAGE = @"KEY_MESSAGE";
NSString *KEY_ADDR = @"KEY_ADDR";

@class PTPusher;

@interface ReactiveEventsViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic) PTPusher *pusher;

@property IBOutlet UITextField *nameField;
//@property IBOutlet UIButton *changeNmaeButton;

@property IBOutlet UITextField *inputTextField;
//@property IBOutlet UIButton *sendTextButton;
@property IBOutlet UITextView *textView;

@property IBOutlet UITableView *onlineTableView;

@property NSMutableArray *onlineArray;

@property NSString *sentName;

@property NSMutableDictionary *userP2PDict;


- (IBAction)sendTextPress:(id)sender;
- (IBAction)changeNamePress:(id)sender;


@end

//@interface OGButton : UIButton
//
//@property NSString *name;
//
//@end
//
//@interface P2PObject : NSObject
//{
//@public
//    pj_stun_sock   *stun_sock;
//}


//@end


