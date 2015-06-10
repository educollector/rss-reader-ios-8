//
//  PopoverTableViewCell.h
//  RssAppBsc
//
//  Created by Aleksandra Skierbiszewska on 10.06.2015.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PopoverTableViewCell : UITableViewCell
@property (nonatomic, weak) UITableViewController *controller;
@property (weak, nonatomic) IBOutlet UILabel *label;

@end
