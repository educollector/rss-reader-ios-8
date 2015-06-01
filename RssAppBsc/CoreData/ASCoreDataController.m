#import "ASCoreDataController.h"
#import "Post.h"
#import "FeedItem.h"
@interface ASCoreDataController()

@property (nonatomic, strong) NSManagedObjectContext *writerManagedObjectContext;
@property (nonatomic, strong) NSManagedObjectContext *mainManagedObjectContext;
//@property (nonatomic, strong) NSManagedObjectContext *privateBackgroundManagedObjectContext;
@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end

@implementation ASCoreDataController

@synthesize writerManagedObjectContext = _writerManagedObjectContext;
@synthesize mainManagedObjectContext = _mainManagedObjectContext;
//@synthesize privateBackgroundManagedObjectContext = _privateBackgroundManagedObjectContext;
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

//Writing to the persistant store without blocking UI
- (NSManagedObjectContext *)writerManagedObjectContext{
    if (_writerManagedObjectContext != nil) {
        return _writerManagedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _writerManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_writerManagedObjectContext performBlockAndWait:^{
            [_writerManagedObjectContext setPersistentStoreCoordinator:coordinator];
        }];
    }
    return _writerManagedObjectContext;
}

//Working with NSFetchedResultController
- (NSManagedObjectContext *)mainManagedObjectContext{
    if (_mainManagedObjectContext != nil) {
        return _mainManagedObjectContext;
    }
    NSManagedObjectContext *parentContext = [self writerManagedObjectContext];
    if (parentContext != nil) {
        _mainManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_mainManagedObjectContext performBlockAndWait:^{
            [_mainManagedObjectContext setParentContext:parentContext];
        }];
    }
    return _mainManagedObjectContext;
    
}

- (void)saveWriterContext{
    [self.writerManagedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        if ([self.writerManagedObjectContext save:&error]) {
            NSLog(@"writerManagedObjectContext SAVED");
        }else{
            NSLog(@"Could not save master context due to %@", error);
        }
    }];
}
- (void)saveMainContext{
    if (self.mainManagedObjectContext.parentContext != nil && self.mainManagedObjectContext != nil) {
        // push to parent
        NSError *error;
        if ([self.mainManagedObjectContext  save:&error]) {
            NSLog(@"mainManagedObjectContext  saved!");
            // save parent to disk asynchronously
            [self.mainManagedObjectContext.parentContext performBlock:^{
                [self saveWriterContext];
//                NSError *error;
//                if ([self.mainManagedObjectContext.parentContext save:&error]) {
//                    NSLog(@"Parent (Writer) Context saved!");
//                }else{
//                    NSLog(@"Can't Save parent (writer) context! %@ %@", error, [error localizedDescription]);
//                }
            }];
        }else{
            NSLog(@"Can't Save mainManagedObjectContext ! %@ %@", error, [error localizedDescription]);
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
            [self saveMainContext];
//            NSError *error;
//            if ([self.mainManagedObjectContext.parentContext save:&error]) {
//                NSLog(@"Parent (Writer) Context saved!");
//            }else{
//                NSLog(@"Can't Save parent (writer) context! %@ %@", error, [error localizedDescription]);
//            }
        }];
    }else{
        NSLog(@"Can't Save mainManagedObjectContext ! %@ %@", error, [error localizedDescription]);
    }
}

- (NSManagedObjectContext*)generateBackgroundManagedContext{
    NSManagedObjectContext* tmpBackgroundCOntext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    tmpBackgroundCOntext.parentContext = [self mainManagedObjectContext];
    return tmpBackgroundCOntext;
    
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
        NSString *title = @"Warning";
        NSString *applicationName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        NSString *message = [NSString stringWithFormat:@"A serious application error occurred while %@ tried to read your data. Please contact support for help.", applicationName];
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
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

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - Incompatible Store

- (NSString *)nameForIncompatibleStore {
    // Initialize Date Formatter
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    // Configure Date Formatter
    [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    
    return [NSString stringWithFormat:@"%@.sqlite", [dateFormatter stringFromDate:[NSDate date]]];
}

#pragma mark - Data saving and retrieving

-(void) savePostsToCoreData:(NSMutableArray*)postsToDisplay{
    NSLog(@"savePostsToCoreData");
    NSManagedObjectContext *tmpPrivateContext = [self generateBackgroundManagedContext];
    [self deleteAllEntities: @"Post" withContext:_writerManagedObjectContext];
    
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

- (void)deleteAllEntities:(NSString *)nameEntity withContext:(NSManagedObjectContext*)context
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:nameEntity];
    [fetchRequest setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError *error;
    NSArray *fetchedObjects = [context executeFetchRequest:fetchRequest error:&error];
    for (NSManagedObject *object in fetchedObjects)
    {
        [context deleteObject:object];
    }
    
    error = nil;
    [context save:&error];
}


@end
