//
//  ReactiveEventsViewController.h
//  libPusher
//
//  Created by Luke Redpath on 27/11/2013.
//
//

#import <UIKit/UIKit.h>

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


- (IBAction)sendTextPress:(id)sender;
- (IBAction)changeNamePress:(id)sender;


@end
