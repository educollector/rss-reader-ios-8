#import "BrowserTableViewController.h"
#import "AppDelegate.h"
#import "CustomTableViewCell.h"
#import "CoreDataController.h"

@interface BrowserTableViewController ()
//@property (nonatomic,strong) NSManagedObjectContext *managedObjectContext;

@end

@implementation BrowserTableViewController{
    UISearchController *searchController;
    NSFetchedResultsController *fetchResultController;
    NSManagedObjectContext *managedObjectContext;
    NSArray *urls;
    Url *url;
}

//@synthesize managedObjectContext;

- (void)viewDidLoad {
    [super viewDidLoad];
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    managedObjectContext = [appDelegate managedObjectContext];
    
    
    searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchBar.delegate = self;
    [searchController.searchBar sizeToFit];
    self.tableView.tableHeaderView = searchController.searchBar;
    self.definesPresentationContext = YES;
    searchController.searchResultsUpdater = self;
    searchController.dimsBackgroundDuringPresentation = NO;
    [self fetchDataFromDatabase];

}

-(void)fetchDataFromDatabase{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Url"];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"url" ascending:YES];
    fetchRequest.sortDescriptors = @[sortDescriptor];
    //AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    //NSManagedObjectContext *managedObjectContext = [appDelegate managedObjectContext];
    //managedObjectContext = [[CoreDataController sharedInstance]newManagedObjectContext];
    if (managedObjectContext != nil) {
        fetchResultController = [[NSFetchedResultsController alloc]
                                 initWithFetchRequest:fetchRequest managedObjectContext:managedObjectContext
                                 sectionNameKeyPath:nil cacheName:nil];
        fetchResultController.delegate = self;
        NSError *error;
        if ([fetchResultController performFetch:&error]) {
            urls = fetchResultController.fetchedObjects;
        } else {
            NSLog(@"Can't get the record! %@ %@", error, [error localizedDescription]);
        }
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
    //AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    //NSManagedObjectContext *managedObjectContext = [appDelegate managedObjectContext];
    url = (Url *)[NSEntityDescription insertNewObjectForEntityForName:@"Url" inManagedObjectContext:managedObjectContext];
    url.url = [NSString stringWithFormat:@"http://%@", searchController.searchBar.text];
    NSLog(@"url.url : %@", url.url);
    NSError *error;
    //saving url to the Core Data
    
        if (![managedObjectContext save:&error]) {
            NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
        }
        
        [self dismissViewControllerAnimated:YES completion:nil];
        searchController.searchBar.text = @"";
        [searchBar resignFirstResponder];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"pl.skierbisz.browserscreen.linkadded" object:self];
    }
    NSLog(@"Url is in database");
}

- (BOOL)isUrlInDatabase:(NSString *)urlToCheck{
    NSEntityDescription *productEntity=[NSEntityDescription entityForName:@"Url" inManagedObjectContext:managedObjectContext];
    NSFetchRequest *fetch=[[NSFetchRequest alloc] init];
    [fetch setEntity:productEntity];
    NSPredicate *p=[NSPredicate predicateWithFormat:@"url == %@", urlToCheck];
    [fetch setPredicate:p];
    // do sorting
    NSError *fetchError;
    NSArray *fetchedProducts=[managedObjectContext executeFetchRequest:fetch error:&fetchError];
    // handle error
    if(fetchedProducts != nil){
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
}
- (void) controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
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

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    //Delete the row from the data source
    //AppDelegate *appDelegate= (AppDelegate *)[UIApplication sharedApplication].delegate;
    //NSManagedObjectContext *managedObjectContext = [appDelegate managedObjectContext];
    if(managedObjectContext != nil){
        Url *urlToDelete = (Url*)[fetchResultController objectAtIndexPath:indexPath];
        [managedObjectContext deleteObject:urlToDelete];
        NSError *error;
        if(![managedObjectContext save:&error]){
            NSLog(@"Can't delete the feed url from the list! %@ %@", error, [error localizedDescription]);
        }
        else{
            NSLog(@"Url delelted");
        }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"pl.skierbisz.browserscreen.linkdeleted" object:self];
    }
    
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
