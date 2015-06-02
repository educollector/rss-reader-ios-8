//
//  FeedItem.m
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import "FeedItem.h"

@implementation FeedItem

-(FeedItem*)initWithDefaultValues{
    self = [super init];
    if(self){
        _title = @"News test title that is not so long";
        _content = @"But I must explain to you how all this mistaken idea of denouncing pleasure and praising pain was born and I will give you a complete account of the system, and expound the actual teachings of the great explorer of the truth, the master-builder of human happiness. No one rejects, dislikes, or avoids pleasure itself, because it is pleasure, but because those who.";
        _site = @"Suer Site Name";
        _time = @"2 hours";
        _sourceFeedUrl = @"http://interia.pl";
    }
    return self;
}

@end
