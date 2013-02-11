//
//  JLRoutesTests.m
//  JLRoutesTests
//
//  Created by Joel Levin on 2/9/13.
//  Copyright (c) 2013 Afterwork Studios. All rights reserved.
//

#import "JLRoutesTests.h"
#import "JLRoutes.h"


static JLRoutesTests *testsInstance = nil;


@interface JLRoutesTests ()

@property (assign) BOOL didRoute;
@property (strong) NSDictionary *lastMatch;

- (void)route:(NSString *)URLString;
- (void)validateParameterCount:(NSUInteger)count;
- (void)validateParameter:(NSDictionary *)parameter;
- (void)validateNoLastMatch;
- (void)validatePattern:(NSString *)pattern;

@end


@implementation JLRoutesTests

+ (void)setUp {
	id defaultHandler = ^BOOL (NSDictionary *params) {
		NSLog(@"%@", params);
		testsInstance.lastMatch = params;
		return YES;
	};
	
	// used in testBasicRouting
	[JLRoutes addRoute:@"/test" handler:defaultHandler];
	[JLRoutes addRoute:@"/user/view/:userID" handler:defaultHandler];
	[JLRoutes addRoute:@"/:object/:action/:primaryKey" handler:defaultHandler];
	[JLRoutes addRoute:@"/" handler:defaultHandler];
	[JLRoutes addRoute:@"/:" handler:defaultHandler];
	[JLRoutes addRoute:@"/interleaving/:param1/foo/:param2" handler:defaultHandler];
	
	// used in testPriority
	[JLRoutes addRoute:@"/test/priority/:level" handler:defaultHandler];
	[JLRoutes addRoute:@"/test/priority/high" priority:20 handler:defaultHandler];
	
	// used in testBlockReturnValue
	[JLRoutes addRoute:@"/return/:value" handler:^BOOL(NSDictionary *parameters) {
		NSLog(@"%@", parameters);
		testsInstance.lastMatch = parameters;
		NSString *value = parameters[kJLRouteParametersKey][@"value"];
		return [value isEqualToString:@"yes"];
	}];
	
    [super setUp];
}


- (void)setUp {
	testsInstance = self;
	[super setUp];
}


- (void)testBasicRouting {
	[self route:@"tests:/"];
	[self validateNoLastMatch];
	
	[self route:@"tests://"];
	[self validateParameterCount:0];
	
	[self route:nil];
	[self validateNoLastMatch];
	
	[self route:@"tests://test?"];
	[self validateParameterCount:0];
	[self validatePattern:@"/test"];
	
	[self route:@"tests://?key=value"];
	[self validateParameterCount:1];
	[self validateParameter:@{@"key": @"value"}];
	
	[self route:@"tests://test"];
	[self validateParameterCount:0];
	
	[self route:@"tests://user/view/joeldev"];
	[self validateParameterCount:1];
	[self validateParameter:@{@"userID": @"joeldev"}];
	
	[self route:@"tests://user/view/joeldev?foo=bar&thing=stuff"];
	[self validateParameterCount:3];
	[self validateParameter:@{@"userID": @"joeldev"}];
	[self validateParameter:@{@"foo" : @"bar"}];
	[self validateParameter:@{@"thing" : @"stuff"}];
	
	[self route:@"tests://post/edit/123"];
	[self validateParameterCount:3];
	[self validateParameter:@{@"object": @"post"}];
	[self validateParameter:@{@"action": @"edit"}];
	[self validateParameter:@{@"primaryKey": @"123"}];
	
	[self route:@"tests://interleaving/paramvalue1/foo/paramvalue2"];
	[self validateParameterCount:2];
	[self validateParameter:@{@"param1": @"paramvalue1"}];
	[self validateParameter:@{@"param2": @"paramvalue2"}];
	
	[self route:@"tests://doesnt/exist/and/wont/match"];
	[self validateNoLastMatch];
}


- (void)testPriority {
	// this should match the /test/priority/high route even though there's one before it that would match if priority wasn't being set
	[self route:@"tests://test/priority/high"];
	[self validateParameterCount:0];
	[self validatePattern:@"/test/priority/high"];
}


- (void)testBlockReturnValue {
	// even though this matches a route, the block returns NO here so there won't be a valid match
	[self route:@"tests://return/no"];
	[self validateNoLastMatch];
	
	// this one is the same route but will return yes, causing it to be flagged as a match
	[self route:@"tests://return/yes"];
	[self validateParameterCount:1]; // the value is parameterized, so 'yes' should be the only param
}


#pragma mark -
#pragma mark Convenience Methods

- (void)route:(NSString *)URLString {
	NSLog(@"*** Routing %@", URLString);
	self.lastMatch = nil;
	self.didRoute = [JLRoutes routeURL:[NSURL URLWithString:URLString]];
}


- (void)validateParameterCount:(NSUInteger)count {
	STAssertTrue(self.didRoute, @"didRoute should be YES");
	STAssertNotNil(self.lastMatch, @"Last match was nil");
	STAssertTrue([self.lastMatch[kJLRouteParametersKey] count] == count, @"Incorrect parameter count: %@", self.lastMatch);
}


- (void)validateParameter:(NSDictionary *)parameter {
	NSString *key = [[parameter allKeys] lastObject];
	NSString *value = [[parameter allValues] lastObject];
	NSDictionary *parsedParameters = self.lastMatch[kJLRouteParametersKey];
	STAssertTrue([parsedParameters[key] isEqualToString:value], @"Exact parameter pair not found: %@ in %@", parameter, self.lastMatch);
}


- (void)validateNoLastMatch {
	STAssertFalse(self.didRoute, @"Expected not to route successfully");
}


- (void)validatePattern:(NSString *)pattern {
	STAssertTrue([self.lastMatch[kJLRoutePatternKey] isEqualToString:pattern], @"Pattern did not match, was expecting: %@", pattern);
}


@end
