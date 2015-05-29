//
//  CoreDataController.h
//  RssAppBsc
//
//  Created by Aleksandra Skierbiszewska on 29.05.2015.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>


@interface CoreDataController : NSObject

+ (id)sharedInstance;

- (NSManagedObjectContext *)masterManagedObjectContext;
- (NSManagedObjectContext *)newManagedObjectContext;
- (void)saveMasterContext;
- (void)saveBackgroundContext;
- (NSManagedObjectModel *)managedObjectModel;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;

@end
