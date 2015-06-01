#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface ASCoreDataController : NSObject


+ (id)sharedInstance;

- (NSManagedObjectContext *)writerManagedObjectContext;
- (NSManagedObjectContext *)mainManagedObjectContext;
//- (NSManagedObjectContext *)privateBackgroundManagedObjectContext;
- (void)saveWriterContext;
- (void)saveMainContext;
- (void)saveBackgroundContext:(NSManagedObjectContext*)backgroundContext;
- (NSManagedObjectContext*)generateBackgroundManagedContext;
- (NSManagedObjectModel *)managedObjectModel;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;

@end
