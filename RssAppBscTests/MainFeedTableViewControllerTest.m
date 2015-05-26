#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@interface MainFeedTableViewControllerTest : XCTestCase

@end

@implementation MainFeedTableViewControllerTest

NSString* textSample;


- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    textSample = [[NSString alloc]init];
    textSample = @"<****> [&#8230;] […] &#8211 - Pierwszy raz zetknąłem się z tą <****> grą dwa <****> lata temu. Kolega mi <****> pokazał, powiedział, że fajna i warto trochę pograć. Od tego czasu nic się nie zmieniło &#8211; on ciągle w to gra i twierdzi, że nie ma lepszej gry na świecie. To jedna z tych produkcji, które człowiek z zewnątrz nie ogarnia. Walki czołgów. [&#8230;]";
};
- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

- (void)testCleanFromTagsWithScanner{
   // cleanFromTagsWithScanner();
}



@end