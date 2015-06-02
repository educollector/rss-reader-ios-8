#import "PostsOfUrls.h"
#import "Post.h"
#import "Url.h"
#import "FeedItem.h"



@implementation PostsOfUrls

-(id)getPostsForUrl:(NSString*)url{
    if(postsOfUrls){
        return[postsOfUrls objectForKey:url];
    }
    return nil;
}

-(id)getAllPosts{
    if(postsOfUrls){
        NSArray *keys = [postsOfUrls allKeys];
        NSMutableArray *posts = [[NSMutableArray alloc]init];
        
        for(NSString* url in keys){
            [posts addObjectsFromArray: [postsOfUrls valueForKey:url]];
        }
        return posts;
    }
    return nil;
    
}

-(id)getAllUrls:(NSArray*)urls{
    if(postsOfUrls){
        NSArray *keys = [postsOfUrls allKeys];
        return keys;
    }
    return  nil;
}
-(void)appendDataWithUrl:(NSString*)url andPosts:(NSMutableArray*)posts{
    if(!postsOfUrls)    {
        postsOfUrls =[[NSMutableDictionary alloc]init];
    }
    [postsOfUrls setObject:posts forKey:url];
    
}
@end


