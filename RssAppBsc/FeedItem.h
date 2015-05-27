//
//  FeedItem.h
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FeedItem : NSObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *link;
@property (nonatomic, strong) NSString *shortText;
@property (nonatomic, strong) NSString *pubDate;
@property (nonatomic, strong) NSString *imageLink;
@property (nonatomic, strong) NSString *content;
@property (nonatomic, strong) NSString *site;
@property (nonatomic, strong) NSString *time;
@property (nonatomic, strong) NSString *url;

-(FeedItem*)initWithDefaultValues;

@end
