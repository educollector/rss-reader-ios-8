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

// setters

- (NSManagedObjectContext *)writerContext;
- (NSManagedObjectContext *)mainContext;
//- (NSManagedObjectContext *)privateContext;

//save and generate contexts

- (void)saveWriterContext;
- (void)saveMainContext;
- (void)saveBackgroundContext:(NSManagedObjectContext*)backgroundContext;
- (NSManagedObjectContext*)generateBackgroundManagedContext;

//core data stack

- (NSManagedObjectModel *)managedObjectModel;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;

//playing with data

-(void) savePostsToCoreDataFromUrl: (NSString*)feedUrl andPost:(NSMutableArray*)postsArray;
-(NSMutableArray *)loadUrlsFromDatabase;
-(NSMutableArray *)loadPostsFromDtabase;
-(NSMutableArray *)loadFavouritPostFromDatabase;
- (void)savePost:(FeedItem *)item asFavourite:(BOOL)isLiked;

@end
