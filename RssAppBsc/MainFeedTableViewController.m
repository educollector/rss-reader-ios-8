#import "MainFeedTableViewController.h"
#import "UIPopoverController+iPhone.h"
#import "ASPopoverViewController.h"

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
    NSMutableArray __block *postsToDisplayIntermediate;
    NSMutableArray __block *postsToDisplaySource;
    NSMutableString *title, *link, *description,*pubDate, *imgLink;
    NSString *currentElement;
    FeedItem *currentRssItem;
    UIActivityIndicatorView *spinner;
    NSMutableArray *urlsOfFeeds;
    dispatch_queue_t backgroundSerialQueue;
    dispatch_queue_t backgroundGlobalQueue;
    
    NSManagedObjectContext *managedObjectContext;
    UIRefreshControl *refreshControl;
    NSString *currentChannelUrl;
    NSMutableArray* postsToAppendToUrl;
    UIBarButtonItem *popoverButton;
    BOOL isPopoverVisible;
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
    
    // register custom nib for cell
    [self.tableView registerNib:[UINib nibWithNibName:@"FeedItemTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"FeedItemTableViewCell"];
    
    dataController = [ASCoreDataController sharedInstance];
    managedObjectContext = [dataController writerContext];
    
    _responseData = [[NSMutableData alloc] init];
    tabBarController = [self tabBarController];
    makeRefresh = NO;
    isDataLoaded = NO;
    backgroundSerialQueue = dispatch_queue_create("pl.skierbisz.postPreparingQueue", NULL);
    backgroundGlobalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0);
    [self internetConnectionChecking];
    [self uiSetSpiner:YES];
    
    popoverButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"sort"]
                                                    style:UIBarButtonItemStylePlain
                                                    target:self
                                                    action:@selector(presentSearchPopover)];
//                                      initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
//                                      target:self
//                                      action:@selector(presentSearchPopover)];
    
    self.navigationItem.rightBarButtonItem = popoverButton;
    
    //--------------------------------------//
    // --> Choose how to load data at start //
    //--------------------------------------//
    //
    //[self getActualDataFromConnection];
    //[self loadPostsFromDtabase];
    //
    //--------------------------------------//
    // -->ASCoreDataController
    //
    postsToDisplaySource = [dataController loadPostsFromDtabaseUsingUrls];
    //[self uiUpdateMainFeedTable] jest w viewWillApppear
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
#pragma mark - Popover
//*****************************************************************************/
- (void)presentSearchPopover{
    isPopoverVisible = YES;
    ASPopoverViewController *dateVC = [[ASPopoverViewController alloc] init];
    UINavigationController *destNav = [[UINavigationController alloc] initWithRootViewController:dateVC];/*Here dateVC is controller you want to show in popover*/
    dateVC.preferredContentSize = CGSizeMake(280,150);
    destNav.modalPresentationStyle = UIModalPresentationPopover;
    _sortPopover = destNav.popoverPresentationController;
    _sortPopover.delegate = self;
    _sortPopover.sourceView = self.view;
    _sortPopover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    _sortPopover.sourceRect = [self makeSourceRectWithWidth];
    _sortPopover.barButtonItem = popoverButton;// destNav.modalPresentationStyle = UIModalPresentationPopover;
    destNav.navigationBarHidden = YES;
    [self presentViewController:destNav animated:YES completion:nil];
}

- (UIModalPresentationStyle) adaptivePresentationStyleForPresentationController: (UIPresentationController * ) controller {
    return UIModalPresentationNone;
}

- (void)prepareForPopoverPresentation:(UIPopoverPresentationController *)popoverPresentationController{
}

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController{
    NSLog(@" popover dismissed");
    isPopoverVisible = NO;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    //TODO: displaying popover when changing location
    if(isPopoverVisible){
        _sortPopover.sourceRect = [self makeSourceRectWithWidth];
    }
}

-(CGRect)makeSourceRectWithWidth{
    CGFloat width = [[UIScreen mainScreen] bounds].size.width;
    CGRect rect = CGRectMake(width-10.0f, 0.0f, 0.0f, 0.0f);
    return rect;
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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(markPostAsLiked:)
                                                 name:@"pl.skierbisz.webviewscreen.post.liked"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(markPostAsUnLiked:)
                                                 name:@"pl.skierbisz.webviewscreen.post.unliked"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(uiUpdateMainFeedTable)
                                                 name:@"pl.skierbisz.searchpopover.search.subject.changed"
                                               object:nil];
}
-(void)styleTheView{
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
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
    //[self loadUrlsFromDatabase];
    //-->ASCoreDataController
    urlsOfFeeds = [dataController loadUrlsFromDatabase];
    [self makeRequestAndConnectionWithNSSession];
}


-(void)endOfLoadingData{
    NSLog(@"endOfLoadingData");
    if(isDataLoaded){
        //dispatch_async(backgroundGlobalQueue, ^{
        
        postsToDisplaySource = [[NSMutableArray alloc]initWithArray:postsToDisplayIntermediate];
        NSLog(@"postsToDisplay count %d", (int)[postsToDisplaySource count]);
        //}];
        [self uiUpdateMainFeedTable];
    }
}
// Synchonous request with NSURLSesion
-(void)makeRequestAndConnectionWithNSSession{
    NSError __block *error = nil;
    NSURLResponse __block *response = nil;
    postsToDisplayIntermediate = [[NSMutableArray alloc] init];
    
    NSMutableArray __block *tmpArrayOfStringUrl = [[NSMutableArray alloc] init];
    //TODO czemu w tej atblicy stringów pojawia sie nil skoro w getActualDataFromConnection są poprawne url.url'e????
    for(Url* feedUrl in urlsOfFeeds){
        if(feedUrl.url == nil){
            NSLog(@"nil w tablicy urlsOfFeeds");
        }else{
            [tmpArrayOfStringUrl addObject:feedUrl.url];
        }
        
    }

    dispatch_async(backgroundGlobalQueue,^{
        if(urlsOfFeeds.count != 0){
            
            for(NSString* feedUrl in tmpArrayOfStringUrl){
                _responseData = [[NSMutableData alloc] init];
                postsToAppendToUrl = [[NSMutableArray alloc]init];
                NSURL *url = [NSURL URLWithString: feedUrl];
                
                NSData *datatToAppend = [NSURLSession sendSynchronousDataTaskWithURL:url returningResponse:&response error:&error];
                if(error != nil){
                    NSLog(@"There was an error with synchrononous request: %@", error.description);
                    //[self connectionDidFailedWithError:error];
                }else{
                    [_responseData appendData:datatToAppend];
                    [self makeParsing];
                    
                    
                    for(FeedItem *item in postsToAppendToUrl){
                        item.sourceFeedUrl = [NSMutableString stringWithString:feedUrl];
                    }
                    
                    //--> ASDCoreDataController
                    [dataController savePostsToCoreDataFromUrl:feedUrl andPost:postsToAppendToUrl];
                    //[self savePostsToCoreDataFromUrl:feedUrl andPosts:(NSMutableArray*)postsToAppendToUrl];
                    
                    [postsToDisplayIntermediate addObjectsFromArray:postsToAppendToUrl];
                }
            }
        }else{
            postsToDisplaySource = nil;
            [dataController deleteAllEntities:@"Url" withContext:[dataController generateBackgroundManagedContext]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self endOfLoadingData];
        });
    });
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
    for (NSManagedObject *object in fetchedObjects)    {
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
    if (postsToDisplaySource == nil){
        return 0;
    }
    [self sortPostsByUserDefaults];
    return postsToDisplaySource.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * cellIdentifier = @"FeedItemTableViewCell";
    //FeedTableViewCell *cell = (FeedTableViewCell *)[tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    //(FeedTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[@"FeedCell" forIndexPath:indexPath];
    FeedItemTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    cell.controller = self;//! necessary to use Prototype cell defined in XIB !!!
    
    FeedItem *tmpItem = [postsToDisplaySource objectAtIndex:indexPath.row];
    cell.postImage.image = [UIImage imageNamed:@"postImage"];
    cell.postTitle.text = tmpItem.title;
    cell.postTitle.textColor = [UIColor blackColor];
    cell.postAdditionalInfo.textColor = [UIColor blackColor];
    NSString *cleanedDescription = [ASTextCleaner cleanFromTagsWithScanner: tmpItem.shortText];
    cell.postAdditionalInfo.text = [NSString stringWithFormat:@" %@ \n %@", tmpItem.pubDate, cleanedDescription];
    if([tmpItem.isRead isEqualToNumber:[NSNumber numberWithInteger:1]]){
        cell.postTitle.textColor = [UIColor grayColor];
        cell.postAdditionalInfo.textColor = [UIColor grayColor];
    }
    if([tmpItem.isLiked isEqualToNumber:[NSNumber numberWithInteger:1]]){
        [cell.favouriteButton setImage:[UIImage imageNamed:@"star_active"] forState:UIControlStateNormal];
    }else{
        
        [cell.favouriteButton setImage:[UIImage imageNamed:@"star_inactive"] forState:UIControlStateNormal];
    }
    
    return cell;
}

//*****************************************************************************/
#pragma mark - Table view - helper methods
//*****************************************************************************/
-(void)sortPostsBy:(NSString*)sorter{
    //Sorting posts
    BOOL isAscending = [[NSUserDefaults standardUserDefaults] boolForKey:@"sortAscending"];
    NSArray *sortedPosts = [[postsToDisplaySource copy]sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:sorter ascending:isAscending]]];
    postsToDisplaySource = sortedPosts;
}

-(void)sortPostsByUserDefaults{
    //Sorting posts
    NSString *sorter;
    BOOL isAscending = [[NSUserDefaults standardUserDefaults] boolForKey:@"sortAscending"];
    NSInteger sortingSubject = [[NSUserDefaults standardUserDefaults] integerForKey:@"sortingSubject"];
        
    switch (sortingSubject) {
        case 0:
            sorter = @"title";
            break;
        case 1:
            sorter = @"pubDate";
            break;
        default:
            sorter = @"title";
            break;
    }
    NSArray *sortedPosts = [[postsToDisplaySource copy]sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:sorter ascending:isAscending]]];
    postsToDisplaySource = sortedPosts;
}

-(void) markPostAsLiked:(NSNotification *)notification {
    NSDictionary *dict = [notification userInfo];
    NSLog(@"-----Dict: %@", dict);
    FeedItem *itemToCompare = [[FeedItem alloc]init];
    itemToCompare.guid = [dict valueForKey:@"guid"];
    itemToCompare.title = [dict valueForKey:@"title"];
    
    
    for (FeedItem *item in postsToDisplaySource) {
        if ([item.title isEqualToString:itemToCompare.title]) {
            [dataController savePost:itemToCompare asFavourite:YES]; //save data to Core Data
            item.isLiked = [NSNumber numberWithBool:YES]; //modify table view data source -> postsToDisplaySource
            [self.tableView reloadData];
            break;
        }
    }
    
}

-(void) markPostAsUnLiked:(NSNotification *)notification {
    NSDictionary *dict = [notification userInfo];
    NSLog(@"-----Dict: %@", dict);
    FeedItem *itemToCompare = [[FeedItem alloc]init];
    itemToCompare.guid = [dict valueForKey:@"guid"];
    itemToCompare.title = [dict valueForKey:@"title"];
    
    
    for (FeedItem *item in postsToDisplaySource) {
        if ([item.title isEqualToString:itemToCompare.title]) {
            [dataController savePost:itemToCompare asFavourite:NO]; //save data to Core Data
            item.isLiked = [NSNumber numberWithBool:NO]; //modify table view data source -> postsToDisplaySource
            [self.tableView reloadData];
            break;
        }
    }
    
}

-(void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {

//    UITableView *tableView = self.tableView;
    
    switch (type) {
        case NSFetchedResultsChangeInsert:
//            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
//            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate: {
//            Course *changedCourse = [self.fetchedResultsController objectAtIndexPath:indexPath];
//            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
//            cell.textLabel.text = ...;
        }
            break;
            
        case NSFetchedResultsChangeMove:
//            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
//            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [[postsToDisplaySource objectAtIndex:[indexPath row]] setIsRead:[[NSNumber alloc] initWithInteger:1]];
    [dataController savePostAsIsRead:[postsToDisplaySource objectAtIndex:[indexPath row]]];
    FeedItemTableViewCell *cell = (FeedItemTableViewCell*)[self.tableView cellForRowAtIndexPath:indexPath];
    [self performSegueWithIdentifier:@"showPostDetailViewFromMain" sender:cell];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"showPostDetailViewFromMain"]){
        NSLog(@"CALL prepareForSegue if");
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        DetailViewController *destinationViewController = segue.destinationViewController;
        FeedItem *item = postsToDisplaySource[indexPath.row];
        destinationViewController.link = item.link;
        destinationViewController.feedItem = item;
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
