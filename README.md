JLRoutes
========

### What is it? ###
JLRoutes is advanced URL parsing with a block-based callback API. It is designed to make it very easy to handle complex URL schemes in your application without having to do any URL or string parsing of any kind.

### Simple Example ###
```objc
[JLRoutes addRoute:@"/user/view/:userID" handler:^BOOL(NSDictionary *parameters) {
  NSString *userID = parameters[@"userID"]; // defined in the route by specifying ":userID"
  // present UI for viewing user with ID 'userID'
  return YES; // return YES to say we have handled the route
}];
```

After having set that route up, at any point something (including a different application) could call this to fire the handler block:
```objc
NSURL *viewUserURL = [NSURL URLWithString:@"myapp://user/view/joeldev"];
[[UIApplication sharedApplication] openURL:viewUserURL];
```

In this example, the userID object in the parameters dictionary passed to the block would have "userID" : "joeldev", which could then be used to present a UI or do whatever else is needed.

### More Complex Example ###

```objc
// would match things like /user/view/joeldev or /post/edit/123
[JLRoutes addRoute:@"/:object/:action/:primaryKey" handler:^BOOL(NSDictionary *parameters) {
  NSString *object = parameters[@"userID"];
  NSString *action = parameters[@"action"];
  NSString *primaryKey = parameters[@"primaryKey"];
  // stuff
  return YES;
}];
```

### Features ###
* Simple API with minimal impact to existing codebases
* Parse any number of parameters interleaved throughout the URL
* Seamlessly parses out GET URL parameters and passes them along as part of the parameters dictionary
* Routes prioritization
* Return NO from a handler block for JLRoutes to look for the next matching route

### Installation ###
JLRoutes is available for installation via CocoaPods. The Releases folder in the repo has binary builds as well, if you'd rather just drop something in.

### Requirements ###
ARC. Only tested on iOS 6, but I don't think there's any reason why it wouldn't work on previous versions.

### License ###
BSD

