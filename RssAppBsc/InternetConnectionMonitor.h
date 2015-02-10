//
//  InternetConnectionMonitor.h
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 10/02/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability.h"



@interface InternetConnectionMonitor : NSObject

- (BOOL)canAccessInternet;

@end
