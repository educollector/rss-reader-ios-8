//
//  FeedItemTableViewCell.m
//  RssAppBsc
//
//  Created by Aleksandra Skierbiszewska on 08.06.2015.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import "FeedItemTableViewCell.h"

@implementation FeedItemTableViewCell
@synthesize controller;

- (void)awakeFromNib {
    // Initialization code
    //    _postAdditionalInfo.numberOfLines = 0;
    //    [_postAdditionalInfo sizeToFit];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSIndexPath *path = [controller.tableView indexPathForCell:self];
    [controller.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    [controller performSegueWithIdentifier:@"FinishedTask" sender:controller];
    [super touchesEnded:touches withEvent:event];
}

@end