//
//  FavouritesTableViewController.m
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import "FavouritesTableViewController.h"

@interface FavouritesTableViewController ()
@property (nonatomic,strong) ASCoreDataController *dataController;
@end

@implementation FavouritesTableViewController{
    NSManagedObjectContext *managedObjectContext;
    NSArray *favouritePosts;
    UIRefreshControl *refreshControl;
}
@synthesize dataController;

//*****************************************************************************/
#pragma mark - View methods
//*****************************************************************************/
- (void)viewDidLoad {
    [super viewDidLoad];
    [self styleTheView];
    [self setPullToRefresh];
    [self preferredStatusBarStyle];
    // register custom nib
    [self.tableView registerNib:[UINib nibWithNibName:@"FeedItemTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"FeedItemTableViewCell"];
    dataController = [ASCoreDataController sharedInstance];
    managedObjectContext = [dataController generateBackgroundManagedContext];
    favouritePosts = [dataController loadFavouritPostFromDatabase];
}

- (void) viewWillAppear:(BOOL)animated{
    ///Data is refreshed to show actual state in case of ex. some posts was unliked
    [self refreshData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

//*****************************************************************************/
#pragma mark - View - helper methods
//*****************************************************************************/

-(void)styleTheView{
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    // Set this in every view controller so that the back button displays back instead of the root view controller name
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
}

-(void)setPullToRefresh{
    refreshControl = [[UIRefreshControl alloc]init];
    [self.tableView addSubview:refreshControl];
    [refreshControl addTarget:self action:@selector(refreshData) forControlEvents:UIControlEventValueChanged];
}
-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}


//*****************************************************************************/
#pragma mark - Data
//*****************************************************************************/

//-(void)loadFavouritPostFromDatabase{
//    favouritePosts = [[NSMutableArray alloc]init];
//    NSPredicate *p =[NSPredicate predicateWithFormat:@"isLiked == %@", [NSNumber numberWithBool:YES]];
//    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"pubDate" ascending:nil];
//    
//    NSFetchRequest *fetchRequest=[[NSFetchRequest alloc] initWithEntityName:@"Post"];
//    fetchRequest.sortDescriptors = @[sortDescriptor];
//    [fetchRequest setPredicate:p];
//    NSError *error;
//    NSArray *fetchedProducts;
//    if (managedObjectContext != nil){
//        fetchedProducts=[managedObjectContext executeFetchRequest:fetchRequest error:&error];
//        if([fetchedProducts count] <=0){
//            //show popup [self showPopupNoRssAvailable];
//        }else{
//            [favouritePosts addObjectsFromArray:fetchedProducts];
//        }
//    }else {
//        NSLog(@"Can't get the record! %@ %@", error, [error localizedDescription]);
//    }
//}


- (void)refreshData{
    favouritePosts = [dataController loadFavouritPostFromDatabase];
    [self.tableView reloadData];
    [refreshControl endRefreshing];
}

//*****************************************************************************/
#pragma mark - Table view data source
//*****************************************************************************/

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(favouritePosts.count == 0){
        return 0;
    }
    return favouritePosts.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * cellIdentifier = @"FeedItemTableViewCell";
    //FeedTableViewCell *cell = (FeedTableViewCell *)[tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    
    FeedItemTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    cell.controller = self; //! necessary to use Prototype cell defined in XIB !!!
    
    FeedItem *tmpItem = [favouritePosts objectAtIndex:indexPath.row];
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
#pragma mark - Navigation
//*****************************************************************************/

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
//    DetailViewController *destinationViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"DetailViewController"];
//    //DetailViewController *destinationViewController = [[DetailViewController alloc]init];
//    FeedItem *tmpItem = [favouritePosts objectAtIndex:[indexPath row]];
//    destinationViewController.link = tmpItem.link;
//    destinationViewController.feedItem = tmpItem;
//    
//    [self presentViewController:destinationViewController animated:YES completion:nil];
    FeedItemTableViewCell *cell = (FeedItemTableViewCell*)[self.tableView cellForRowAtIndexPath:indexPath];
    [self performSegueWithIdentifier:@"showPostDetailViewFromFavourites" sender:cell];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"showPostDetailViewFromFavourites"]){
        NSLog(@"CALL prepareForSegue if");
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        DetailViewController *destinationViewController = segue.destinationViewController;
        FeedItem *item = favouritePosts[indexPath.row];
        destinationViewController.link = item.link;
        destinationViewController.feedItem = item;
    }
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
