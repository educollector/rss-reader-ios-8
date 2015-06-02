#import <Foundation/Foundation.h>

@interface PostsOfUrls : NSObject{
    NSMutableDictionary *postsOfUrls;
}


-(id)getPostsForUrl:(NSString*)url;
-(id)getAllPosts;
-(id)getAllUrls:(NSArray*)urls;
-(void)appendDataWithUrl:(NSString*)url andPosts:(NSMutableArray*)posts;

@end
