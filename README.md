JLRoutes
========

### What is it? ###
JLRoutes is advanced URL parsing with a block-based callback API. It is designed to make it very easy to handle complex URL schemes in your application without having to do any URL or string parsing of any kind.

### Example Usage ###
```objc
[JLRoutes addRoute:@"/user/view/:userID" handler:^BOOL(NSDictionary *parameters) {
  NSString *userID = parameters[@"userID"]; // defined in the route by specifying ":userID"
  // code to present UI for viewing user with ID 'userID'
}];
```

After having set that route up, at any point something (including a different application) could call this to fire the handler block:
```objc
NSURL *viewUserURL = [NSURL URLWithString:@"myapp://user/view/joeldev"];
[[UIApplication sharedApplication] openURL:viewUserURL];
```

In this example, the userID object in the parameters dictionary passed to the block would have "userID" : "joeldev", which could then be used to present a UI or do whatever else is needed.

### Features ###
* Block-based API with minimal impact to existing codebases
* Able to parse any number of parameters interleaved into the URL
* Seamlessly parses out GET URL parameters and passes them along as part of the parameters dictionary
* Route prioritization
* Return NO from a handler block for JLRoutes to look for the next matching route

### Requirements ###
ARC. Only tested on iOS 6, but I don't think there's any reason why it wouldn't work on previous versions.

### License ###
BSD

