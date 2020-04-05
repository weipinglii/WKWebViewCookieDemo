//
//  ViewController.m
//  WKWebViewCookieDemo
//
//  Created by weiping.lii on 2020/3/24.
//  Copyright © 2020 weiping.lii. All rights reserved.
//

#import "ViewController.h"
#import "WebViewController.h"
#import "WebViewCookieUtil.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIStackView *cookieInfoStack;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)updateCookie:(id)sender {
    UITextField *tf1 = self.cookieInfoStack.arrangedSubviews.firstObject;
    UITextField *tf2 = self.cookieInfoStack.arrangedSubviews.lastObject;
    NSString *key = tf1.text;
    NSString *value = tf2.text;
    
    NSMutableDictionary *cookieDict = [NSMutableDictionary dictionary];
    cookieDict[key] = value;
    [WebViewCookieUtil clientCookieDidUpdate:cookieDict toRemove:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    WebViewController *webVC = (WebViewController *)segue.destinationViewController;
    NSURL *URL = [NSURL URLWithString:self.textField.text];
    webVC.URL = URL;
    NSParameterAssert(URL);
}




@end
