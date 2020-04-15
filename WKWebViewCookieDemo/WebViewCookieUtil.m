//
//  WebViewCookieUtil.m
//  WKWebViewCookieDemo
//
//  Created by weiping.lii on 2020/3/24.
//  Copyright © 2020 weiping.lii. All rights reserved.
//

#import "WebViewCookieUtil.h"

@implementation WebViewCookieUtil

+ (WKProcessPool *)sharedProcessPool {
    static WKProcessPool *_sharedPool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedPool = [WKProcessPool new];
    });
    return _sharedPool;
}


+ (void)clientCookieDidUpdate:(NSDictionary *)cookieDict toRemove:(NSArray *)toRemove; {
    NSHTTPCookieStorage *httpCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    // 移除旧的配置
    NSArray<NSHTTPCookie *> *oldCookies = httpCookieStorage.cookies;
    [oldCookies enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        for (NSString *name in toRemove) {
            if ([obj.name isEqualToString:name] && [obj.domain hasSuffix:domainForThisApp]) {
                [httpCookieStorage deleteCookie:obj];
            }
        }
    }];
    
    // Write new Cookie to storage.
    NSArray *cookieObjectArr = [self cookieObjectsFromCookieDict:cookieDict];
    for (NSHTTPCookie *cookie in cookieObjectArr) {
        [httpCookieStorage setCookie:cookie];
    }
    
    if (@available(iOS 11.0, *)) {
        WKHTTPCookieStore *wkCookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
        [wkCookieStore getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull currentCookies) {
            dispatch_group_t cleanGroup = dispatch_group_create();
            for (NSHTTPCookie *cookie in currentCookies) {
                for (NSString *name in toRemove) {
                    if ([cookie.domain hasSuffix:domainForThisApp] && [cookie.name isEqualToString:name]) {
                        dispatch_group_enter(cleanGroup);
                        [wkCookieStore deleteCookie:cookie completionHandler:^{
                            dispatch_group_leave(cleanGroup);
                        }];
                    }
                }
            }
            dispatch_group_notify(cleanGroup, dispatch_get_main_queue(), ^{
                for (NSHTTPCookie *cookie in cookieObjectArr) {
                    [wkCookieStore setCookie:cookie completionHandler:nil];
                }
            });
        }];
    } else {
        //  adjust userScript and reload webView if needed
    }
}

+ (NSArray<NSHTTPCookie *> *)cookieObjectsFromCookieDict:(NSDictionary *)cookieDict {
    NSMutableArray<NSHTTPCookie *> *cookieArr = [NSMutableArray array];
    [cookieDict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        if (![key isEqualToString:@"domain"]
            && ![key isEqualToString:@"path"])
        {
            NSDictionary *properties = @{
                NSHTTPCookieName: key,
                NSHTTPCookieValue: obj,
                NSHTTPCookiePath: @"/",
                NSHTTPCookieDomain: domainForThisApp,
            };
            NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:properties];
            [cookieArr addObject:cookie];
        }
    }];
    return [cookieArr copy];
}

+ (void)updateCookieScriptForWKWebviewInIOS10OrEarlier:(WKWebView *)webView {
    if (webView) {
        WKUserContentController *userContentController = webView.configuration.userContentController;
        [userContentController removeAllUserScripts];
        WKUserScript *cookieScript = [self cookieScriptForIOS10AndEarlier];
        [userContentController addUserScript:cookieScript];
    }
}

+ (WKUserScript *)cookieScriptForIOS10AndEarlier {
    NSMutableString *temp = @"".mutableCopy;
    NSHTTPCookieStorage *httpCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    [httpCookieStorage.cookies enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![obj.domain isEqualToString:domainForThisApp]) {
            return ;
        }
        NSString *foo = [NSString stringWithFormat:@"%@=%@;domain=%@;path=/",obj.name, obj.value, domainForThisApp];
        [temp appendFormat:@"document.cookie = '%@';\n", foo];
    }];
    WKUserScript * cookieScript = [[WKUserScript alloc] initWithSource:[temp copy] injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    return cookieScript;
}

+ (NSString *)cookieStringForFirstRequestIOS10AndEarlier {
    NSHTTPCookieStorage *httpCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    return [self cookieStringForCurrentDomain:httpCookieStorage.cookies];
}


+ (NSString *)cookieStringForCurrentDomain:(NSArray<NSHTTPCookie *> *)cookies {
    
    NSMutableString *temp = @"".mutableCopy;
    [temp appendFormat:@"domain=%@; path=%@; ", domainForThisApp, @"/"];
    [cookies enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (![obj.domain isEqualToString:domainForThisApp]) {
            return ;
        }
        [temp appendFormat:@"%@=%@; ", obj.name, obj.value];
    }];
    return [temp copy];
}

+ (NSString *)debug_formatedCookieString:(NSString *)cookieString {
    if (cookieString.length) {
        NSArray<NSString *> *components = [cookieString componentsSeparatedByString:@";"];
        components = [components sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
            return [obj1 compare:obj2];
        }];
        return [components componentsJoinedByString:@";\n"];
    }
    return @"";
}
@end

NSString *domainForThisApp = @".bing.com";
