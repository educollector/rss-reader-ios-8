//
//  MainFeedTableViewController.m
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import "MainFeedTableViewController.h"
#import "FeedItem.h"
#import "FeedTableViewCell.h"
#import "DetailViewController.h"

@interface MainFeedTableViewController (){
    NSXMLParser *rssParser;
    NSMutableArray *rssItems;
    NSMutableString *title, *link, *description,*pubDate, *imgLink;
    NSString *currentElement;
    FeedItem *currentRssItem;
    UIActivityIndicatorView *spinner;
}

@end

@implementation MainFeedTableViewController{
    NSMutableArray *feedItems;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //[self.tableView setHidden:YES];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    self.tableView.backgroundView.backgroundColor = [UIColor yellowColor];
    // Set this in every view controller so that the back button displays back instead of the root view controller name
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    [self uiSetSpiner:YES];
    
    [NSTimer scheduledTimerWithTimeInterval:2.0f
                                     target:self
                                   selector: @selector(makeRequestAndConnection)
                                   userInfo:nil
                                    repeats:NO];
}

-(void)makeRequestAndConnection{
    NSLog(@"makeRequestAndConnection");
    
    NSURLRequest *request =  [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://wiadomosci.wp.pl/ver,rss,rss.xml"] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:3.0f];
    //Create url connection and fire request
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if(!connection){
        _responseData = nil;
        NSLog(@"Request timeout");
    }
}

//change status bar icons form black to white http:/ /stackoverflow.com/questions/17678881/how-to-change-status-bar-text-color-in-ios-7?rq=1
-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

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
    NSString *cleanDescription = [self cleanFromTags: tmpItem.descript];
    cell.postAdditionalInfo.text = [NSString stringWithFormat:@" %@ \n %@ ago", tmpItem.pubDate, cleanDescription];    //NSLog(@"INFO title: %@ ; link: %@ ; descr: %@ ; pubDate: %@", tmpItem.title, tmpItem.link,tmpItem.descript, tmpItem.pubDate);
    return cell;
}

- (NSString *) cleanFromTags:(NSString *)text{
    NSString *cleanedText;
    NSCharacterSet *doNotWant;
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
    
    NSLog(@"\n\ncleanedText------%@\n\n", cleanedText);
    
    //doNotWant = [NSCharacterSet characterSetWithCharactersInString:@"-=+[]{}:/?.><;,!@#$%^&*\n()\r'"];
    //cleanedText = [[text componentsSeparatedByCharactersInSet: doNotWant] componentsJoinedByString: @""];
    return cleanedText;
}

#pragma mark - URL Connecting

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _responseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_responseData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    // Return nil to indicate not necessary to store a cached response for this connection
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    rssItems = [[NSMutableArray alloc] init];
    rssParser = [[NSXMLParser alloc] initWithData:(NSData *)_responseData];
    [rssParser setDelegate: self];
    [rssParser parse];
    NSLog(@"SUCCESS: connectionDidFinishLoading");
    [self performSelectorOnMainThread:@selector(uiUpdateMainFeedTable) withObject:Nil waitUntilDone:YES];
}

-(void)uiUpdateMainFeedTable{
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

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    connection = nil;
    _responseData = nil;
    NSLog(@"Connection failed! Errooooooor - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
    
    UIAlertController *connectionAlert = [UIAlertController
                                          alertControllerWithTitle:@"Coś poszło nie tak"
                                          message:[error localizedDescription]
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okeyAction = [UIAlertAction
                                 actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                                 handler: ^(UIAlertAction *action){
                                     [self makeRequestAndConnection];
                                     NSLog(@"alert - OK clicked");
                                 }];
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action){
                                       [self uiUpdateMainFeedTable];
                                       NSLog(@"alert - Cancel clicked");
                                   }];
    
    [connectionAlert addAction:cancelAction];
    [connectionAlert addAction:okeyAction];
    [self presentViewController:connectionAlert animated:YES completion:nil];
}

#pragma mark - Parsing

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
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if ([currentElement isEqualToString:@"title"]) {
        [title appendString:string];
    } else if ([currentElement isEqualToString:@"link"]) {
        [link appendString:string];
    } else if ([currentElement isEqualToString:@"description"]) {
        [description appendString:string];
    } else if ([currentElement isEqualToString:@"pubDate"]) {
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
        //NSLog(@"INFO title: %@ ; link: %@ ; descr: %@ ; pubDate: %@", currentRssItem.title, currentRssItem.link,currentRssItem.descript, currentRssItem.pubDate);
        
        [rssItems addObject:currentRssItem];
    }
    NSLog(@"PARSING DONE");
}



#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"showPostDetailsFromMain"]){
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        DetailViewController *destinationViewController = segue.destinationViewController;
        FeedItem *item = rssItems[indexPath.row];
        destinationViewController.link = item.link;
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



}


@end
