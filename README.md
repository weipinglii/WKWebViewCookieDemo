# WKWebViewCookieDemo

## 背景
正在维护的项目使用cookie来维护用户登录状态、App版本系统、语言等状态信息。

在UIWebView时代，可以通过`NSHTTPCookieStorage`单例很直接的管理客户端cookie。UIWebView的cookie数据会自动和`NSHTTPCookieStorage`进行同步。然而WKWebView的cookie维护一直为人诟。只要你维护过相关业务，不同iOS版本上出现的各种cookie的问题一定让你头疼过。

这个Demo是目前项目中使用的cookie管理方案，方案来回折腾了好几个月，虽然不是很完整，但是基本满足当前项目需求。

## 方案
初始化时`WKWebsiteDataStore `使用`[WKWebsiteDataStore defaultDataStore]`，`WKProcessPool`使用全局单例。

```
//	webView初始化
- (WKWebView *)wkWebView{
    if (!_wkWebView) {
        WKWebViewConfiguration * config = [[WKWebViewConfiguration alloc]init];
        config.allowsInlineMediaPlayback = YES;
        config.selectionGranularity = YES;
        config.processPool = [WebViewCookieUtil sharedProcessPool];
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
```

通过`NSHTTPCookieStorage`维护客户端cookie，当cookie更新时首先更新`NSHTTPCookieStorage`中，然后在不同的iOS版本使用不同的方式同步到`WKWebView`中。

```
+ (void)clientCookieDidUpdate:(NSDictionary *)cookieDict toRemove:(NSArray *)toRemove {
	//  客户端cookie更新时调用，比如用户登录状态改变
    NSHTTPCookieStorage *httpCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    // 移除Cookie
    NSArray<NSHTTPCookie *> *oldCookies = httpCookieStorage.cookies;
    [oldCookies enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        for (NSString *name in toRemove) {
            if ([obj.domain isEqualToString:name] && [obj.domain isEqualToString:domainForThisApp]) {
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
                    if ([cookie.domain isEqualToString:domainForThisApp] && [cookie.name isEqualToString:name]) {
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
```

### iOS11以上
管理方式如上段代码所示，在cookie更新之后直接对`[WKWebsiteDataStore defaultDataStore]`进行cookie设置即可。

潜在问题：
Cookie更新缓慢或无法更新。
当存在非视图结构中的WKWebView同时加载网页时，`WKHttpCookieStorage`的异步API回调可能会被阻塞导致cookie无法及时更新或者完全无法更新。
目前观察该问题出现在iOS11.3～iOS12.2的系统。如果遇到相同问题可以首先排查是否有多个webView同时加载。
如果解问题难以发现或者解决成本较高，可以牺牲性能使用`nonPersistentDataStore`来暂时规避这个问题

### iOS10方案
iOS10或以下系统还没有提供`httpCookieStorage`，我们需要使用`WKUserScript`注入JS代码的方式进行cookie更新。

```
//	创建userContentController时添加UserScript
- (WKUserContentController *)userContentController {
    if (!_userContentController) {
        WKUserContentController *userContentController = [WKUserContentController new];
        if (@available(iOS 11.0, *)) {
            [userContentController addUserScript:[WebViewCookieUtil cookieScriptForIOS10AndEarlier]];
        }
        _userContentController = userContentController;
    }
    return _userContentController;
}
```
将`NSHTTPCookieStorage`中的cookie转换成JS设置语句

```
//	WKCookieUtil
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
```

即使已经添加`WKUserScript`，首个请求仍然需要通过设置request的httpHeader来带上cookie信息。

```
- (void)loadURLWithCachePolicy:(NSURLRequestCachePolicy)cachePolicy {
   //	...
    if (@available(iOS 11.0, *)) {
        //	...
    } else {
        NSString *cookieStr = [WebViewCookieUtil cookieStringForFirstRequestIOS10AndEarlier];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.URL cachePolicy:cachePolicy timeoutInterval:10];
        [request addValue:cookieStr forHTTPHeaderField:@"Cookie"];
        [self.wkWebView loadRequest:request];
    }
}
```

```
//	WKCookieUtil
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
```

补充：
如果当前webView使用过程中需要更新cookie，必须删除之前的`WKUserScript`，重新添加新的`WKUserScript`，然后reload整个页面。

### 参考资料
* [iOS 11.3: WKWebView cookie synchronizing stopped working](https://forums.developer.apple.com/thread/99674)
* [iOS UIWebView and WKWebView cookie get, set, delete](http://www.programmersought.com/article/6081753176/)