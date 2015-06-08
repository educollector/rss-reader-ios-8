#import "UIBarButtonItem+ButtonState.h"

@implementation UIBarButtonItem (ButtonState)

- (ASBarButtonStatus)status{
    return (ASBarButtonStatus)self.status;
}

-(void)setStatus:(ASBarButtonStatus)status{
       self.status = (ASBarButtonStatus)status;
}

@end