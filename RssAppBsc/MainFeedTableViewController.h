//
//  MainFeedTableViewController.h
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import "FeedItem.h"
#import "FeedTableViewCell.h"
#import "DetailViewController.h"
#import "BrowserTableViewController.h"
#import "InternetConnectionMonitor.h"
#import "Reachability.h"
#import "Url.h"
#import "AppDelegate.h"
#import <dispatch/dispatch.h>
#import "Url.h"
#import "Post.h"
#import "NSURLSession+SynchronousTask.h"
#import "CoreDataController.h"

@interface MainFeedTableViewController : UITableViewController<UITabBarControllerDelegate, NSURLConnectionDataDelegate, NSXMLParserDelegate, NSFetchedResultsControllerDelegate>
{
    NSMutableData *_responseData;
}


@end
