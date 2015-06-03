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
    IBOutlet UIBarButtonItem *backBarButtonItem;
    IBOutlet UIBarButtonItem *forwardBarButtonItem;
    IBOutlet UIToolbar *webViewToolbar;
    UIBarButtonItem *shareButton;
    UIBarButtonItem *addToFavourButton;
}

//*****************************************************************************/
#pragma mark - View methods
//*****************************************************************************/

- (void)viewDidLoad {
    [super viewDidLoad];
    self.webView.delegate = self;
    [self uiMakeContent];
    [self uiNavigationBarStyling];
    [self uiMakeWebViewToolbar];
    [self updateButtons];
}

- (void)viewWillDisappear:(BOOL)animated{
    self.navigationController.toolbarHidden = YES;
    self.navigationController.tabBarController.tabBar.hidden = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//*****************************************************************************/
#pragma mark - Preparing layout
//*****************************************************************************/

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
    self.navigationController.tabBarController.tabBar.hidden  = YES;
    
    NSString *backArrowString = @"\U000025C0\U0000FE0E"; //BLACK LEFT-POINTING TRIANGLE PLUS VARIATION SELECTOR
    NSString *forwardArrowString = @"\U000025B6\U0000FE0E"; //FORWARD LEFT-POINTING TRIANGLE PLUS VARIATION SELECTOR
    
    backBarButtonItem = [[UIBarButtonItem alloc]
                                          initWithTitle:backArrowString
                                          style:UIBarButtonItemStylePlain
                                          target:self
                                          action:@selector(webViewGoBack)];
    
    forwardBarButtonItem = [[UIBarButtonItem alloc]
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

//*****************************************************************************/
#pragma mark - webView updating helper methods
//*****************************************************************************/


-(void)webViewGoBack{
    [self.webView goBack];
}

-(void)webViewGoForward{
    [self.webView canGoForward];
}

-(void)updateButtons{
    forwardBarButtonItem.enabled = NO;
    backBarButtonItem.enabled = NO;
    if([self.webView canGoForward]){
        forwardBarButtonItem.enabled = YES;
    }
    if([self.webView canGoBack]){
        backBarButtonItem.enabled = YES;
    }
}

-(void)testMethod{
    NSLog(@"I am a test method! I test nav bar buttons 'share' clicking!");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"pl.skierbisz.webviewscreen.postliked" object:self];
}

-(void)postAddedToFavourite{
    NSDictionary* dict = [NSDictionary dictionaryWithObjects: [NSArray arrayWithObjects:self.feedItem.guid,self.feedItem.title, nil]
                                                     forKeys: [NSArray arrayWithObjects:@"guid", @"title", nil]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"pl.skierbisz.webviewscreen.postliked"
                                                        object:nil
                                                      userInfo:dict];
}

//*****************************************************************************/
#pragma mark - Styling
//*****************************************************************************/

-(void)uiNavigationBarStyling{
    UIImage *shareImage = [[UIImage alloc] init];
    NSString *image = @"share.png";
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cache = [paths objectAtIndex:0];
    NSString *fullPath = [NSString stringWithFormat:@"%@/%@", cache, image];
    shareImage = [UIImage imageWithContentsOfFile:fullPath];
    
    addToFavourButton = [[UIBarButtonItem alloc] initWithTitle: @"Like" style:UIBarButtonItemStyleDone target:self action:@selector(postAddedToFavourite)];
    shareButton = [[UIBarButtonItem alloc] initWithTitle: @"Share" style:UIBarButtonItemStyleDone target:self action:@selector(testMethod)];
    NSArray *barItemArray = [[NSArray alloc]initWithObjects: shareButton,addToFavourButton, nil];
    [self.navigationItem setRightBarButtonItems:barItemArray];
}

//*****************************************************************************/
#pragma mark - UIWebView delegate methods
//*****************************************************************************/
- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    //if statemet lets to load all links on the website
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    
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
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        NSLog(@"User tapped a link: %@", [[request URL] absoluteString]);
    }
    [self updateButtons];
    return YES;
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
