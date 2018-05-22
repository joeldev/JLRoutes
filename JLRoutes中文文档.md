JLRoutes
========

[![Platforms](https://img.shields.io/cocoapods/p/JLRoutes.svg?style=flat)](http://cocoapods.org/pods/JLRoutes)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/JLRoutes.svg)](http://cocoapods.org/pods/JLRoutes)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.org/joeldev/JLRoutes.svg?branch=master)](https://travis-ci.org/joeldev/JLRoutes)
[![Apps](https://img.shields.io/cocoapods/at/JLRoutes.svg?maxAge=2592000)](https://cocoapods.org/pods/JLRoutes)

### 它是什么? ###
JLRoutes是通过一个简单的block生成的URL路由库。它旨在使您能够轻松处理应用程序中的复杂URL schemes，并使用最少的代码。

### 安装 ###
安装并使用[CocoaPods](https://cocoapods.org/pods/JLRoutes)或Carthage (添加 `github "joeldev/JLRoutes"` 到你的 `Cartfile`)来获得JLRoutes。

### 要求 ###
JLRoutes 2.x 要求 iOS 8.0+ 或 macOS 10.10+。如果你需要支持 iOS 7 或 macOS 10.9, 请使用 1.6.4 版本 (这是最新的1.x版本)。

### 文档 ###
在[这里](http://cocoadocs.org/docsets/JLRoutes/)获取文档。

### 开始使用 ###

[在 Info.plist 中配置你的 URL schemes。](https://developer.apple.com/library/ios/documentation/iPhone/Conceptual/iPhoneOSProgrammingGuide/Inter-AppCommunication/Inter-AppCommunication.html#//apple_ref/doc/uid/TP40007072-CH6-SW2)

```objc
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  JLRoutes *routes = [JLRoutes globalRoutes];

  [routes addRoute:@"/user/view/:userID" handler:^BOOL(NSDictionary *parameters) {
    NSString *userID = parameters[@"userID"]; // 在路由中通过指定“: userID”

    // 查看ID为'userID'的用户的UI

    return YES; // 返回YES表示我们已经处理了该路线
  }];

  return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *, id> *)options
{
  return [JLRoutes routeURL:url];
}
```

也可以使用点语法注册路由：
```objc
JLRoutes.globalRoutes[@"/user/view/:userID"] = ^BOOL(NSDictionary *parameters) {
  // ...
};
```

路由中添加`/user/view/:userID`之后，调用下列的代码会执行block块，block块中会返回一个包含`@"userID": @"joeldev"`的字典：
```objc
NSURL *viewUserURL = [NSURL URLWithString:@"myapp://user/view/joeldev"];
[JLRoutes routeURL:viewUserURL];
```

### 参数字典 ###

参数字典至少包含以下三个键：
```json
{
  "JLRouteURL":  "(路由对应的NSURL对象)",
  "JLRoutePattern": "(路由对应的Pattern字符串)",
  "JLRouteScheme": "(路由的scheme, 默认为 JLRoutesGlobalRoutesScheme)"
}
```

### Block 处理者 ###

block处理者预计会返回一个布尔值，以表示它是否处理了路由。
如果block块中返回NO，JLRoutes认为该路线不匹配，并且它将继续寻找匹配。
如果pattern字符串匹配且block返回YES，则认为路由匹配。

### 全局配置 ###

有多个全局配置选项可用于帮助自定义特定用例的JLRoutes行为。所有选项仅影响下一个操作。

```objc
/// 配置详细日志记录。默认为NO。
+ (void)setVerboseLoggingEnabled:(BOOL)loggingEnabled;

/// 配置是否应将'+'替换为解析值中的空格。默认为YES。
+ (void)setShouldDecodePlusSymbols:(BOOL)shouldDecode;

/// 配置URL host是否始终被视为path component。 默认为NO。
+ (void)setAlwaysTreatsHostAsPathComponent:(BOOL)treatsHostAsPathComponent;

/// 配置创建路由定义时使用的默认类。 默认为JLRRouteDefinition。
+ (void)setDefaultRouteDefinitionClass:(Class)routeDefinitionClass;
```

在`JLRoutes`类中这些都已配置：
```objc
[JLRoutes setAlwaysTreatsHostAsPathComponent:YES];
```

### 更复杂的例子 ###

```objc
[[JLRoutes globalRoutes] addRoute:@"/:object/:action/:primaryKey" handler:^BOOL(NSDictionary *parameters) {
  NSString *object = parameters[@"object"];
  NSString *action = parameters[@"action"];
  NSString *primaryKey = parameters[@"primaryKey"];
  // stuff
  return YES;
}];
```

这个路由可以匹配`/user/view/joeldev`或`/post/edit/123`之类的东西。假设你用一些URL参数调用`/post/edit/123`：

```objc
NSURL *editPost = [NSURL URLWithString:@"myapp://post/edit/123?debug=true&foo=bar"];
[JLRoutes routeURL:editPost];
```

block处理者会接收到包含以下键/值对的字典参数：
```json
{
  "object": "post",
  "action": "edit",
  "primaryKey": "123",
  "debug": "true",
  "foo": "bar",
  "JLRouteURL": "myapp://post/edit/123?debug=true&foo=bar",
  "JLRoutePattern": "/:object/:action/:primaryKey",
  "JLRouteScheme": "JLRoutesGlobalRoutesScheme"
}
```

### Schemes ###

JLRoutes支持在特定的URL scheme中设置路由。在scheme中设置的Routers只能通过这个scheme内的URLs进行匹配。
默认情况，所有路由都为全局scheme。

```objc
[[JLRoutes globalRoutes] addRoute:@"/foo" handler:^BOOL(NSDictionary *parameters) {
  // 如果scheme是没有`东西`或`操作`这个block会被调用。默认scheme为JLRoutesGlobalRoutesScheme
  return YES;
}];

[[JLRoutes routesForScheme:@"thing"] addRoute:@"/foo" handler:^BOOL(NSDictionary *parameters) {
  // 通过thing://foo来调用这个blcok
  return YES;
}];

[[JLRoutes routesForScheme:@"stuff"] addRoute:@"/foo" handler:^BOOL(NSDictionary *parameters) {
  // 通过stuff://foo来调用这个blcok
  return YES;
}];
```

这个例子表明你可以在不同的scheme中声明相同的路由，并在每个scheme的基础上用不同的回调来处理它们。

如果你要添加下面的路由：
```objc
[[JLRoutes globalRoutes] addRoute:@"/global" handler:^BOOL(NSDictionary *parameters) {
  return YES;
}];
```

然后尝试通过URL`thing://global`进行匹配，它不会被匹配。因为该路由尚未在`thing`scheme中声明，而是在全局shceme内声明（我们假设开发人员需要它）您可以通过设置以下属性为`YES`：
```objc
[JLRoutes routesForScheme:@"thing"].shouldFallbackToGlobalRoutes = YES;
```

这告诉JLRoutes，如果URL不能在`thing`shceme中匹配（也就是说，它开始于`thing：`但没有找到适当的路由），尝试通过在global routes scheme中寻找匹配路线来恢复。
将该属性设置为YES后，这个`thing://global`URL将被匹配到`/global`block。

### 通配符 ###

例如，对于任何以`/wildcard/`开头的URL，将触发以下路由，但如果下一个组件不是`joker`，则会被处理者拒绝。

```objc
[[JLRoutes globalRoutes] addRoute:@"/wildcard/*" handler:^BOOL(NSDictionary *parameters) {
  NSArray *pathComponents = parameters[JLRouteWildcardComponentsKey];
  if (pathComponents.count > 0 && [pathComponents[0] isEqualToString:@"joker"]) {
    // 被匹配到; 做一些操作
    return YES;
  }

  // 没有兴趣，除非'joker'在里面
  return NO;
}];
```

### 可选路由 ###

JLRoutes支持使用可选参数设置路由。
在路由注册时刻，通过可选参数，JLRoute将注册多个路由。

例如，对于`/the(/foo/:a)(/bar/:b)`route，它将注册以下routes：

- `/the/foo/:a/bar/:b`
- `/the/foo/:a`
- `/the/bar/:b`
- `/the`

### 查询路由 ###

```objc
/// 被注册的所有路由, key 为 scheme
+ (NSDictionary <NSString *, NSArray <JLRRouteDefinition *> *> *)allRoutes;

/// 返回指定的 scheme 中的所有路由
- (NSArray <JLRRouteDefinition *> *)routes;
```

### Block 处理者 ###

`JLRRouteHandler`是一个类，可以创建block处理者，传递给 addRoute: call。
这对于，如果您想让一个单独的类或对象成为处理者情况下特别有用。

你的目标类需要遵守`JLRRouteHandlerTarget`协议，如下：

```objc
@interface MyTargetViewController : UIViewController <JLRRouteHandlerTarget>

@property (nonatomic, copy) NSDictionary <NSString *, id> *parameters;

@end


@implementation MyTargetViewController

- (instancetype)initWithRouteParameters:(NSDictionary <NSString *, id> *)parameters
{
  self = [super init];

  _parameters = [parameters copy]; // 持有之后再做一些事情

  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  // 用self.parameters做一些有趣的事情，初始化视图等等...
}

@end
```

要通过`JLR RouteHandler`连接起来，你可以这样做：

```objc
id handlerBlock = [JLRRouteHandler handlerBlockForTargetClass:[MyTargetViewController class] completion:^BOOL (MyTargetViewController *viewController) {
  // Push the created view controller onto the nav controller
  [self.navigationController pushViewController:viewController animated:YES];
  return YES;
}];

[[JLRoutes globalRoutes] addRoute:@"/some/route" handler:handlerBlock];
```

`JLRRouteHandler`还有一个便捷方法，用于轻松路由到对象的现有实例，并创建新实例。 例如：

```objc
MyTargetViewController *rootController = ...; // some object that exists and conforms to JLRRouteHandlerTarget.
id handlerBlock = [JLRRouteHandler handlerBlockForWeakTarget:rootController];

[[JLRoutes globalRoutes] addRoute:@"/some/route" handler:handlerBlock];
```

当路线匹配时，它将调用目标对象上的一个方法：

```objc
- (BOOL)handleRouteWithParameters:(NSDictionary<NSString *, id> *)parameters;
```

### 解析自定义路由 ###

可以通过继承`JLRRouteDefinition`并使用`addRoute：`方法来添加自定义子类的实例，从而控制路由的解析方式。

```objc
// 自定义路由
@interface AlwaysMatchRouteDefinition : JLRRouteDefinition
@end


@implementation AlwaysMatchRouteDefinition

- (JLRRouteResponse *)routeResponseForRequest:(JLRRouteRequest *)request
{
  // 当JLRoutes试图确定我们是否匹配给定的请求对象时，会调用此方法。

  // 创建参数字典
  NSDictionary *variables = [self routeVariablesForRequest:request];
  NSDictionary *matchParams = [self matchParametersForRequest:request routeVariables:variables];

  // 返回有效的匹配!
  return [JLRRouteResponse validMatchResponseWithParameters:matchParams];
}

@end
```

现在可以创建并添加这个路由：

```objc
id handlerBlock = ... // assume exists
AlwaysMatchRouteDefinition *alwaysMatch = [[AlwaysMatchRouteDefinition alloc] initWithPattern:@"/foo" priority:0 handlerBlock:handlerBlock];
[[JLRoutes globalRoutes] addRoute:alwaysMatch];
```

如果你编写了自定义路由并希望JLRoutes在添加路由时始终使用它，可以使用如下方法进行设置：

```objc
[JLRoutes setDefaultRouteDefinitionClass:[MyCustomRouteDefinition class]];
```

---

这篇中文文档，多少会与原文档有些差入。欢迎大家可以一起维护。
