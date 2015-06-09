#import "ASCoreDataController.h"
#import "Post.h"
#import "FeedItem.h"
#import "Url.h"
#import "NSURLSession+SynchronousTask.h"
#import "NSString+HTML.h"

#define kBgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

@interface ASCoreDataController()

@property (nonatomic, strong) NSManagedObjectContext *writerContext;
@property (nonatomic, strong) NSManagedObjectContext *mainContext;
//@property (nonatomic, strong) NSManagedObjectContext *privateContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end

@implementation ASCoreDataController{
    NSMutableArray __block *postsToDisplay;
    NSMutableArray __block *postsToAppendToUrl;
    NSMutableString *title, *link, *description,*pubDate, *imgLink;
    NSString *currentElement;
    FeedItem *currentRssItem;
    BOOL isDataLoaded;
    NSMutableData *responseData;
    NSXMLParser *rssParser;
}

@synthesize writerContext = _writerContext;
@synthesize mainContext = _mainContext;
//@synthesize privateBackgroundManagedObjectContext = _privateContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

+ (id)sharedInstance {
    static dispatch_once_t once;
    static ASCoreDataController *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}
/***********************************************************/
#pragma mark - Core Data stack
/***********************************************************/
/***********************************************************/
#pragma mark - Managed Object Contexts
/***********************************************************/
//Writing to the persistant store without blocking UI
- (NSManagedObjectContext *)writerContext{
    if (_writerContext != nil) {
        return _writerContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _writerContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_writerContext performBlockAndWait:^{
            [_writerContext setPersistentStoreCoordinator:coordinator];
        }];
    }
    return _writerContext;
}

//ex. Working with NSFetchedResultController
- (NSManagedObjectContext *)mainContext{
    if (_mainContext != nil) {
        return _mainContext;
    }
    NSManagedObjectContext *parentContext = [self writerContext];
    if (parentContext != nil) {
        _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_mainContext performBlockAndWait:^{
            [_mainContext setParentContext:parentContext];
        }];
    }
    return _mainContext;
}

- (void)saveWriterContext{
    [self.writerContext performBlockAndWait:^{
        NSError *error = nil;
        if ([self.writerContext save:&error]) {
            NSLog(@"writerContext SAVED");
        }else{
            NSLog(@"Can't Save parentContext! %@ %@", error, [error localizedDescription]);
        }
    }];
}

- (void)saveMainContext{
    if (self.mainContext.parentContext != nil && self.mainContext != nil) {
        // push to parent
        NSError *error;
        if ([self.mainContext  save:&error]) {
            NSLog(@"mainContext  saved!");
            // save parent to disk asynchronously
            [self.mainContext.parentContext performBlock:^{
                [self saveWriterContext];
            }];
        }else{
            NSLog(@"Can't Save mainContext ! %@ %@", error, [error localizedDescription]);
        }
    }
}


- (void)saveBackgroundContext:(NSManagedObjectContext*)backgroundContext{
    // push to parent
    NSError *error;
    if ([backgroundContext  save:&error]) {
        NSLog(@"backgroundContext  saved!");
        // save parent to disk asynchronously
        [backgroundContext.parentContext performBlock:^{
            [self saveMainContext]; //TODO: czy to jest we wlasciwym watku???
        }];
    }else{
        NSLog(@"Can't Save mainContext ! %@ %@", error, [error localizedDescription]);
    }
}

- (NSManagedObjectContext*)generateBackgroundManagedContext{
    NSManagedObjectContext* tmpBackgroundContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    tmpBackgroundContext.parentContext = [self mainContext];
    return tmpBackgroundContext;
    
}
/***********************************************************/
#pragma mark -
/***********************************************************/

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"RssAppBsc" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Store.sqlite"]; //RssAppBsc.sqlite
    NSError *errorAddingStore = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    //    Use this to light migration http://code.tutsplus.com/tutorials/core-data-from-scratch-migrations--cms-21844
    //    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @(YES),
    //                               NSInferMappingModelAutomaticallyOption : @(YES) };
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&errorAddingStore]) {
        NSLog(@"Unable to create persistent store after recovery. %@, %@", errorAddingStore, errorAddingStore.localizedDescription);
        // Show Alert View
        NSString *applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        NSString *message = [NSString stringWithFormat:@"A serious application error occurred while %@ tried to read your data. Please contact support for help.", applicationName];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        // Move Incompatible Store
        if ([fm fileExistsAtPath:[storeURL path]]) {
            NSURL *corruptURL = [[self applicationIncompatibleStoresDirectory] URLByAppendingPathComponent:[self nameForIncompatibleStore]];
            
            // Move Corrupt Store
            NSError *errorMoveStore = nil;
            [fm moveItemAtURL:storeURL toURL:corruptURL error:&errorMoveStore];
            
            if (errorMoveStore) {
                NSLog(@"Unable to move corrupt store.");
            }
        }
        
    }
    return _persistentStoreCoordinator;
}

- (NSURL *)applicationStoresDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *applicationApplicationSupportDirectory = [[fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *URL = [applicationApplicationSupportDirectory URLByAppendingPathComponent:@"Stores"];
    
    if (![fm fileExistsAtPath:[URL path]]) {
        NSError *error = nil;
        [fm createDirectoryAtURL:URL withIntermediateDirectories:YES attributes:nil error:&error];
        
        if (error) {
            NSLog(@"Unable to create directory for data stores.");
            
            return nil;
        }
    }
    return URL;
}

- (NSURL *)applicationIncompatibleStoresDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *URL = [[self applicationStoresDirectory] URLByAppendingPathComponent:@"Incompatible"];
    
    if (![fm fileExistsAtPath:[URL path]]) {
        NSError *error = nil;
        [fm createDirectoryAtURL:URL withIntermediateDirectories:YES attributes:nil error:&error];
        
        if (error) {
            NSLog(@"Unable to create directory for corrupt data stores.");
            
            return nil;
        }
    }
    return URL;
}

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSString *)nameForIncompatibleStore {
    // Initialize Date Formatter
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    // Configure Date Formatter
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    
    return [NSString stringWithFormat:@"%@.sqlite", [dateFormatter stringFromDate:[NSDate date]]];
}

//*****************************************************************************/
#pragma mark - Data saving and retrieving
//*****************************************************************************/

-(void) savePostsToCoreDataFromUrl: (NSString*)feedUrl andPost:(NSMutableArray*)postsArray{
    NSLog(@"savePostsToCoreDataFromUrl");
    NSManagedObjectContext *tmpPrivateContext = [self generateBackgroundManagedContext];
    [self deleteUrl: feedUrl withContext:tmpPrivateContext];
    Url *urlToSave = (Url *)[NSEntityDescription insertNewObjectForEntityForName:@"Url" inManagedObjectContext:tmpPrivateContext];
    urlToSave.url = feedUrl;
    NSSet* setOfPosts = [NSSet setWithArray:[postsArray copy]];
    [urlToSave addPosts:setOfPosts];
}

-(void) savePostsToCoreData: (NSMutableArray*)postsArray{
    NSLog(@"savePostsToCoreData");
    NSManagedObjectContext *tmpPrivateContext = [self generateBackgroundManagedContext];
    [self deleteAllEntities: @"Post" withContext:_writerContext]; //czy tmpPrivateContext??
    
    [tmpPrivateContext performBlock:^{
        // do something that takes some time asynchronously using the temp context
        for(int i; i < postsToDisplay.count; i++){
            FeedItem *post = (FeedItem*)postsToDisplay[i];
            Post *postToSave = (Post *)[NSEntityDescription insertNewObjectForEntityForName:@"Post" inManagedObjectContext:tmpPrivateContext];
            postToSave.title = post.title;
            postToSave.shortText = post.shortText;
            postToSave.pubDate = post.pubDate;
            postToSave.link = post.link;
        }
        //save the context
        [self saveBackgroundContext:tmpPrivateContext];
    }];
}

- (void)deleteUrl:(NSString *)url withContext:(NSManagedObjectContext *)context{
    NSEntityDescription *productEntity=[NSEntityDescription entityForName:@"Url" inManagedObjectContext:context];
    NSFetchRequest *fetch=[[NSFetchRequest alloc] init];
    [fetch setEntity:productEntity];
    NSPredicate *p=[NSPredicate predicateWithFormat:@"url == %@", url];
    [fetch setPredicate:p];
    //... add sorts if you want them
    NSError *fetchError;
    NSArray *fetchedProducts=[context executeFetchRequest:fetch error:&fetchError];
    // handle error
    for (NSManagedObject *product in fetchedProducts) {
        [context deleteObject:product];
    }
}

- (void)deleteAllEntities:(NSString *)nameEntity withContext:(NSManagedObjectContext*)context
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:nameEntity];
    [fetchRequest setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError *error;
    NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
    for (NSManagedObject *object in fetchedObjects)    {
        [context deleteObject:object];
    }
    error = nil;
    [context save:&error];
}


-(NSMutableArray*)loadUrlsFromDatabase{
    NSManagedObjectContext *tmpPrivateContext = [self generateBackgroundManagedContext];
    NSMutableArray *urlsOfFeeds = [[NSMutableArray alloc]init];
    if (tmpPrivateContext != nil){
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Url" inManagedObjectContext:tmpPrivateContext];
        [fetchRequest setEntity:entity];
        
        NSError *error = nil;
        NSArray *tmpUrlsArray = [tmpPrivateContext executeFetchRequest:fetchRequest error:&error];
        if (error) {
            NSLog(@"Unable to execute fetch request loadUrlsFromDatabase. %@, %@", error, error.localizedDescription);
        } else {
            NSLog(@"SUCCESS loadUrlsFromDatabase");
        }
        if([tmpUrlsArray count] <= 0){
            //[self showPopupNoRssAvailable];
             NSLog(@"Add [self showPopupNoRssAvailable");
            return urlsOfFeeds; //zwróci nil ?
        }
        //rewrite the table linksOfFeed to remove feed deleted on BrowseScreen and keep the table up to date
        for(Url* el in tmpUrlsArray){
            [urlsOfFeeds addObject:el.url];
        }
    }
    return urlsOfFeeds;
}

@end
