#import "MainFeedTableViewController.h"
#import "NSString+HTML.h"
#define kBgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)


@interface MainFeedTableViewController ()
@property (nonatomic,strong) ASCoreDataController *dataController;
@end

@implementation MainFeedTableViewController{
    UITabBarController *tabBarController;
    NSFetchedResultsController *fetchResultController;
    Url *urlToMakeRequest;
    BOOL makeRefresh;
    BOOL __block isDataLoaded;
    InternetConnectionMonitor *monitor;
    NSXMLParser *rssParser;
    NSMutableArray __block *postsToDisplay;
    NSMutableString *title, *link, *description,*pubDate, *imgLink;
    NSString *currentElement;
    FeedItem *currentRssItem;
    UIActivityIndicatorView *spinner;
    NSMutableArray *urlsOfFeeds;
    dispatch_queue_t backgroundSerialQueue;
    dispatch_queue_t backgroundGlobalQueue;
    AppDelegate *appDelegate;
    NSManagedObjectContext *managedObjectContext;
    UIRefreshControl *refreshControl;
    NSString *currentChannelUrl;
    NSMutableArray* postsToAppendToUrl;
}

@synthesize dataController;

//*****************************************************************************/
#pragma mark - View methods
//*****************************************************************************/

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setNotificationCenter];
    [self styleTheView];
    [self setPullToRefresh];
  
    //Core Data
    appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    managedObjectContext = [appDelegate managedObjectContext];
    
    dataController = [ASCoreDataController sharedInstance];
    
    _responseData = [[NSMutableData alloc] init];
    tabBarController = [self tabBarController];
    makeRefresh = NO;
    isDataLoaded = NO;
    backgroundSerialQueue = dispatch_queue_create("pl.skierbisz.postPreparingQueue", NULL);
    backgroundGlobalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0);
    [self internetConnectionChecking];
    [self uiSetSpiner:YES];
    
    //--------------------------------------//
    //Choose how to load data at start      //
    //--------------------------------------//
    //[self getActualDataFromConnection];
    [self loadPostsFromDtabase];
    //--------------------------------------//
}

-(void)viewWillAppear:(BOOL)animated{
    NSLog(@"Main feed - viewWillAppear");
    [super viewWillAppear:animated];
    [self uiUpdateMainFeedTable];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


//*****************************************************************************/
#pragma mark - View - helper methods
//*****************************************************************************/

-(void)setNotificationCenter{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(getActualDataFromConnection)
                                                 name:@"pl.skierbisz.browserscreen.linkadded"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(getActualDataFromConnection)
                                                 name:@"pl.skierbisz.browserscreen.linkdeleted"
                                               object:nil];
}
-(void)styleTheView{
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    self.tableView.backgroundView.backgroundColor = [UIColor yellowColor];
    // Set this in every view controller so that the back button displays back instead of the root view controller name
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
}
-(void)setPullToRefresh{
    refreshControl = [[UIRefreshControl alloc]init];
    [self.tableView addSubview:refreshControl];
    [refreshControl addTarget:self action:@selector(getActualDataFromConnection) forControlEvents:UIControlEventValueChanged];
}
-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

//*****************************************************************************/
#pragma mark - Data
//*****************************************************************************/

-(void)getActualDataFromConnection{
    NSLog(@"\n\nMainFeed --- getActualDataFromConnection\n\n");
    [self loadUrlsFromDatabase];
    [self makeRequestAndConnectionWithNSSession];
}


-(void)endOfLoadingData{
    NSLog(@"endOfLoadingData");
    //for(FeedItem* el in postsToDisplay){ NSLog(@"-Element: %@", el.title); }
    NSLog(@"postsToDisplay count %d", (int)[postsToDisplay count]);
    
    if(isDataLoaded){
        //dispatch_async(backgroundGlobalQueue, ^{
        
        //[self savePostsToCoreData];
        //});
        
        [self uiUpdateMainFeedTable];
    }
}

-(void)loadPostsFromDtabase{
    NSLog(@"Main feed - fetchPostsFromDtabase");
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]initWithEntityName:@"Post"];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"pubDate" ascending:nil];
    fetchRequest.sortDescriptors = @[sortDescriptor];
    if(managedObjectContext != nil){
        fetchResultController = [[NSFetchedResultsController alloc]
                                 initWithFetchRequest:fetchRequest
                                 managedObjectContext:managedObjectContext
                                 sectionNameKeyPath:nil
                                 cacheName:nil];
        fetchResultController.delegate = self;
        
        NSError *error;
        if ([fetchResultController performFetch:&error]) {
            NSArray *tmpPostsArray = [[NSArray alloc] initWithArray: fetchResultController.fetchedObjects];
            if([tmpPostsArray count] <= 0){
                [self showPopupNoRssAvailable];
            }
            //rewrite the table linksOfFeed to remove feed deleted on BrowseScreen and keep the table up to date
            postsToDisplay = [[NSMutableArray alloc] init];
            for(Post *el in tmpPostsArray){
                FeedItem *item = [[FeedItem alloc]init];
                item.title = [NSMutableString stringWithString:el.title];
                item.pubDate = [NSMutableString stringWithString:el.pubDate];
                item.shortText = [NSMutableString stringWithString:el.shortText];
                item.link = [NSMutableString stringWithString:el.link];
                [postsToDisplay addObject: item];
            }
            [self uiUpdateMainFeedTable];
        } else {
            NSLog(@"Can't get the record! %@ %@", error, [error localizedDescription]);
        }
    }
}

-(void)loadUrlsFromDatabase{
    NSLog(@"Main feed - fetchUrlsFromDatabase");
    //fetchnig data from database
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Url"];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"url" ascending:YES];
    fetchRequest.sortDescriptors = @[sortDescriptor];
    if (managedObjectContext != nil) {
        fetchResultController = [[NSFetchedResultsController alloc]
                                 initWithFetchRequest:fetchRequest
                                 managedObjectContext:managedObjectContext
                                 sectionNameKeyPath:nil
                                 cacheName:nil];
        fetchResultController.delegate = self;
        NSError *error;
        if ([fetchResultController performFetch:&error]) {
            NSArray *tmpUrlsArray = [[NSArray alloc] initWithArray: fetchResultController.fetchedObjects];
            urlsOfFeeds = [[NSMutableArray alloc]init];
            if([tmpUrlsArray count] <= 0){
                [self showPopupNoRssAvailable];
            }
            //rewrite the table linksOfFeed to remove feed deleted on BrowseScreen and keep the table up to date
            for(Url* el in tmpUrlsArray){
                [urlsOfFeeds addObject:el.url];
            }
        } else {
            NSLog(@"Can't get the record! %@ %@", error, [error localizedDescription]);
        }
    }
}

// Synchonous request with NSURLSesion
-(void)makeRequestAndConnectionWithNSSession{
    NSError __block *error = nil;
    NSURLResponse __block *response = nil;
    postsToDisplay = [[NSMutableArray alloc] init];
    NSURLRequest __block *request =[[NSURLRequest alloc]init];

    dispatch_async(backgroundGlobalQueue,^{
        if(urlsOfFeeds.count != 0){
            for(NSString* feedUrl in urlsOfFeeds){
                _responseData = [[NSMutableData alloc] init];
                postsToAppendToUrl = [[NSMutableArray alloc]init];
                NSURL *url = [NSURL URLWithString: feedUrl];
                request= [NSURLRequest requestWithURL:[NSURL URLWithString: feedUrl]];
                
                NSData *datatToAppend = [NSURLSession sendSynchronousDataTaskWithURL:url returningResponse:&response error:&error];
                [_responseData appendData:datatToAppend];
                [self makeParsing];
                
                
                for(FeedItem *item in postsToAppendToUrl){
                    item.sourceFeedUrl = [NSMutableString stringWithString:feedUrl];
                }
                [self savePostsToCoreDataFromUrl:feedUrl andPosts:(NSMutableArray*)postsToAppendToUrl];
                [postsToDisplay addObjectsFromArray:postsToAppendToUrl ];
                
                if(error != nil){
                    NSLog(@"There was an error with synchrononous request: %@", error.description);
                    [self connectionDidFailedWithError:error];
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self endOfLoadingData];
        });
    });
}


-(void) savePostsToCoreDataFromUrl: (NSString*)feedUrl andPosts:(NSMutableArray*)postsArray{
    NSLog(@"savePostsToCoreDataFromUrl");
    NSManagedObjectContext *tmpPrivateContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    tmpPrivateContext.parentContext = [((AppDelegate *)[UIApplication sharedApplication].delegate) managedObjectContext];
    [self deleteUrl: feedUrl];
    
    [tmpPrivateContext performBlock:^{
        Url *urlToSave = (Url *)[NSEntityDescription insertNewObjectForEntityForName:@"Url" inManagedObjectContext:tmpPrivateContext];
        urlToSave.url = feedUrl;
        for(FeedItem *post in postsArray){
            Post *postToSave = (Post *)[NSEntityDescription insertNewObjectForEntityForName:@"Post" inManagedObjectContext:tmpPrivateContext];
            postToSave.title = post.title;
            postToSave.shortText = post.shortText;
            postToSave.pubDate = post.pubDate;
            postToSave.link = post.link;
            postToSave.sourceFeedUrl.url = post.sourceFeedUrl;
            [urlToSave addPostsObject:postToSave];
        }        
        //save the context
        [self saveContextwithWithChild:tmpPrivateContext];
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
                postToSave.sourceFeedUrl.url = post.sourceFeedUrl;
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

//*****************************************************************************/
#pragma mark - Core Data - helper mthods
//*****************************************************************************/

- (void)deleteAllEntities:(NSString *)nameEntity
{
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
    NSEntityDescription *productEntity=[NSEntityDescription entityForName:@"Url" inManagedObjectContext:managedObjectContext];
    NSFetchRequest *fetch=[[NSFetchRequest alloc] init];
    [fetch setEntity:productEntity];
    NSPredicate *p=[NSPredicate predicateWithFormat:@"url == %@", url];
    [fetch setPredicate:p];
    // do sorting
    NSError *fetchError;
    NSArray *fetchedProducts=[managedObjectContext executeFetchRequest:fetch error:&fetchError];
    // handle error
    for (NSManagedObject *product in fetchedProducts) {
        [managedObjectContext deleteObject:product];
    }
}

//*****************************************************************************/
#pragma mark - UI update
//*****************************************************************************/

-(void)uiUpdateMainFeedTable{
    [self.tableView reloadData];
    [self uiSetSpiner:NO];    
    [refreshControl endRefreshing];
}

-(void)uiSetSpiner:(BOOL) isLoading{
    if(isLoading){
        spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        spinner.center = CGPointMake(160, 240);
        spinner.hidesWhenStopped = YES;
        spinner.tag = 1;
        [self.view addSubview:spinner];
        [spinner startAnimating];
    }
    else{
        if(spinner!=NULL){
            [spinner stopAnimating];
            UIActivityIndicatorView *tmpSpinner = (UIActivityIndicatorView*)[self.view viewWithTag:1];
            [tmpSpinner removeFromSuperview];
            [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
        }
    }
}

//*****************************************************************************/
#pragma mark - Table view data source
//*****************************************************************************/

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (postsToDisplay == nil){
        return 0;
    }
    return postsToDisplay.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"cellForRowAtIndexPath");
    static NSString * cellIdentifier = @"FeedCell";
    FeedTableViewCell *cell = (FeedTableViewCell *)[tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    //(FeedTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[@"FeedCell" forIndexPath:indexPath];
    FeedItem *tmpItem = [postsToDisplay objectAtIndex:indexPath.row];
    cell.postImage.image = [UIImage imageNamed:@"postImage"];
    cell.postTitle.text = tmpItem.title;
    cell.postTitle.textColor = [UIColor blackColor];
    cell.postAdditionalInfo.textColor = [UIColor blackColor];
    NSString *cleanedDescription = [self cleanFromTagsWithScanner: tmpItem.shortText];
    cell.postAdditionalInfo.text = [NSString stringWithFormat:@" %@ \n %@ ago", tmpItem.pubDate, cleanedDescription];
    if([tmpItem.isRead isEqualToNumber:[NSNumber numberWithInteger:1]]){
        cell.postTitle.textColor = [UIColor grayColor];
        cell.postAdditionalInfo.textColor = [UIColor grayColor];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger index = [indexPath row];
    [[postsToDisplay objectAtIndex:index] setIsRead:[[NSNumber alloc] initWithInteger:1]];
}

//*****************************************************************************/
#pragma mark - Table view - text formatting methods
//*****************************************************************************/

- (NSString *) cleanFromTagsWithRegexp:(NSString *)text{
    NSString *cleanedText;
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"<img.*\/>"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&error];
    
    cleanedText = [regex stringByReplacingMatchesInString:text
                            options:0
                            range:NSMakeRange(0, [text length])
                            withTemplate:@""];
    
    regex = [NSRegularExpression regularExpressionWithPattern:@"<a.*>.*<\/a>"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:&error];
    
    cleanedText = [regex stringByReplacingMatchesInString:cleanedText
                                                  options:0
                                                    range:NSMakeRange(0, [cleanedText length])
                                             withTemplate:@""];
    return cleanedText;
}

- (NSString *)cleanFromTagsWithScanner:(NSString *)text{
    
    //wstawianie znakow specjalnych zamiast ich kodow
    NSString *tmpString = [text kv_decodeHTMLCharacterEntities];
    
    //czyszczenie z <TAGOW HTML>
    NSMutableString *cleanedText = [NSMutableString stringWithCapacity:[tmpString length]];
    
    NSScanner *scanner = [NSScanner scannerWithString:text];
    scanner.charactersToBeSkipped = NULL;
    NSString *tempText = nil;
    
    while (![scanner isAtEnd])
    {
        [scanner scanUpToString:@"<" intoString:&tempText];
        
        if (tempText != nil)
            [cleanedText appendString:tempText];
        
        [scanner scanUpToString:@">" intoString:NULL];
        
        if (![scanner isAtEnd])
            [scanner setScanLocation:[scanner scanLocation] + 1];
        
        tempText = nil;
    }
    
    return cleanedText;
}

//*****************************************************************************/
#pragma mark - Internet Connection
//*****************************************************************************/
- (void) connectionDidFailedWithError: error{
        _responseData = nil;
        NSLog(@"Connection failed! Errooooooor - %@ %@",
              [error localizedDescription],
              [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    
        UIAlertController *connectionAlert = [UIAlertController
                                              alertControllerWithTitle:@"Coś poszło nie tak"
                                              message:[error localizedDescription]
                                              preferredStyle:UIAlertControllerStyleAlert];
    
        UIAlertAction *okeyAction = [UIAlertAction
                                     actionWithTitle:@"OK."
                                     style:UIAlertActionStyleDefault
                                     handler: ^(UIAlertAction *action){
                                         [self makeRequestAndConnectionWithNSSession];
                                         NSLog(@"alert - OK clicked");
                                     }];
        UIAlertAction *cancelAction = [UIAlertAction
                                       actionWithTitle:@"Cancel."
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction *action){
                                           [self uiUpdateMainFeedTable];
                                           NSLog(@"alert - Cancel clicked");
                                       }];
    
        [connectionAlert addAction:cancelAction];
        [connectionAlert addAction:okeyAction];
        [self presentViewController:connectionAlert animated:YES completion:nil];
}

-(void)internetConnectionChecking{
    NSLog(@"internetConnectionChecking");
    monitor = [[InternetConnectionMonitor alloc]init];
    
    if(!monitor.canAccessInternet){
        makeRefresh = YES;
        UIAlertController *alert = [UIAlertController
                                    alertControllerWithTitle:@"Brak połączenia z internetem"
                                    message:@"Sprawdź połacznie w Ustawieniach telefonu i spróbuj ponownie"
                                    preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okeyAction = [UIAlertAction
                                     actionWithTitle:@"OK"
                                     style:UIAlertActionStyleDefault
                                     handler:^(UIAlertAction *acton){
                                         NSLog(@"ok action");
                                         [self uiSetSpiner:NO];
                                         self.navigationItem.title = @"-----";
                                     }];
        UIAlertAction *retryAction = [UIAlertAction
                                      actionWithTitle:@"Try again"
                                      style:UIAlertActionStyleCancel
                                      handler:^(UIAlertAction *action){
                                          [self uiSetSpiner:NO];
                                          [self viewDidLoad];
                                      }];
        
        [alert addAction:retryAction];
        [alert addAction:okeyAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
    else{
        NSLog(@"Internet connection: TRUE");
        if(makeRefresh){
            [self makeRequestAndConnectionWithNSSession];
            makeRefresh = NO;
        }
    }
}
//*****************************************************************************/
#pragma mark - Parsing
//*****************************************************************************/

-(void)makeParsing{
    rssParser = [[NSXMLParser alloc] initWithData:(NSData *)_responseData];
    [rssParser setDelegate: self];
    [rssParser parse];
    isDataLoaded = YES;
}

//*****************************************************************************/
#pragma mark - Parsing - delegate methods
//*****************************************************************************/

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes: (NSDictionary *)attributeDict {
        currentElement = elementName;
        currentChannelUrl = [[NSString alloc]init];
    
        if ([currentElement isEqualToString:@"channel"]) {
            return;
        }
        if ([currentElement isEqualToString:@"item"]) {
            FeedItem *rssItem = [[FeedItem alloc] init];
            currentRssItem = rssItem;
            return;
        }
        else if ([currentElement isEqualToString:@"entry"]) {
            FeedItem *rssItem = [[FeedItem alloc] init];
            currentRssItem = rssItem;
            return;
        }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if ([currentElement isEqualToString:@"title"]) {
        [currentRssItem.title appendString:[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
        [title appendString:string];
    } else if ([currentElement isEqualToString:@"link"]) {
         [currentRssItem.link appendString:[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    } else if ([currentElement isEqualToString:@"description"]) {
         [currentRssItem.shortText appendString:[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    } else if ([currentElement isEqualToString:@"summary"]) {// Atom
         [currentRssItem.shortText appendString:[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    } else if ([currentElement isEqualToString:@"pubDate"]) {
         [currentRssItem.pubDate appendString:[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    } else if ([currentElement isEqualToString:@"updated"]) { // Atom
         [currentRssItem.pubDate appendString:[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    } else if ([currentElement isEqualToString:@"guid"]) {
        [currentRssItem.guid appendString:[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    } else if ([currentElement isEqualToString:@"id"]) { //Atom
        [currentRssItem.guid appendString:[string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
    }
    
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:@"item"]) {
        //[postsToDisplay addObject:currentRssItem];
        [postsToAppendToUrl addObject:currentRssItem];
        
    } else if ([elementName isEqualToString:@"entry"]) {
        //[postsToDisplay addObject:currentRssItem];
        [postsToAppendToUrl addObject:currentRssItem];
    }
    if(currentRssItem.title!=nil) {NSLog(@"PARSING DONE \t%@", currentRssItem.title);}
}

- (void)parserDidEndDocument:(NSXMLParser *)parser{
    NSLog(@"parserDidEndDocument");
    isDataLoaded = YES;
}

//*****************************************************************************/
#pragma mark - Navigation
//*****************************************************************************/

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"showPostDetailsFromMain"]){
        NSLog(@"CALL prepareForSegue if");
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        DetailViewController *destinationViewController = segue.destinationViewController;
        FeedItem *item = postsToDisplay[indexPath.row];
        destinationViewController.link = item.link;
    }
}

// UITabBarControllerDelegate method.
- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController{
    NSLog(@"tabBarController didSelectViewController:");
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

//*****************************************************************************/
#pragma mark - Popups
//*****************************************************************************/

-(void)showPopupNoRssAvailable{
    NSLog(@"showPopupNoRssAvailable");
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:@"Brak wiadomości"
                                message:@"Dodaj linki do stron, które chcesz obserwować"
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okeyAction = [UIAlertAction
                                 actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *acton){
                                     NSLog(@"ok action");
                                     [self uiSetSpiner:NO];
                                     self.tabBarController.selectedIndex = 1;
                                 }];
    [self uiSetSpiner:NO];
    [alert addAction:okeyAction];
    //self.parentViewController to avoid "presenting view controllers on detached view controllers is discouraged"
    [self.parentViewController presentViewController:alert animated:YES completion:nil];
}

//
//
//-(void)makeRequestAndConnection{
//    NSLog(@"makeRequestAndConnection");
//    _responseData = [[NSMutableData alloc] init];
//    NSError __block *error = nil;
//    NSURLResponse __block *response = nil;
//    postsToDisplay = [[NSMutableArray alloc] init];
//    NSURLRequest __block *request =[[NSURLRequest alloc]init];
//    
//    dispatch_async(backgroundGlobalQueue,^{
//        if(urlsOfFeeds.count != 0){
//            for(NSString* feedUrl in urlsOfFeeds){
//                NSLog(@"item in table of links: %@", feedUrl);
//                
//                NSLog(@"making request");
//                request= [NSURLRequest requestWithURL:[NSURL URLWithString: feedUrl]];
//                
//                NSData *datatToAppend = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//                [_responseData appendData:datatToAppend];
//                if(error != nil){
//                    NSLog(@"There was an error with synchrononous request: %@", error.description);
//                    [self connectionDidFailedWithError:error];
//                }
//            }
//        }
//        [self makeParsing];
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [self endOfLoadingData];
//        });
//    });
//}

//// Asynchonous request with NSURLSesion
//-(void)makeRequestAndConnectionWithNSSession{
//    NSLog(@"makeRequestAndConnectionWithNSSession");
//    _responseData = [[NSMutableData alloc] init];
//    postsToDisplay = [[NSMutableArray alloc] init];
//    NSUInteger __block counter = (NSUInteger)0;
//    if(urlsOfFeeds.count != 0){
//        for(NSString* feedUrl in urlsOfFeeds){
//            NSURLSession *session = [NSURLSession sharedSession];
//            [[session dataTaskWithURL:[NSURL URLWithString: feedUrl]
//                    completionHandler:^(NSData *data,
//                                        NSURLResponse *response,
//                                        NSError *error) {
//                        //Handling the response
//                        [_responseData appendData:data];
//                        if(error != nil){
//                            NSLog(@"There was an error with synchrononous request: %@", error.description);
//                            [self connectionDidFailedWithError:error];
//                        }
//                        ++counter;
//                        if(counter  == urlsOfFeeds.count){
//                            [self makeParsing];
//                                dispatch_async(dispatch_get_main_queue(), ^{
//                                [self endOfLoadingData];
//                            });
//                        }
//                    }] resume];
//        }
//    }
//    else{
//        [self makeParsing];
//        [self endOfLoadingData];
//    }
//}

@end
