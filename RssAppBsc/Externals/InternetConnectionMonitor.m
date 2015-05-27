//
//  InternetConnectionMonitor.m
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 10/02/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import "InternetConnectionMonitor.h"

@implementation InternetConnectionMonitor

- (BOOL)canAccessInternet{
    Reachability *IsReachable = [Reachability reachabilityForInternetConnection];
    NetworkStatus internetStats = [IsReachable currentReachabilityStatus];
    
    if (internetStats == NotReachable){
        return NO;
    }
    else{
        return YES;
    }
}



@end
