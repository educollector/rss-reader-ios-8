//
//  ASTextCleaner.h
//  RssAppBsc
//
//  Created by Aleksandra Skierbiszewska on 08.06.2015.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+HTML.h"

@interface ASTextCleaner : NSObject

+ (NSString *) cleanFromTagsWithRegexp:(NSString *)text;
+ (NSString *)cleanFromTagsWithScanner:(NSString *)text;

@end
