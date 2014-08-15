//
//  ReactiveEventsViewController.h
//  libPusher
//
//  Created by Luke Redpath on 27/11/2013.
//
//

#import <UIKit/UIKit.h>
#import "stun_hole_puncher.h"
#import "stun_process_const.h"

//typedef enum {
////    TCP_P2P = 0,
//    UDP_P2P = 1,
//    TCP_SR = 2,
////    UDP_SR = 3,
//} C4miConnectionType;

void runOnMainQueue(void(^block)(void));

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

void mk_punching_result(const char* hole_punching_id, pj_status_t status,void *user_data);

void mk_receive_data(const char* hole_punching_id,unsigned char *data, int datalen, void *user_data);

void mk_binding_result(const char* hole_punching_id,
                       char *mapp_addr,
                       char *local_addr,
                       pj_status_t status, void *inUserData);

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


