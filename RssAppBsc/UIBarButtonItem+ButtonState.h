//
//  UIBarButtonItem+ButtonState.h
//  RssAppBsc
//
//  Created by Aleksandra Skierbiszewska on 08.06.2015.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum{
    ASBarButtonStatusIsFavourite,
    ASBarButtonStatusIsNotFavourite
} ASBarButtonStatus;


@interface UIBarButtonItem (ButtonState)
@property(nonatomic) ASBarButtonStatus status;
@end
