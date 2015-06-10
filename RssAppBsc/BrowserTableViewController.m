#import "BrowserTableViewController.h"
#import "CustomTableViewCell.h"
#import "CoreDataController.h"

@interface BrowserTableViewController ()

@end

@implementation BrowserTableViewController{
    UISearchController *searchController;
    NSFetchedResultsController *fetchResultController;
    NSManagedObjectContext *managedObjectContextMain;
    NSManagedObjectContext *managedObjectContextBg;
    NSArray *urls;
    Url *url;
    ASCoreDataController *dataColntroller;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    dataColntroller = [ASCoreDataController sharedInstance];
    managedObjectContextMain = [dataColntroller mainContext];
    managedObjectContextBg = [dataColntroller generateBackgroundManagedContext];
    
    
    searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchBar.delegate = self;
    [searchController.searchBar sizeToFit];
    self.tableView.tableHeaderView = searchController.searchBar;
    self.definesPresentationContext = YES;
    searchController.searchResultsUpdater = self;
    searchController.dimsBackgroundDuringPresentation = NO;
    //urls = [dataColntroller loadUrlsFromDatabase];
    [self fetchDataFromDatabase];
}

-(void)fetchDataFromDatabase{
    
    if (managedObjectContextMain!= nil) {
        fetchResultController = [[NSFetchedResultsController alloc]
                                 initWithFetchRequest:[dataColntroller fetchRequestUrls]
                                 managedObjectContext: managedObjectContextMain
                                 sectionNameKeyPath:nil
                                 cacheName:nil];
        fetchResultController.delegate = self;
        NSError *error;
        if ([fetchResultController performFetch:&error]) {
            urls = fetchResultController.fetchedObjects;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self.tableView reloadData];
            }];
        } else {
            NSLog(@"Can't get the record! %@ %@", error, [error localizedDescription]);
        }
        
//        [[fetchResultController managedObjectContext] performBlock:^{
//            NSError *error;
//            if ([fetchResultController performFetch:&error]) {
//                urls = fetchResultController.fetchedObjects;
//                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//                    [self.tableView reloadData];
//                }];
//            } else {
//                NSLog(@"Can't get the record! %@ %@", error, [error localizedDescription]);
//            }
//        }];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)filterContentForSearchText:(NSString *)searchText {
    NSLog(@"filterContentForSearchText + %@", searchController.searchBar.text);
}

- (void) updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSLog(@"updateSearchResultsForSearchController");
    //[self filterContentForSearchText:searchController.searchBar.text];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [urls count];
}

// addling feed URL to the list
//*******************************************************************/
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    BOOL isTheLinkValid = [self validateUrl:searchController.searchBar.text];
    if(!isTheLinkValid){
        NSLog(@"String validation : invalid: %d",isTheLinkValid);
    }else{
        NSLog(@"String validation : valid");
    }
    if(![self isUrlInDatabase: [NSString stringWithFormat:@"http://%@", searchController.searchBar.text]]){
        NSLog(@"Can save an url");
        url = (Url *)[NSEntityDescription insertNewObjectForEntityForName:@"Url" inManagedObjectContext:managedObjectContextMain];
        url.url = [NSString stringWithFormat:@"http://%@", searchController.searchBar.text];
        NSError *error;
        //saving url to the Core Data
        if (![managedObjectContextMain save:&error]) {
            NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
        }
        
        [self dismissViewControllerAnimated:YES completion:nil];
        searchController.searchBar.text = @"";
        [searchBar resignFirstResponder];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pl.skierbisz.browserscreen.linkadded" object:self];
        NSLog(@"Success - Url added to databese");
    }else{
        [self showPopupUrlIsInDatabase];
        NSLog(@"Url is in database - no need to add again");
    }
    
}

- (BOOL)isUrlInDatabase:(NSString *)urlToCheck{
    NSEntityDescription *productEntity=[NSEntityDescription entityForName:@"Url" inManagedObjectContext:managedObjectContextMain];
    NSFetchRequest *fetch=[[NSFetchRequest alloc] init];
    [fetch setEntity:productEntity];
    NSPredicate *p=[NSPredicate predicateWithFormat:@"url == %@", urlToCheck];
    [fetch setPredicate:p];
    // do sorting
    NSError *fetchError;
    NSArray *fetchedProducts=[managedObjectContextMain executeFetchRequest:fetch error:&fetchError];
    // handle error
    if(fetchedProducts.count != 0){
        return YES;
    }
    return NO;

}
//*******************************************************************/

- (BOOL) validateUrl: (NSString *) candidate {
    NSString *urlRegEx =
    @"(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:candidate];
}


- (void) controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}
- (void) controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
        atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
       newIndexPath:(NSIndexPath *)newIndexPath {
        dispatch_async(dispatch_get_main_queue(), ^{
            switch (type) {
                case NSFetchedResultsChangeInsert:
                    [self.tableView insertRowsAtIndexPaths:@[newIndexPath]
                                          withRowAnimation:UITableViewRowAnimationFade];
                    break;
                case NSFetchedResultsChangeDelete:
                    [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                                          withRowAnimation:UITableViewRowAnimationFade];
                    break;
                case NSFetchedResultsChangeUpdate:
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                          withRowAnimation:UITableViewRowAnimationFade];
                    break;
                default:
                    [self.tableView reloadData];
                    break;
            }
            urls = controller.fetchedObjects;
        });
}
- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView endUpdates];
    });
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    //UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

        Url *urlToDisplay = (Url*) urls[indexPath.row];
        static NSString *cellIdentifier = @"Cell";
        CustomTableViewCell *cell = (CustomTableViewCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        cell.label.text = urlToDisplay.url;
        return cell;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

// deleting feed URL from the list
//*******************************************************************/
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    //Delete the row from the data source
    if([fetchResultController managedObjectContext] != nil & editingStyle == UITableViewCellEditingStyleDelete){
        
        Url *urlToDelete = (Url*)[fetchResultController objectAtIndexPath:indexPath];
        
        [[fetchResultController managedObjectContext]  deleteObject:urlToDelete];
        NSError *error;
        if(![[fetchResultController managedObjectContext]  save:&error]){
            NSLog(@"Can't delete the feed url from the list! %@ %@", error, [error localizedDescription]);
        }
        else{
            NSLog(@"Url delelted");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"pl.skierbisz.browserscreen.linkdeleted" object:self];
        }
    }
    
}

//*****************************************************************************/
#pragma mark - Popups
//*****************************************************************************/

-(void)showPopupUrlIsInDatabase{
    NSLog(@"showPopupNoRssAvailable");
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:@"Ooops"
                                message:@"Kanał już jest obserwowany"
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okeyAction = [UIAlertAction
                                 actionWithTitle:@"OK"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *acton){
                                 }];
    [alert addAction:okeyAction];
    //self.parentViewController to avoid "presenting view controllers on detached view controllers is discouraged"
    [self.parentViewController presentViewController:alert animated:YES completion:nil];
}

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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
