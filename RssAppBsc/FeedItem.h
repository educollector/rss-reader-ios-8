//
//  FeedItem.h
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FeedItem : NSObject

@property (nonatomic, strong) NSMutableString *title;
@property (nonatomic, strong) NSMutableString *link;
@property (nonatomic, strong) NSMutableString *shortText;
@property (nonatomic, strong) NSMutableString *pubDate;
@property (nonatomic, strong) NSDate *pubDateAsDate;
@property (nonatomic, strong) NSMutableString *imageLink;
@property (nonatomic, strong) NSMutableString *content;
@property (nonatomic, strong) NSMutableString *site;
@property (nonatomic, strong) NSMutableString *time;
@property (nonatomic, strong) NSMutableString *sourceFeedUrl;
@property (nonatomic, strong) NSMutableString *guid;
@property (nonatomic, strong) NSNumber *isRead;
@property (nonatomic, strong) NSNumber *isLiked;
-(FeedItem*)initWithDefaultValues;
-(FeedItem*)init;

@end
