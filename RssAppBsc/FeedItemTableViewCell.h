//
//  FeedItemTableViewCell.h
//  RssAppBsc
//
//  Created by Aleksandra Skierbiszewska on 08.06.2015.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FeedItemTableViewCell : UITableViewCell

@property (nonatomic, weak) UITableViewController *controller;

@property (weak, nonatomic) IBOutlet UIImageView *postImage;
@property (weak, nonatomic) IBOutlet UILabel *postTitle;
@property (weak, nonatomic) IBOutlet UILabel *postAdditionalInfo;
@property (weak, nonatomic) IBOutlet UIButton *favouriteButton;
@end
