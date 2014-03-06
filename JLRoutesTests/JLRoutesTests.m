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
	STAssertNotNil(self.lastMatch, @"Matched something");\
	STAssertEquals((NSInteger)[self.lastMatch count] - 3, (NSInteger)expectedCount, @"Expected parameter count")

#define JLValidateParameter(parameter) {\
	NSString *key = [[parameter allKeys] lastObject];\
	NSString *value = [[parameter allValues] lastObject];\
	STAssertEqualObjects(self.lastMatch[key], value, @"Exact parameter pair not found");}

#define JLValidateAnyRouteMatched()\
	STAssertTrue(self.didRoute, @"Expected any route to match")

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
		testsInstance.lastMatch = params;
		return YES;
	};
	
	[JLRoutes setVerboseLoggingEnabled:YES];
	
	// used in testBasicRouting
	[JLRoutes addRoute:@"/test" handler:defaultHandler];
	[JLRoutes addRoute:@"/user/view/:userID" handler:defaultHandler];
	[JLRoutes addRoute:@"/:object/:action/:primaryKey" handler:defaultHandler];
	[JLRoutes addRoute:@"/" handler:defaultHandler];
	[JLRoutes addRoute:@"/:" handler:defaultHandler];
	[JLRoutes addRoute:@"/interleaving/:param1/foo/:param2" handler:defaultHandler];
	[JLRoutes addRoute:@"/wildcard/*" handler:defaultHandler];
	[JLRoutes addRoute:@"/route/:param/*" handler:defaultHandler];
	
	// used in testPriority
	[JLRoutes addRoute:@"/test/priority/:level" handler:defaultHandler];
	[JLRoutes addRoute:@"/test/priority/high" priority:20 handler:defaultHandler];
	
	// used in testBlockReturnValue
	[JLRoutes addRoute:@"/return/:value" handler:^BOOL(NSDictionary *parameters) {
		testsInstance.lastMatch = parameters;
		NSString *value = parameters[@"value"];
		return [value isEqualToString:@"yes"];
	}];
	
	// used in testNamespaces
	[[JLRoutes routesForScheme:@"namespaceTest1"] addRoute:@"/test" handler:defaultHandler];
	[[JLRoutes routesForScheme:@"namespaceTest2"] addRoute:@"/test" handler:defaultHandler];
	[JLRoutes routesForScheme:@"namespaceTest2"].shouldFallbackToGlobalRoutes = YES;
	
	// used in testRouteRemoval
	[[JLRoutes routesForScheme:@"namespaceTest3"] addRoute:@"/test1" handler:defaultHandler];
	[[JLRoutes routesForScheme:@"namespaceTest3"] addRoute:@"/test2" handler:defaultHandler];
	
	NSLog(@"%@", [JLRoutes description]);
	
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
	JLValidateAnyRouteMatched();
	JLValidatePattern(@"/");
	JLValidateParameterCount(0);

	[self route:@"tests://"];
	JLValidateAnyRouteMatched();
	JLValidatePattern(@"/");
	JLValidateParameterCount(0);
	
	[self route:@"tests://test?"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(0);
	JLValidatePattern(@"/test");
	
	[self route:@"tests://test/"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(0);
	JLValidatePattern(@"/test");
	
	[self route:@"tests://test"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(0);
	
	[self route:@"tests://?key=value"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"key": @"value"});
	
	[self route:@"tests://user/view/joeldev"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joeldev"});
	
	[self route:@"tests://user/view/joeldev/"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joeldev"});
	
	[self route:@"tests://user/view/joel%20levin"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joel levin"});
	
	[self route:@"tests://user/view/joeldev?foo=bar&thing=stuff"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"userID": @"joeldev"});
	JLValidateParameter(@{@"foo" : @"bar"});
	JLValidateParameter(@{@"thing" : @"stuff"});

	[self route:@"tests://user/view/joeldev#foo=bar&thing=stuff"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"userID": @"joeldev"});
	JLValidateParameter(@{@"foo" : @"bar"});
	JLValidateParameter(@{@"thing" : @"stuff"});

	[self route:@"tests://user/view/joeldev?userID=evilPerson"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID": @"joeldev"});

	[self route:@"tests://user/view/joeldev?userID=evilPerson&search=evilSearch&evilThing=evil#search=blarg&userID=otherEvilPerson" withParameters:@{@"evilThing": @"notEvil"}];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"userID": @"joeldev"});
	JLValidateParameter(@{@"search": @"blarg"});
	JLValidateParameter(@{@"evilThing": @"notEvil"});
	
	[self route:@"tests://post/edit/123"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(3);
	JLValidateParameter(@{@"object": @"post"});
	JLValidateParameter(@{@"action": @"edit"});
	JLValidateParameter(@{@"primaryKey": @"123"});
	
	[self route:@"tests://interleaving/paramvalue1/foo/paramvalue2"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(2);
	JLValidateParameter(@{@"param1": @"paramvalue1"});
	JLValidateParameter(@{@"param2": @"paramvalue2"});

	[self route:@"tests://wildcard/matches/with/extra/path/components"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(1);
	NSArray *wildcardMatches = @[@"matches", @"with", @"extra", @"path", @"components"];
	JLValidateParameter(@{kJLRouteWildcardComponentsKey: wildcardMatches});

	[self route:@"tests://route/matches/with/wildcard"];
	JLValidateAnyRouteMatched();
	JLValidateParameterCount(2);
	JLValidateParameter(@{@"param": @"matches"});
	NSArray *parameterWildcardMatches = @[@"with", @"wildcard"];
	JLValidateParameter(@{kJLRouteWildcardComponentsKey: parameterWildcardMatches});

	[self route:@"tests://doesnt/exist/and/wont/match"];
	JLValidateNoLastMatch();
}


- (void)testPriority {
	// this should match the /test/priority/high route even though there's one before it that would match if priority wasn't being set
	[self route:@"tests://test/priority/high"];
	JLValidateAnyRouteMatched();
	JLValidatePattern(@"/test/priority/high");
}


- (void)testBlockReturnValue {
	// even though this matches a route, the block returns NO here so there won't be a valid match
	[self route:@"tests://return/no"];
	JLValidateNoLastMatch();
	
	// this one is the same route but will return yes, causing it to be flagged as a match
	[self route:@"tests://return/yes"];
	JLValidateAnyRouteMatched();
}


- (void)testNamespaces {
	// test that the same route can be handled differently for three different scheme namespaces
	[self route:@"tests://test"];
	JLValidateAnyRouteMatched();
	JLValidateScheme(kJLRoutesGlobalNamespaceKey);
	
	[self route:@"namespaceTest1://test"];
	JLValidateAnyRouteMatched();
	JLValidateScheme(@"namespaceTest1");
	
	[self route:@"namespaceTest2://test"];
	JLValidateAnyRouteMatched();
	JLValidateScheme(@"namespaceTest2");
}


- (void)testFallbackToGlobal {
	// first case, fallback is off and so this should fail because this route isnt declared as part of namespaceTest1
	[self route:@"namespaceTest1://user/view/joeldev"];
	JLValidateNoLastMatch();
	
	// fallback is on, so this should route
	[self route:@"namespaceTest2://user/view/joeldev"];
	JLValidateAnyRouteMatched();
	JLValidateScheme(kJLRoutesGlobalNamespaceKey);
	JLValidateParameterCount(1);
	JLValidateParameter(@{@"userID" : @"joeldev"});
}

- (void)testForRouteExistence {
    // This should return yes and no for whether we have a matching route.
    
    NSURL *shouldHaveRouteURL = [NSURL URLWithString:@"tests:/test"];
    NSURL *shouldNotHaveRouteURL = [NSURL URLWithString:@"tests:/dfjkbsdkjfbskjdfb/sdasd"];

    STAssertTrue([JLRoutes canRouteURL:shouldHaveRouteURL], @"Should state it can route known URL");
    STAssertFalse([JLRoutes canRouteURL:shouldNotHaveRouteURL], @"Should not state it can route unknown URL");
}

- (void)testSubscripting {
  JLRoutes.globalRoutes[@"/subscripting"] = ^BOOL(NSDictionary *parameters) {
		testsInstance.lastMatch = parameters;
		return YES;
	};

  NSURL *shouldHaveRouteURL = [NSURL URLWithString:@"subscripting"];

  STAssertTrue([JLRoutes canRouteURL:shouldHaveRouteURL], @"Should state it can route known URL");
}

- (void)testNonSingletonUsage {
    JLRoutes *routes = [JLRoutes new];
    NSURL *trivialURL = [NSURL URLWithString:@"/success"];
    [routes addRoute:[trivialURL absoluteString] handler:nil];
    STAssertTrue([routes routeURL:trivialURL], @"Non-singleton instance should route known URL");
}

- (void)testRouteRemoval {
	[self route:@"namespaceTest3://test1"];
	JLValidateAnyRouteMatched();
	
	[[JLRoutes routesForScheme:@"namespaceTest3"] removeRoute:@"test1"];
	[self route:@"namespaceTest3://test1"];
	JLValidateNoLastMatch();
	
	[self route:@"namespaceTest3://test2"];
	JLValidateAnyRouteMatched();
	
	[JLRoutes unregisterRouteScheme:@"namespaceTest3"];
	[self route:@"namespaceTest3://test2"];
	JLValidateScheme(kJLRoutesGlobalNamespaceKey);
}

#pragma mark -
#pragma mark Convenience Methods

- (void)route:(NSString *)URLString {
	[self route:URLString withParameters:nil];
}


- (void)route:(NSString *)URLString withParameters:(NSDictionary *)parameters {
	NSLog(@"*** Routing %@", URLString);
	self.lastMatch = nil;
	self.didRoute = [JLRoutes routeURL:[NSURL URLWithString:URLString] withParameters:parameters];
}


@end
