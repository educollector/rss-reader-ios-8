//
//  BrowserTableViewController.h
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "Post.h"
#import "Url.h"
#import "FeedItem.h"
#import "ASCoreDataController.h"

@interface BrowserTableViewController : UITableViewController <UISearchResultsUpdating, NSFetchedResultsControllerDelegate, UISearchBarDelegate>

@end
