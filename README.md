# WKWebViewCookieDemo

当前项目使用cookie来维护用户登录状态、App版本系统、语言等状态信息。

在UIWebView时代，可以通过`NSHTTPCookieStorage`单例很直接的管理客户端cookie。UIWebView的cookie数据会自动和`NSHTTPCookieStorage`进行同步。而WKWebView的cookie维护一直为人诟病。只要你维护过相关业务，不同iOS版本上出现的各种cookie的问题一定让你头疼过。

这个Demo提供踩坑折腾几个月之后的解决方案，虽然不是很完整，但是基本满足当前项目需求。核心类[WebViewCookieUtil](https://github.com/weipinglii/WKWebViewCookieDemo/blob/master/WKWebViewCookieDemo/WebViewCookieUtil.h)。

## iOS11及以上
通过`WKHTTPCookieStore`和`WKProcessPool`对cookie进行管理和同步，

当cookie更新时使用`WKWebsiteDataStore`的`setCookie:completionHandler:`和`deleteCookie:completionHandler:`进行cookie更新即可。
详见`WebViewCookieUtil`的`
+clientCookieDidUpdate:toRemove:`方法

补充：
如果多个使用`defaultDataStore`的webView实例指定的`WKProcessPool`不同，cookie可能会无法更新到所有的webView中，建议全局使用同一个`WKProcessPool`实例。

## iOS10方案
1. 通过`WKUserScript`和`WKUserContentController`注入JS代码的方式进行cookie更新。
2. 首个请求的cookie需要通过NSMutableRequest设置。
3. 更新cookie需要做到如下两个步骤：
	1. 通过`WKWebsiteDataStore`获取到类型为`WKWebsiteDataTypeCookies`的`WKWebsiteDataRecord`, 整体删除。
	2. 从`WKUserContentController`中替换`WKUserScript`然后reload整个页面。

补充:
该方案不需要设置`WKProcessPool`, 如果和高版本iOS一样设置`WKProcessPool`单例，会导致仅删除类型为`WKWebsiteDataTypeCookies`的`WKWebsiteDataRecord`无法删除cookie。

### WKHttpCookieStorage API阻塞问题
当存在非视图结构中的WKWebView加载网页时，`WKHttpCookieStorage`的异步API回调block可能不会被调用或者回调非常慢。目前观察该问题出现在iOS11.3～iOS12.2的系统。如果遇到相同问题可以首先排查是否有多个webView同时加载。
解决成本高的话，可以将该webView的dataStore设置成`nonPersistentDataStore`来暂时规避该问题。

### 参考资料
* [iOS 11.3: WKWebView cookie synchronizing stopped working](https://forums.developer.apple.com/thread/99674)
* [iOS UIWebView and WKWebView cookie get, set, delete](http://www.programmersought.com/article/6081753176/)