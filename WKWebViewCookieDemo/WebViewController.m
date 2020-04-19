//
//  WebViewController.m
//  WKWebViewCookieDemo
//
//  Created by weiping.lii on 2020/3/24.
//  Copyright © 2020 weiping.lii. All rights reserved.
//

#import "WebViewController.h"
#import <WebKit/WebKit.h>
#import "WebViewCookieUtil.h"

@interface WebViewController ()<WKUIDelegate, WKNavigationDelegate, WKHTTPCookieStoreObserver>

@property (nonatomic, strong) WKWebView *wkWebView;

@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) WKUserContentController *userContentController;

@end

@implementation WebViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (@available(iOS 11.0, *)) {
        [[WKWebsiteDataStore defaultDataStore].httpCookieStore addObserver:self];
    }
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self.view insertSubview:self.wkWebView atIndex:0];
    [self.view addSubview:self.progressView];
    
    [self.progressView.topAnchor constraintEqualToAnchor:self.wkWebView.topAnchor].active = YES;
    [self.progressView.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
    [self.progressView.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;
    [self.progressView.heightAnchor constraintEqualToConstant:3].active = YES;
    
    if (@available(iOS 11.0, *)) {
        [self.wkWebView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor].active = YES;
    } else {
        [self.wkWebView.topAnchor constraintEqualToAnchor:self.topLayoutGuide.bottomAnchor].active = YES;
    }
    [self.wkWebView.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
    [self.wkWebView.rightAnchor constraintEqualToAnchor:self.view.rightAnchor].active = YES;
    [self.wkWebView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    
    [self loadURLWithCachePolicy:NSURLRequestUseProtocolCachePolicy];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onCookieScriptShouldUpdateNotification:) name:kCookieScriptShouldUpdateNotification object:nil];
}

- (void)dealloc {
    [_wkWebView stopLoading];
    [_wkWebView removeObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress))];
}

- (void)onCookieScriptShouldUpdateNotification:(NSNotification *)notification {
    if (@available(iOS 11.0, *)) {
        //  no need to update cookie script
    } else {
        BOOL shouldReload = [notification.userInfo[keyForReloadWebView] boolValue];
        if (shouldReload) {
            [self reload];
        } else {        
            [WebViewCookieUtil updateCookieScriptForWKWebviewInIOS10OrEarlier:self.wkWebView];
        }
    }
}

#pragma mark - WKHTTPCookieStoreObserver
- (void)cookiesDidChangeInCookieStore:(WKHTTPCookieStore *)cookieStore API_AVAILABLE(macos(10.13), ios(11.0)) {
    [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {
        for (NSHTTPCookie *cookie in cookies) {
            NSLog(@"%@", cookie);
        }
    }];
}

- (void)loadURLWithCachePolicy:(NSURLRequestCachePolicy)cachePolicy {
    NSParameterAssert(self.URL);
    if (!self.URL) {
        return;
    }
    if (@available(iOS 11.0, *)) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.URL cachePolicy:cachePolicy timeoutInterval:10];
        [self.wkWebView loadRequest:request];
    } else {
        NSString *cookieStr = [WebViewCookieUtil cookieStringForFirstRequestIOS10AndEarlier];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.URL cachePolicy:cachePolicy timeoutInterval:10];
        [request addValue:cookieStr forHTTPHeaderField:@"Cookie"];
        [self.wkWebView loadRequest:request];
    }
}

- (void)reload {
    if (@available(iOS 11.0, *)) {
        //  handled by cookie storage
    } else {
        [WebViewCookieUtil updateCookieScriptForWKWebviewInIOS10OrEarlier:self.wkWebView];
    }
    [self loadURLWithCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
}
    
- (IBAction)randomCookieUpdate:(id)sender {
    NSInteger i = arc4random_uniform(100);
    NSDictionary *cookie = @{@"random": [@(i) stringValue]};
    [WebViewCookieUtil clientCookieDidUpdate:cookie toRemove:nil];
}

- (IBAction)onMoreButtonTapped:(id)sender {
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertVC addAction:[UIAlertAction actionWithTitle:@"Reload" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self reload];
    }]];
    
    [alertVC addAction:[UIAlertAction actionWithTitle:@"Clear Default WebsiteDataStore)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes] modifiedSince:[NSDate dateWithTimeIntervalSince1970:1] completionHandler:^{}];
    }]];
    
    [alertVC addAction:[UIAlertAction actionWithTitle:@"Document Cookies" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self.wkWebView evaluateJavaScript:@"document.cookie" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            NSString *message = [WebViewCookieUtil debug_formatedCookieString:result];
            UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"Document Cookies" message:message preferredStyle:UIAlertControllerStyleAlert];
            [alertVC addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alertVC animated:YES completion:nil];
        }];
    }]];
    
    if (@available(iOS 11.0, *)) {
        [alertVC addAction:[UIAlertAction actionWithTitle:@"WKHTTPCookieStorage" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            WKHTTPCookieStore *cookieStore = self.wkWebView? self.wkWebView.configuration.websiteDataStore.httpCookieStore: [WKWebsiteDataStore defaultDataStore].httpCookieStore;
            [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> *cookies){
                NSString* result = [WebViewCookieUtil cookieStringForCurrentDomain:cookies];
                NSString *message = [WebViewCookieUtil debug_formatedCookieString:result];
                UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"CookieStorage" message:message preferredStyle:UIAlertControllerStyleAlert];
                [alertVC addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alertVC animated:YES completion:nil];
            }];
        }]];
    }
    
    [alertVC addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {}]];
    
    [self presentViewController:alertVC animated:YES completion:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webView.URL) {
        webView.opaque = NO;
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(estimatedProgress))] && object == self.wkWebView) {
        [self.progressView setAlpha:1.0f];
        CGFloat progress = self.wkWebView.estimatedProgress;
        BOOL animated = progress > self.progressView.progress;
        [self.progressView setProgress:progress animated:animated];
        
        // Once complete, fade out UIProgressView
        if (progress >= 1.0f) {
            [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
                [self.progressView setAlpha:0.0f];
            } completion:^(BOOL finished) {
                [self.progressView setProgress:0.0f animated:NO];
            }];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


#pragma mark - Initialize

- (WKWebView *)wkWebView{
    if (!_wkWebView) {
        WKWebViewConfiguration * config = [[WKWebViewConfiguration alloc]init];
        config.allowsInlineMediaPlayback = YES;
        config.selectionGranularity = YES;
        if (@available(iOS 11.0, *)) {        
            config.processPool = [WebViewCookieUtil sharedProcessPool];
        }
        config.userContentController = self.userContentController;
        
        _wkWebView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
        _wkWebView.translatesAutoresizingMaskIntoConstraints = NO;
        _wkWebView.navigationDelegate = self;
        _wkWebView.UIDelegate = self;
        [_wkWebView addObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress)) options:0 context:nil];
        _wkWebView.opaque = NO;
        if (@available(iOS 11.0, *)) {
            _wkWebView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
    }
    return _wkWebView;
}

- (WKUserContentController *)userContentController {
    if (!_userContentController) {
        WKUserContentController *userContentController = [WKUserContentController new];
        if (@available(iOS 11.0, *)) {
            //  handled by cookie storage
        } else{
            [userContentController addUserScript:[WebViewCookieUtil cookieScriptForIOS10AndEarlier]];
        }
        _userContentController = userContentController;
    }
    return _userContentController;
}

- (UIProgressView *)progressView {
    if (!_progressView) {
        _progressView = [[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressView.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return _progressView;
}
@end
