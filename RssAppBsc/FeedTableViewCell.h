//
//  FeedTableViewCell.h
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MainFeedTableViewController.h"

@interface FeedTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIView *postImage;
@property (weak, nonatomic) IBOutlet UILabel *postTitle;
@property (weak, nonatomic) IBOutlet UILabel *postAdditionalInfo;

@end
