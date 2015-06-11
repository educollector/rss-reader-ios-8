#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "FeedItem.h"
#import "FeedTableViewCell.h"
#import "DetailViewController.h"
#import "BrowserTableViewController.h"
#import "InternetConnectionMonitor.h"
#import "Reachability.h"
#import "Url.h"
#import <dispatch/dispatch.h>
#import "Post.h"
#import "NSURLSession+SynchronousTask.h"
#import "CoreDataController.h"
#import "ASCoreDataController.h"
#import "ASTextCleaner.h"
#import "FeedItemTableViewCell.h"

@interface MainFeedTableViewController : UITableViewController<UITabBarControllerDelegate, NSURLConnectionDataDelegate, NSXMLParserDelegate, NSFetchedResultsControllerDelegate, UIPopoverPresentationControllerDelegate>
{
    NSMutableData *_responseData;
}

@property (nonatomic, strong) UIPopoverController *popController;
@property (nonatomic, strong) UIPopoverPresentationController *sortPopover;

@end
