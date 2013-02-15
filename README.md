JLRoutes
========

### What is it? ###
JLRoutes is advanced URL parsing with a block-based callback API. It is designed to make it very easy to handle complex URL schemes in your application without having to do any URL or string parsing of any kind.

### Features ###
* Simple API with minimal impact to existing codebases
* Parse any number of parameters interleaved throughout the URL
* Seamlessly parses out GET URL parameters and passes them along as part of the parameters dictionary
* Routes prioritization
* Scheme namespaces to easily segment routes and block handlers for multiple schemes (1.1)
* Return NO from a handler block for JLRoutes to look for the next matching route
* No dependencies other than Foundation

### Simple Example ###
```objc
[JLRoutes addRoute:@"/user/view/:userID" handler:^BOOL(NSDictionary *parameters) {
  NSString *userID = parameters[@"userID"]; // defined in the route by specifying ":userID"
  // present UI for viewing user with ID 'userID'
  return YES; // return YES to say we have handled the route
}];

// in your app delegate:
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
  return [JLRoutes routeURL:url];
}
```

After having set that route up, at any point something (including a different application) could call this to fire the handler block:
```objc
NSURL *viewUserURL = [NSURL URLWithString:@"myapp://user/view/joeldev"];
[[UIApplication sharedApplication] openURL:viewUserURL];
```

In this example, the userID object in the parameters dictionary passed to the block would have the key/value pair `"userID": "joeldev"`, which could then be used to present a UI or do whatever else is needed.

### The Parameters Dictionary ###

The parameters dictionary always contains at least the following two keys:
```json
{
  "JLRouteURL" : "(the NSURL that caused this block to be fired)",
  "JLRoutePattern" : "(the actual route pattern string)"
}
```

These are defined as constants in JLRoutes.h for easy use.

```objc
static NSString *const kJLRoutePatternKey = @"JLRoutePattern";
static NSString *const kJLRouteURLKey = @"JLRouteURL";
```

### Handler Block ###

As you may have noticed, the handler block is expected to return a boolean for if it has handled the route or not. If the block returns `NO`, JLRoutes will behave as if that route is not a match and it will continue looking for a match. A route is considered to be a match if the pattern string matches **and** the block returns `YES`.

It is also important to note that if you pass nil for the handler block, an internal handler block will be created that simply returns `YES`.

### More Complex Example ###

```objc
[JLRoutes addRoute:@"/:object/:action/:primaryKey" handler:^BOOL(NSDictionary *parameters) {
  NSString *object = parameters[@"object"];
  NSString *action = parameters[@"action"];
  NSString *primaryKey = parameters[@"primaryKey"];
  // stuff
  return YES;
}];
```

This route would match things like `/user/view/joeldev` or `/post/edit/123`. Let's say you called `/post/edit/123` with some URL params as well:

```objc
NSURL *editPost = [NSURL URLWithString:@"myapp://post/edit/123?debug=true&foo=bar"];
[[UIApplication sharedApplication] openURL:editPost];
```

The parameters dictionary that the handler block receives would contain the following key/value pairs:
```json
{
  "object": "post",
  "action": "edit",
  "primaryKey": "123",
  "debug": "true",
  "foo": "bar",
  "JLRouteURL" : "myapp://post/edit/123?debug=true&foo=bar",
  "JLRoutePattern" : "/:object/:action/:primaryKey"
}
```

### Scheme Namespaces (available in 1.1) ###

JLRoutes supports setting up routes within the namespace of a given URL scheme. Routes that are set up within the namespace of a single scheme can only be matched by URLs that use that same scheme. By default, all routes go into the global scheme. The current +addRoute methods will use this scheme, and no functionality is different.

However, if you decide that you do need to handle multiple schemes with different sets of functionality, here is an example of how to do that:

```obcj
[JLRoutes addRoute:@"/foo" handler:^BOOL(NSDictionary *parameters) {
  // This block is called if the scheme is not 'thing' or 'stuff' (see below)
  return YES;
}];

[[JLRoutes routesForScheme:@"thing] addRoute:@"/foo" handler:^BOOL(NSDictionary *parameters) {
  // This block is called for thing://foo
  return YES;
}];

[[JLRoutes routesForScheme:@"stuff] addRoute:@"/foo" handler:^BOOL(NSDictionary *parameters) {
  // This block is called for stuff://foo
  return YES;
}];
```

This example shows that you can declare the same routes in different schemes and handle them with different callbacks on a per-scheme basis.

Continuing with this example, if you were to add the following route to the collection above:

```objc
[JLRoutes addRoute:@"/global" handler:^BOOL(NSDictionary *parameters) {
  return YES;
}];
```

and then try to route the URL `thing://global`, it would not match because that route has not been declared within the namespace `thing` but has instead been declared within the global namespace (which we'll assume is how the developer wants it). However, you can easily change this behavior by setting the following property to `YES`:

```objc
[JLRoutes routesForScheme:@"thing].shouldFallbackToGlobalRoutes = YES;
```

This tells JLRoutes that if a URL cannot be routed within the namespace `thing` (aka, it starts with `thing:` but no appropriate route can be found in the namespace), try to recover by looking for a matching route in the global routes namespace as well. After setting that property to `YES`, the URL 'thing://global` would be routed to the /global block.

### Apps using JLRoutes ###
*None that I know of so far! Feel free to create an issue asking me to add your app.*

### Installation ###
JLRoutes is available for installation via CocoaPods. The Releases folder in the repo has binary builds as well, if you'd rather just drop something in.

### Requirements ###
Requires ARC. Only tested on iOS 6, but I don't think there's any reason why it wouldn't work on previous iOS versions. It should also work seamlessly on OS X.

### License ###
BSD

