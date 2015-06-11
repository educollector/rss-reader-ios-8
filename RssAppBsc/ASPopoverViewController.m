#import "ASPopoverViewController.h"
#import "PopoverTableViewCell.h"

@interface ASPopoverViewController ()

@end

@implementation ASPopoverViewController{
    NSDictionary *sorterInfo;
    NSArray *sortersNames;
    NSArray *sectionTitles;
    UISegmentedControl *segmentedControl;
    UIButton *ascButton;
    UIButton *descButton;
    BOOL sortAsc;
    NSIndexPath* checkedIndexPath;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // register custom nib for cell
    [self.tableView registerNib:[UINib nibWithNibName:@"PopoverTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"PopoverTableViewCell"];
    sortersNames = [[NSArray alloc]initWithObjects:@"By title",@"By pub date", nil];
    sorterInfo = @{@"section1" : sortersNames,
                   @"section2" : @[@" "]
                      };
    sectionTitles = [[sorterInfo allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    self.view.backgroundColor = [UIColor clearColor];
    self.tableView.tableFooterView.hidden = YES;
    
    //segmented control
    segmentedControl = [[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObjects:@"Ascending", @"Descending", nil]];
    [segmentedControl addTarget:self action:@selector(segmentedControlHasChangedValue:) forControlEvents:UIControlEventValueChanged];
    [segmentedControl center];
    sortAsc = [[[NSUserDefaults standardUserDefaults] objectForKey:@"sortAscending"] boolValue];
    sortAsc ? (segmentedControl.selectedSegmentIndex = 0) : (segmentedControl.selectedSegmentIndex = 1);
    [self.view addSubview:segmentedControl];
}

-(void)viewWillDisappear:(BOOL)animated{
    [self saveSortingSubject];
}

-(void) segmentedControlHasChangedValue: (id) sender {
    UISegmentedControl *segmControl = (UISegmentedControl*) sender;
    switch ([segmControl selectedSegmentIndex]) {
        case 0:
            [self sortAscending];
            break;
        case 1:
            [self sortDescending];
            break;
        case UISegmentedControlNoSegment:
            break;
        default:
            NSLog(@"No option for: %ld", [segmControl selectedSegmentIndex]);
    }
}

-(void)sortAscending{
    // send notyf to main
    [[NSUserDefaults standardUserDefaults] setBool: YES forKey:@"sortAscending"];
    NSLog(@"sortAscending");
}

-(void)sortDescending{
    // send notyf to main
    [[NSUserDefaults standardUserDefaults] setBool: NO forKey:@"sortAscending"];
    NSLog(@"sortDescending");
}

-(void)saveSortingSubject{
    NSString *sortingSubject = sortersNames[[checkedIndexPath row]]; //By title,By pub date, By channel
    if([sortingSubject isEqual:@"By title"]){
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"sortingSubject"];
    }else if([sortingSubject isEqual:@"By pub date"]){
        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"sortingSubject"];
    }else{
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"sortingSubject"];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"pl.skierbisz.searchpopover.search.subject.changed" object:self];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *sectionTitle = [sectionTitles objectAtIndex:section];
    NSArray *thingsInSection = [sorterInfo objectForKey:sectionTitle];
    if (thingsInSection == nil){
        return 0;
    }
    return thingsInSection.count;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    // hide the header of the first section
//    if (section == 0)
//        return 1.0f;
    
    return 32.0f;
    
}
//
//-(UIView*)tableView:(UITableView*)tableView viewForFooterInSection:(NSInteger)section
//{
//    self.tableView.tableFooterView.hidden = true;
//    return [[UIView alloc] initWithFrame:CGRectMake(0,0,0,0)] ;
//    
//}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if (section == 0) {
        return nil;
    } else {
        return [sectionTitles objectAtIndex:section];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * cellIdentifier = @"PopoverTableViewCell";
    PopoverTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: cellIdentifier];
    cell.controller = self;//! necessary to use Prototype cell defined in XIB !!!
    
    NSString *sectionTitle = [sectionTitles objectAtIndex:indexPath.section];
    NSArray *sectionItems = [sorterInfo objectForKey:sectionTitle];
    
    cell.label.text = [sectionItems objectAtIndex:[indexPath row]];
    
    if([checkedIndexPath isEqual:indexPath]){
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    if(indexPath.section == 1){
        [cell addSubview: segmentedControl];
    }
    
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *currentSelectedIndexPath = [tableView indexPathForSelectedRow];
    if (currentSelectedIndexPath != nil)
    {
        [[tableView cellForRowAtIndexPath:currentSelectedIndexPath] setBackgroundColor:[UIColor whiteColor]];
    }
    
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    // Uncheck the previous checked row
    if(checkedIndexPath){
        UITableViewCell* uncheckCell = [tableView
                                        cellForRowAtIndexPath:checkedIndexPath];
        uncheckCell.accessoryType = UITableViewCellAccessoryNone;
    }
    if([checkedIndexPath isEqual:indexPath]){
        checkedIndexPath = nil;
    }
    else{
        UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.selectedBackgroundView = nil;
        [cell setBackgroundColor:[UIColor whiteColor]];
        //cell.selectionStyle = UITableViewCellSelectionStyleNone;
        checkedIndexPath = indexPath;
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
        
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
