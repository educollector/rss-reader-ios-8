//
//  DetailViewController.m
//  RssAppBsc
//
//  Created by Ola Skierbiszewska on 29/01/15.
//  Copyright (c) 2015 Ola Skierbiszewska. All rights reserved.
//

#import "DetailViewController.h"


@interface DetailViewController ()

@end

@implementation DetailViewController{
    NSURL *urlToLoad;
    IBOutlet UIBarButtonItem *backButton;
    IBOutlet UIBarButtonItem *forwardButton;
    IBOutlet UIBarButtonItem *stopButton;
    IBOutlet UIToolbar *webViewToolbar;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.webView.delegate = self;
    [self uiMakeContent];
    [self uiNavigationBarStyling];
    [self uiMakeWebViewToolbar];
}
-(void)uiMakeContent{
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor clearColor];    
    self.webView.scalesPageToFit = YES;
    urlToLoad = [[NSURL alloc] initWithString: self.link];
    NSURLRequest *request = [NSURLRequest requestWithURL:urlToLoad];
    [self.webView loadRequest:request];
}

-(void)uiMakeWebViewToolbar{
    self.navigationController.toolbarHidden = NO;
    self.tabBarController.tabBar.hidden = YES;
   CGRect frame = CGRectMake(0, [[UIScreen mainScreen] bounds].size.height - 44-49, [[UIScreen mainScreen] bounds].size.width, 44);
//    webViewToolbar = [[UIToolbar alloc]initWithFrame:frame];
//    webViewToolbar.backgroundColor = [UIColor orangeColor];
//    webViewToolbar.barStyle = UIBarStyleBlackTranslucent;
//    [webViewToolbar sizeToFit];
//    [self.view addSubview:webViewToolbar];
    
    NSString *backArrowString = @"\U000025C0\U0000FE0E"; //BLACK LEFT-POINTING TRIANGLE PLUS VARIATION SELECTOR
    NSString *forwardArrowString = @"\U000025BA\U0000FE0E"; //FORWARD LEFT-POINTING TRIANGLE PLUS VARIATION SELECTOR
    
    UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc]
                                          initWithTitle:backArrowString
                                          style:UIBarButtonItemStylePlain
                                          target:self
                                          action:@selector(webViewGoBack)];
    UIBarButtonItem *forwardBarButtonItem = [[UIBarButtonItem alloc]
                                          initWithTitle:forwardArrowString
                                          style:UIBarButtonItemStylePlain
                                          target:self
                                          action:@selector(webViewGoForward)];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil
                                      action:nil];

    NSArray *items = [NSArray arrayWithObjects:backBarButtonItem, flexibleSpace, forwardBarButtonItem, nil];
    self.toolbarItems = items;
    
    self.navigationController.toolbar.frame = CGRectMake(0,
                                [[UIScreen mainScreen] bounds].size.height - self.navigationController.toolbar.frame.size.height,
                                self.navigationController.toolbar.frame.size.width,
                                self.navigationController.toolbar.frame.size.height);
}

-(void)webViewGoBack{
    if ([self.webView canGoBack])
    {
        [self.webView goBack];
    }
}

-(void)webViewGoForward{
    if ([self.webView canGoForward])
    {
        [self.webView canGoForward];
    }
}
                                        
                                          
-(void)uiNavigationBarStyling{
    UIImage *shareImage = [[UIImage alloc] init];
    NSString *image = @"share.png";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cache = [paths objectAtIndex:0];
    NSString *fullPath = [NSString stringWithFormat:@"%@/%@", cache, image];
    shareImage = [UIImage imageWithContentsOfFile:fullPath];
    
    UIBarButtonItem *btn =[[UIBarButtonItem alloc] initWithImage:shareImage landscapeImagePhone:shareImage style:UIBarButtonItemStyleDone target:self action:@selector(testMethod)];
    
    UIBarButtonItem *addToFavourButton = [[UIBarButtonItem alloc] initWithTitle: @"Like" style:UIBarButtonItemStyleDone target:self action:@selector(testMethod)];
    UIBarButtonItem *shareButton = [[UIBarButtonItem alloc] initWithTitle: @"Share" style:UIBarButtonItemStyleDone target:self action:@selector(testMethod)];
    NSArray *barItemArray = [[NSArray alloc]initWithObjects: shareButton,addToFavourButton,btn, nil];
    [self.navigationItem setRightBarButtonItems:barItemArray];
}

-(void)testMethod{
    NSLog(@"I am a test method! I test nav bar buttons clicking!");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark UIWebView delegate methods
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    //if statemet lets to load all links on the website
    if(!([error code] == NSURLErrorCancelled)){
        NSLog(@"could not load the website caused by error: %@", error);

        NSLog(@"Connection failed! Errooooooor - %@ %@",
              [error localizedDescription],
              [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);

        UIAlertController *connectionAlert = [UIAlertController
                                              alertControllerWithTitle:@"Coś poszło nie tak"
                                              message:[error localizedDescription]
                                              preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *okeyAction = [UIAlertAction
                                     actionWithTitle:@"Try again"
                                     style:UIAlertActionStyleDefault
                                     handler: ^(UIAlertAction *action){
                                         [self uiMakeContent];
                                     }];
        UIAlertAction *cancelAction = [UIAlertAction
                                       actionWithTitle:@"Cancel"
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction *action){
                                           [self.navigationController popViewControllerAnimated:YES];
                                       }];

        [connectionAlert addAction:cancelAction];
        [connectionAlert addAction:okeyAction];
        [self presentViewController:connectionAlert animated:YES completion:nil];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSLog(@"shouldStartLoadWithRequest: %@", [[request URL] absoluteString]);
    return YES;
}
- (void)webViewDidStartLoad:(UIWebView *)webView {
    NSLog(@"webViewDidStartLoad");
    
}
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"webViewDidFinishLoad");
    if (webView.isLoading){
        NSLog(@"webview.isLoading");
    }
    else{
        NSLog(@"webview NOT isLoading");
    }
    return;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
