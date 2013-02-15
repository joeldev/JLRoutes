//
//  JLRoutesTests.m
//  JLRoutesTests
//
//  Created by Joel Levin on 2/9/13.
//  Copyright (c) 2013 Afterwork Studios. All rights reserved.
//

#import "JLRoutesTests.h"
#import "JLRoutes.h"


#define JLValidateParameterCount(expectedCount)\
	STAssertTrue(self.didRoute, @"Route matched");\
	STAssertNotNil(self.lastMatch, @"Matched something");\
	STAssertEquals((NSInteger)[self.lastMatch count] - 3, (NSInteger)expectedCount, @"Expected parameter count")

#define JLValidateParameter(parameter) {\
	NSString *key = [[parameter allKeys] lastObject];\
	NSString *value = [[parameter allValues] lastObject];\
	STAssertEqualObjects(self.lastMatch[key], value, @"Exact parameter pair not found");}

#define JLValidateNoLastMatch()\
	STAssertFalse(self.didRoute, @"Expected not to route successfully")

#define JLValidatePattern(pattern)\
	STAssertEqualObjects(self.lastMatch[kJLRoutePatternKey], pattern, @"Pattern did not match")

#define JLValidateScheme(scheme)\
	STAssertEqualObjects(self.lastMatch[kJLRouteNamespaceKey], scheme, @"Scheme did not match")


static JLRoutesTests *testsInstance = nil;


@interface JLRoutesTests ()

@property (assign) BOOL didRoute;
@property (strong) NSDictionary *lastMatch;

- (void)route:(NSString *)URLString;

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
		NSString *value = parameters[@"value"];
		return [value isEqualToString:@"yes"];
	}];
	
	// used in testNamespaces
	[[JLRoutes routesForScheme:@"namespaceTest1"] addRoute:@"/test" handler:defaultHandler];
	[[JLRoutes routesForScheme:@"namespaceTest2"] addRoute:@"/test" handler:defaultHandler];
	[JLRoutes routesForScheme:@"namespaceTest2"].shouldFallbackToGlobalRoutes = YES;
	
	[super setUp];
}


- (void)setUp {
	testsInstance = self;
	[super setUp];
}


- (void)testBasicRouting {
	[self route:nil];
	JLValidateNoLastMatch();
	
	[self route:@"tests:/"];
	JLValidatePattern(@"/");
	JLValidateParameterCount(0);

	[self route:@"tests://"];
	JLValidatePattern(@"/");
	JLValidateParameterCount(0);

	[self route:@"tests:/"];
	JLValidatePattern(@"/");
	JLValidateParameterCount(0);
	
	[self route:@"tests://test?"];
	JLValidateParameterCount(0);
	JLValidatePattern(@"/test");
	
	[self route:@"tests://test/"];
	JLValidateParameterCount(0);
	JLValidatePattern(@"/test");
	
	[self route:@"tests://test"];
	JLValidateParameterCount(0);
	
	[self route:@"tests://?key=value"];
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"key": @"value"});
	
	[self route:@"tests://user/view/joeldev"];
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joeldev"});
	
	[self route:@"tests://user/view/joeldev/"];
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joeldev"});
	
	[self route:@"tests://user/view/joel%20levin"];
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joel levin"});
	
	[self route:@"tests://user/view/joeldev?foo=bar&thing=stuff"];
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"userID": @"joeldev"});
	JLValidateParameter(@{@"foo" : @"bar"});
	JLValidateParameter(@{@"thing" : @"stuff"});
	
	[self route:@"tests://post/edit/123"];
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"object": @"post"});
	JLValidateParameter(@{@"action": @"edit"});
	JLValidateParameter(@{@"primaryKey": @"123"});
	
	[self route:@"tests://interleaving/paramvalue1/foo/paramvalue2"];
	JLValidateParameterCount(2);
	JLValidateParameter(@{@"param1": @"paramvalue1"});
	JLValidateParameter(@{@"param2": @"paramvalue2"});
	
	[self route:@"tests://doesnt/exist/and/wont/match"];
	JLValidateNoLastMatch();
}


- (void)testPriority {
	// this should match the /test/priority/high route even though there's one before it that would match if priority wasn't being set
	[self route:@"tests://test/priority/high"];
	JLValidateParameterCount(0);
	JLValidatePattern(@"/test/priority/high");
}


- (void)testBlockReturnValue {
	// even though this matches a route, the block returns NO here so there won't be a valid match
	[self route:@"tests://return/no"];
	JLValidateNoLastMatch();
	
	// this one is the same route but will return yes, causing it to be flagged as a match
	[self route:@"tests://return/yes"];
	JLValidateParameterCount(1); // the value is parameterized, so 'yes' should be the only param
}


- (void)testNamespaces {
	// test that the same route can be handled differently for three different scheme namespaces
	[self route:@"tests://test"];
	JLValidateParameterCount(0);
	JLValidateScheme(kJLRoutesGlobalNamespaceKey);
	
	[self route:@"namespaceTest1://test"];
	JLValidateParameterCount(0);
	JLValidateScheme(@"namespaceTest1");
	
	[self route:@"namespaceTest2://test"];
	JLValidateParameterCount(0);
	JLValidateScheme(@"namespaceTest2");
}


- (void)testFallbackToGlobal {
	// first case, fallback is off and so this should fail because this route isnt declared as part of namespaceTest1
	[self route:@"namespaceTest1://user/view/joeldev"];
	JLValidateNoLastMatch();
	
	// fallback is on, so this should route
	[self route:@"namespaceTest2://user/view/joeldev"];
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID" : @"joeldev"});
}


#pragma mark -
#pragma mark Convenience Methods

- (void)route:(NSString *)URLString {
	NSLog(@"*** Routing %@", URLString);
	self.lastMatch = nil;
	self.didRoute = [JLRoutes routeURL:[NSURL URLWithString:URLString]];
}


@end
