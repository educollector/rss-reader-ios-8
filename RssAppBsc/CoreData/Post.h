#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Url;

@interface Post : NSManagedObject

@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSString * imageLink;
@property (nonatomic, retain) NSString * link;
@property (nonatomic, retain) NSString * pubDate;
@property (nonatomic, retain) NSString * shortText;
@property (nonatomic, retain) NSString * site;
@property (nonatomic, retain) NSString * time;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) Url *sourceFeedUrl;

@end
