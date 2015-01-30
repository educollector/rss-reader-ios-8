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

@implementation DetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //---WEBVIEW----
    self.webView.delegate = self;
    NSURL *url = [[NSURL alloc] initWithString: @"http://programmingteam.pl"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
    
    //---NAV BAR Buttons----
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
    NSLog(@"I am a test method!");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"Error : %@",error);
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSLog(@"shouldStartLoadWithRequest: %@", [[request URL] absoluteString]);
    return YES;
}
- (void)webViewDidStartLoad:(UIWebView *)webViewa {
    NSLog(@"webViewDidStartLoad");
    
}
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"webViewDidFinishLoad");
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
