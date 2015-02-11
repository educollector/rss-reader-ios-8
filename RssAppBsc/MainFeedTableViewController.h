//
//  MainFeedTableViewController.h
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FeedItem.h"
#import "FeedTableViewCell.h"
#import "DetailViewController.h"
#import "InternetConnectionMonitor.h"
#import "Reachability.h"
#import "Url.h"


@interface MainFeedTableViewController : UITableViewController<NSURLConnectionDataDelegate, NSXMLParserDelegate>
{
    NSMutableData *_responseData;
}


@end
