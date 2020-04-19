//
//  WebViewCookieUtil.h
//  WKWebViewCookieDemo
//
//  Created by weiping.lii on 2020/3/24.
//  Copyright © 2020 weiping.lii. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WebViewCookieUtil : NSObject

+ (WKProcessPool *)sharedProcessPool;

//  call when cookie updates
+ (void)clientCookieDidUpdate:(NSDictionary *_Nullable)cookieDict toRemove:(NSArray *_Nullable)toRemove;

+ (void)updateCookieScriptForWKWebviewInIOS10OrEarlier:(WKWebView *_Nullable)webView;

+ (WKUserScript *)cookieScriptForIOS10AndEarlier;

+ (NSString *)cookieStringForFirstRequestIOS10AndEarlier;

+ (NSString *)cookieStringForCurrentDomain:(NSArray<NSHTTPCookie *> *)cookies;

+ (NSString *)debug_formatedCookieString:(NSString *)cookieString;

@end

extern NSString *domainForThisApp;
extern NSString *domainComponentForThisApp;

//  for iOS10 and earlier
extern NSString * const kCookieScriptShouldUpdateNotification;
extern NSString * const keyForReloadWebView;

NS_ASSUME_NONNULL_END

