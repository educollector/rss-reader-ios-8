#import <UIKit/UIKit.h>

@interface PopoverTableViewCell : UITableViewCell
@property (nonatomic, weak) UITableViewController *controller;
@property (weak, nonatomic) IBOutlet UILabel *label;

@end
