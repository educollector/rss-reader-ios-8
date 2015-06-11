// MORE INFO: http://code.tutsplus.com/tutorials/ios-sdk-customizing-popovers--mobile-16090
#import <UIKit/UIKit.h>

@interface PopoverBackgroundView : UIPopoverBackgroundView

+ (CGFloat)arrowBase;
+ (CGFloat)arrowHeight;
+ (UIEdgeInsets)contentViewInsets;

- (UIImage *)drawArrowImage:(CGSize)size;
- (UIModalPresentationStyle) adaptivePresentationStyleForPresentationController: (UIPresentationController * ) controller;

@end
