//
//  MainFeedTableViewController.m
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import "MainFeedTableViewController.h"
#import "NSString+HTML.h"
#define kBgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

@interface MainFeedTableViewController (){
}

@end

@implementation MainFeedTableViewController{
    UITabBarController *tabBarController;
    NSFetchedResultsController *fetchResultController;
    Url *urlToMakeRequest;
    BOOL makeRefresh;
    BOOL __block isDataLoaded;
    InternetConnectionMonitor *monitor;
    NSXMLParser *rssParser;
    NSMutableArray *rssItems;
    NSMutableString *title, *link, *description,*pubDate, *imgLink;
    NSString *currentElement;
    FeedItem *currentRssItem;
    UIActivityIndicatorView *spinner;
    NSMutableArray *linksOfFeeds;
    dispatch_queue_t backgroundSerialQueue;
    dispatch_queue_t backgroundGlobalQueue;
}

- (void)viewDidLoad {
    
    NSLog(@"Main feed - viewDidLoad");
    _responseData = [[NSMutableData alloc] init];
    tabBarController = [self tabBarController];
    makeRefresh = NO;
    isDataLoaded = NO;
    backgroundSerialQueue = dispatch_queue_create("pl.skierbisz.postPreparingQueue", NULL);
    backgroundGlobalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0);
    [self internetConnectionChecking];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    self.tableView.backgroundView.backgroundColor = [UIColor yellowColor];
    // Set this in every view controller so that the back button displays back instead of the root view controller name
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    [self uiSetSpiner:YES];
    //linksOfFeeds = [[NSMutableArray alloc] initWithObjects: @"http://rss.cnn.com/rss/edition.rss",  nil];
    [self getActualDataFromConnection];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(getActualDataFromConnection) name:@"pl.skierbisz.browserscreen.linkadded"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(getActualDataFromConnection) name:@"pl.skierbisz.browserscreen.linkdeleted"
                                               object:nil];
    
    [super viewDidLoad];

}

-(void)getActualDataFromConnection{
    NSLog(@"\n\nMainFeed --- getActualDataFromConnection\n\n");
    [self fetchDataFromDatabase];
    [self makeRequestAndConnectionWithNSSession];
    //[self makeRequestAndConnection];
}

-(void)viewWillAppear:(BOOL)animated{
    NSLog(@"Main feed - viewWillAppear");
    [super viewWillAppear:animated];
}

-(void)fetchDataFromDatabase{
    NSLog(@"Main feed - fetchDataFromDatabase");
    //fetchnig data from database
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Url"];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"url" ascending:YES];
    fetchRequest.sortDescriptors = @[sortDescriptor];
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *managedObjectContext = [appDelegate managedObjectContext];
    if (managedObjectContext != nil) {
        fetchResultController = [[NSFetchedResultsController alloc]
                                 initWithFetchRequest:fetchRequest managedObjectContext:managedObjectContext
                                 sectionNameKeyPath:nil cacheName:nil];
        fetchResultController.delegate = self;
        NSError *error;
        if ([fetchResultController performFetch:&error]) {
            NSArray *tmpUrlsArray = [[NSArray alloc] initWithArray: fetchResultController.fetchedObjects];
            linksOfFeeds = [[NSMutableArray alloc]init];
            if([tmpUrlsArray count] <= 0){
                [self showPopupNoRssAvailable];
            }
            //rewrite the table linksOfFeed to remove feed deleted on BrowseScreen and keep the table up to date
            for(Url* el in tmpUrlsArray){
                [linksOfFeeds addObject:el.url];
            }
        } else {
            NSLog(@"Can't get the record! %@ %@", error, [error localizedDescription]);
        }
    }
}


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

-(void)makeRequestAndConnectionWithNSSession{
    NSLog(@"makeRequestAndConnectionWithNSSession");
    _responseData = [[NSMutableData alloc] init];
    rssItems = [[NSMutableArray alloc] init];
    NSUInteger __block counter = (NSUInteger)0;
    if(linksOfFeeds.count != 0){
        for(NSString* linkToFeed in linksOfFeeds){
            NSURLSession *session = [NSURLSession sharedSession];
            [[session dataTaskWithURL:[NSURL URLWithString: linkToFeed]
                    completionHandler:^(NSData *data,
                                        NSURLResponse *response,
                                        NSError *error) {
                        //Handling the response
                        [_responseData appendData:data];
                        if(error != nil){
                            NSLog(@"There was an error with synchrononous request: %@", error.description);
                            [self connectionDidFailedWithError:error];
                        }
                        ++counter;
                        if(counter  == linksOfFeeds.count){
                            [self makeParsing];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                [self endOfLoadingData];
                            });
                        }
                    }] resume];
        }
    }
    else{
        [self makeParsing];
        [self endOfLoadingData];
    }
}

-(void)makeRequestAndConnection{
    NSLog(@"makeRequestAndConnection");
    _responseData = [[NSMutableData alloc] init];
    NSError __block *error = nil;
    NSURLResponse __block *response = nil;
    rssItems = [[NSMutableArray alloc] init];
    NSURLRequest __block *request =[[NSURLRequest alloc]init];
    
    dispatch_async(backgroundGlobalQueue,^{
        
        for(NSString* linkToFeed in linksOfFeeds){
            NSLog(@"item in table of links: %@", linkToFeed);
            
            NSLog(@"making request");
            request= [NSURLRequest requestWithURL:[NSURL URLWithString: linkToFeed]];
            
            NSData *datatToAppend = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            [_responseData appendData:datatToAppend];
            if(error != nil){
                NSLog(@"There was an error with synchrononous request: %@", error.description);
                [self connectionDidFailedWithError:error];
            }
        }
        [self makeParsing];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self endOfLoadingData];
        });
    });
}

-(void)makeParsing{
    rssParser = [[NSXMLParser alloc] initWithData:(NSData *)_responseData];
    [rssParser setDelegate: self];
    [rssParser parse];
    isDataLoaded = YES;
}

-(void)endOfLoadingData{
    NSLog(@"endOfLoadingData");
    for(FeedItem* el in rssItems){
        NSLog(@"-Element: %@", el.title);
    }
    NSLog(@"rssItems count %d", (int)[rssItems count]);
    if(isDataLoaded){
        [self uiUpdateMainFeedTable];
    }
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
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

-(void)uiUpdateMainFeedTable{
    NSLog(@"uiUpdateMainFeedTable");
    [self.tableView reloadData];
    [self uiSetSpiner:NO];
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//*****************************************************************************/
#pragma mark - Table view data source
//*****************************************************************************/

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return rssItems.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"cellForRowAtIndexPath");
    static NSString * cellIdentifier = @"FeedCell";
    FeedTableViewCell *cell = (FeedTableViewCell *)[tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    //(FeedTableViewCell *)[tableView dequeueReusableCellWithIdentifier:[@"FeedCell" forIndexPath:indexPath];
    FeedItem *tmpItem = [rssItems objectAtIndex:indexPath.row];
    cell.postImage.image = [UIImage imageNamed:@"postImage"];
    cell.postTitle.text = tmpItem.title;
    NSString *cleanedDescription = [self cleanFromTagsWithScanner: tmpItem.descript];
    cell.postAdditionalInfo.text = [NSString stringWithFormat:@" %@ \n %@ ago", tmpItem.pubDate, cleanedDescription];    //NSLog(@"INFO title: %@ ; link: %@ ; descr: %@ ; pubDate: %@", tmpItem.title, tmpItem.link,tmpItem.descript, tmpItem.pubDate);
    return cell;
}

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
#pragma mark - internet Connecting
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
        currentRssItem.descript = [description stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.pubDate = [pubDate stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [rssItems addObject:currentRssItem];
    } else if ([elementName isEqualToString:@"entry"]) {
        currentRssItem.title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.link = [link stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.descript = [description stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        currentRssItem.pubDate = [pubDate stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [rssItems addObject:currentRssItem];
    }
    NSLog(@"PARSING DONE \t%@", currentRssItem.title);
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
        FeedItem *item = rssItems[indexPath.row];
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


@end
