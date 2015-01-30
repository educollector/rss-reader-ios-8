//
//  BrowserTableViewController.m
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import "BrowserTableViewController.h"
#import "AppDelegate.h"
#import "CustomTableViewCell.h"


@interface BrowserTableViewController ()

@end

@implementation BrowserTableViewController{
    UISearchController *searchController;
    NSFetchedResultsController *fetchResultController;
    NSArray *urls;
    Url *url;
    NSArray *tablica;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    tablica = [NSArray arrayWithObjects:@"Aston Martin", @"Lotus", @"Jaguar", @"Bentley", nil];
    NSLog(@"Tablica count: %ld", tablica.count);
    
    searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchBar.delegate = self; //potrzebna jest delegata, żeby wywołac searchBarSearchButtonClicked:
    [searchController.searchBar sizeToFit];
    self.tableView.tableHeaderView = searchController.searchBar;
    self.definesPresentationContext = YES;
    searchController.searchResultsUpdater = self;
    searchController.dimsBackgroundDuringPresentation = NO;
    
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
    [self.tableView reloadData];
}

- (void) updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSLog(@"updateSearchResultsForSearchController");
    [self filterContentForSearchText:searchController.searchBar.text];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //NSLog(@"Number of rows - Tablica count: %d", tablica.count);
    return [urls count];
}

//---Keyboard----

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    NSLog(@"searchBarSearchButtonClicked");
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    NSManagedObjectContext *managedObjectContext = [appDelegate managedObjectContext];
    url = (Url *)[NSEntityDescription insertNewObjectForEntityForName:@"Url" inManagedObjectContext:managedObjectContext];
    url.url = searchController.searchBar.text;
    NSLog(@"url.url : %@", url.url);
    NSError *error;
    if (![managedObjectContext save:&error]) {
        NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
    
    [searchBar resignFirstResponder];
    
}

- (BOOL) isKeyboardOnScreen
{
    BOOL isKeyboardShown = NO;
    
    NSArray *windows = [UIApplication sharedApplication].windows;
    if (windows.count > 1) {
        NSArray *wSubviews =  [windows[1]  subviews];
        if (wSubviews.count) {
            CGRect keyboardFrame = [wSubviews[0] frame];
            CGRect screenFrame = [windows[1] frame];
            if (keyboardFrame.origin.y+keyboardFrame.size.height == screenFrame.size.height) {
                isKeyboardShown = YES;
            }
        }
    }
    
    return isKeyboardShown;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    //UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    Url *url = (Url*) urls[indexPath.row];
    static NSString *cellIdentifier = @"Cell";
    CustomTableViewCell *cell = (CustomTableViewCell*)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    cell.label.text = url.url;
    return cell;
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
