#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "FeedItem.h"
#import "FeedTableViewCell.h"
#import "DetailViewController.h"
#import "BrowserTableViewController.h"
#import "InternetConnectionMonitor.h"
#import "Reachability.h"
#import "AppDelegate.h"
#import <dispatch/dispatch.h>
#import "NSURLSession+SynchronousTask.h"
#import "CoreDataController.h"
#import "ASCoreDataController.h"

@interface ASCoreDataController : NSObject <NSXMLParserDelegate>


+ (id)sharedInstance;

- (NSManagedObjectContext *)writerManagedObjectContext;
- (NSManagedObjectContext *)mainManagedObjectContext;
//- (NSManagedObjectContext *)privateBackgroundManagedObjectContext;
- (void)saveWriterContext;
- (void)saveMainContext;
- (void)saveBackgroundContext:(NSManagedObjectContext*)backgroundContext;
- (NSManagedObjectContext*)generateBackgroundManagedContext;
- (NSManagedObjectModel *)managedObjectModel;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;

@end
