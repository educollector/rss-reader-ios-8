//
//  Url.h
//  RssAppBsc
//
//  Created by Aleksandra Skierbiszewska on 27.05.2015.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Post;

@interface Url : NSManagedObject

@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSSet *posts;
@end

@interface Url (CoreDataGeneratedAccessors)

- (void)addPostsObject:(Post *)value;
- (void)removePostsObject:(Post *)value;
- (void)addPosts:(NSSet *)values;
- (void)removePosts:(NSSet *)values;

@end
