#import "ASCoreDataController.h"
#import "Post.h"
#import "FeedItem.h"
#import "Url.h"
#import "NSURLSession+SynchronousTask.h"
#import "NSString+HTML.h"

#define kBgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

@interface ASCoreDataController()

@property (nonatomic, strong) NSManagedObjectContext *writerManagedObjectContext;
@property (nonatomic, strong) NSManagedObjectContext *mainManagedObjectContext;
//@property (nonatomic, strong) NSManagedObjectContext *privateBackgroundManagedObjectContext;
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
    NSMutableArray *urlsOfFeeds;
    NSMutableData *responseData;
    NSXMLParser *rssParser;
}

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

//*****************************************************************************/
#pragma mark - Data saving and retrieving

//*****************************************************************************/

-(void)getActualDataFromConnection{
    NSLog(@"\n\nMainFeed --- getActualDataFromConnection\n\n");
    [self loadUrlsFromDatabase];
    [self makeRequestAndConnectionWithNSSession];
}

-(void) savePostsToCoreDataFromUrl: (NSString*)feedUrl andPost:(NSMutableArray*)postsArray{
    NSLog(@"savePostsToCoreDataFromUrl");
    //if(isDataLoaded){
    NSManagedObjectContext *tmpPrivateContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    tmpPrivateContext.parentContext = [((AppDelegate *)[UIApplication sharedApplication].delegate) managedObjectContext];
    [self deleteUrl: feedUrl];
    Url *urlToSave = (Url *)[NSEntityDescription insertNewObjectForEntityForName:@"Url" inManagedObjectContext:tmpPrivateContext];
    urlToSave.url = feedUrl;
    NSSet* setOfPosts = [NSSet setWithArray:[postsArray copy]];
    [urlToSave addPosts:setOfPosts];
    
    //}
}

-(void) savePostsToCoreData_2{
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

-(void) savePostsToCoreData{
    NSLog(@"savePostsToCoreData");
    if(isDataLoaded){
        NSManagedObjectContext *tmpPrivateContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        tmpPrivateContext.parentContext = [((AppDelegate *)[UIApplication sharedApplication].delegate) managedObjectContext];
        [self deleteAllEntities: @"Post"];
        
        [tmpPrivateContext performBlock:^{
            // do something that takes some time asynchronously using the temp context
            for(FeedItem *post in postsToDisplay){
                Post *postToSave = (Post *)[NSEntityDescription insertNewObjectForEntityForName:@"Post" inManagedObjectContext:tmpPrivateContext];
                postToSave.title = post.title;
                postToSave.shortText = post.shortText;
                postToSave.pubDate = post.pubDate;
                postToSave.link = post.link;
            }
            //save the context
            [self saveContextwithWithChild:tmpPrivateContext];
        }];
    }
}

-(void)saveContextwithWithChild:(NSManagedObjectContext *)childContext {
    if (childContext.parentContext != nil && childContext != nil) {
        // push to parent
        NSError *error;
        if ([childContext save:&error]) {
            NSLog(@"childContext saved!");
            // save parent to disk asynchronously
            [childContext.parentContext performBlock:^{
                NSError *error;
                if ([childContext.parentContext save:&error]) {
                    NSLog(@"ParentContext saved!");
                }else{
                    NSLog(@"Can't Save parentContext! %@ %@", error, [error localizedDescription]);
                }
            }];
        }else{
            NSLog(@"Can't Save childContext! %@ %@", error, [error localizedDescription]);
        }
    }
}

- (void)deleteAllEntities:(NSString *)nameEntity{
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *managedObjectContext = [appDelegate managedObjectContext];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:nameEntity];
    [fetchRequest setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError *error;
    NSArray *fetchedObjects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    for (NSManagedObject *object in fetchedObjects)
    {
        [managedObjectContext deleteObject:object];
    }
    
    error = nil;
    [managedObjectContext save:&error];
}

- (void)deleteUrl:(NSString *)url{
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *managedObjectContext = [appDelegate managedObjectContext];
    
    NSNumber *soughtPid=[NSNumber numberWithInt:53];
    NSEntityDescription *productEntity=[NSEntityDescription entityForName:@"Url" inManagedObjectContext:managedObjectContext];
    NSFetchRequest *fetch=[[NSFetchRequest alloc] init];
    [fetch setEntity:productEntity];
    NSPredicate *p=[NSPredicate predicateWithFormat:@"url == %@", soughtPid];
    [fetch setPredicate:p];
    //... add sorts if you want them
    NSError *fetchError;
    NSArray *fetchedProducts=[managedObjectContext executeFetchRequest:fetch error:&fetchError];
    // handle error
    for (NSManagedObject *product in fetchedProducts) {
        [managedObjectContext deleteObject:product];
    }
}


-(void)loadUrlsFromDatabase{
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *managedObjectContext = [appDelegate managedObjectContext];
    
    if (managedObjectContext != nil){
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Url" inManagedObjectContext:managedObjectContext];
        [fetchRequest setEntity:entity];
        
        NSError *error = nil;
        NSArray *tmpUrlsArray = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (error) {
            NSLog(@"Unable to execute fetch request loadUrlsFromDatabase. %@, %@", error, error.localizedDescription);
        } else {
            NSLog(@"SUCCESS loadUrlsFromDatabase");
        }
        urlsOfFeeds = [[NSMutableArray alloc]init];
        if([tmpUrlsArray count] <= 0){
            //[self showPopupNoRssAvailable];
             NSLog(@"Add [self showPopupNoRssAvailable");
        }
        //rewrite the table linksOfFeed to remove feed deleted on BrowseScreen and keep the table up to date
        for(Url* el in tmpUrlsArray){
            [urlsOfFeeds addObject:el.url];
        }
    }
}

// Synchonous request with NSURLSesion
-(void)makeRequestAndConnectionWithNSSession{
    NSError __block *error = nil;
    NSURLResponse __block *response = nil;
    NSURLRequest __block *request =[[NSURLRequest alloc]init];
    
    postsToDisplay = [[NSMutableArray alloc]init];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
        if(urlsOfFeeds.count != 0){
            for(NSString* feedUrl in urlsOfFeeds){
                
                responseData = [[NSMutableData alloc] init];
                postsToAppendToUrl = [[NSMutableArray alloc]init];
                NSURL *url = [NSURL URLWithString: feedUrl];
                request= [NSURLRequest requestWithURL:[NSURL URLWithString: feedUrl]];
                
                //NSData *datatToAppend = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                NSData *datatToAppend = [NSURLSession sendSynchronousDataTaskWithURL:url returningResponse:&response error:&error];
                [responseData appendData:datatToAppend];
                [self makeParsing];
                for(FeedItem *item in postsToAppendToUrl){
                    item.sourceFeedUrl = feedUrl;
                }
                [self savePostsToCoreDataFromUrl:feedUrl andPost:(NSMutableArray*)postsToAppendToUrl];
                [postsToDisplay addObjectsFromArray:postsToAppendToUrl ];
                
                if(error != nil){
                    NSLog(@"There was an error with synchrononous request: %@ Impelment connectionDidFailedWithError", error.description);
                    //[self connectionDidFailedWithError:error];
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            //[self endOfLoadingData];
            //TODO send notification???
        });
    });
}

-(void)makeParsing{
    rssParser = [[NSXMLParser alloc] initWithData:(NSData *)responseData];
    [rssParser setDelegate: self];
    [rssParser parse];
    isDataLoaded = YES;
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

//*****************************************************************************/
#pragma mark - Parsing
//*****************************************************************************/

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:
(NSDictionary *)attributeDict {
    currentElement = elementName;
    if ([currentElement isEqualToString:@"item"]) {
        FeedItem *rssItem = [[FeedItem alloc] init];
        currentRssItem = rssItem;
        title = [[NSMutableString alloc] init];
        link = [[NSMutableString alloc] init];
        description = [[NSMutableString alloc] init];
        pubDate = [[NSMutableString alloc] init];
        imgLink = [[NSMutableString alloc] init];
    }
    else if ([currentElement isEqualToString:@"entry"]) {
        FeedItem *rssItem = [[FeedItem alloc] init];
        currentRssItem = rssItem;
        title = [[NSMutableString alloc] init];
        link = [[NSMutableString alloc] init];
        description = [[NSMutableString alloc] init];
        pubDate = [[NSMutableString alloc] init];
        imgLink = [[NSMutableString alloc] init];
    }
}


- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if ([currentElement isEqualToString:@"title"]) {
        [title appendString:string];
    } else if ([currentElement isEqualToString:@"link"]) {
        [link appendString:string];
    } else if ([currentElement isEqualToString:@"description"]) {
        [description appendString:string];
    } else if ([currentElement isEqualToString:@"summary"]) {// Atom
        [description appendString:string];
    } else if ([currentElement isEqualToString:@"pubDate"]) {
        [pubDate appendString:string];
    } else if ([currentElement isEqualToString:@"updated"]) { // Atom
        [pubDate appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:
(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:@"item"]) {
        currentRssItem.title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.link = [link stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.shortText = [description stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.pubDate = [pubDate stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [postsToDisplay addObject:currentRssItem];
    } else if ([elementName isEqualToString:@"entry"]) {
        currentRssItem.title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.link = [link stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.shortText = [description stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.pubDate = [pubDate stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [postsToAppendToUrl addObject:currentRssItem];
    }
    if(currentRssItem.title!=nil) {NSLog(@"PARSING DONE \t%@", currentRssItem.title);}
}

- (void)parserDidEndDocument:(NSXMLParser *)parser{
    NSLog(@"parserDidEndDocument");
    isDataLoaded = YES;
}


@end
