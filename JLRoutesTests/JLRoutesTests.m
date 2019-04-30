/*
 Copyright (c) 2017, Joel Levin
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of JLRoutes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import "JLRoutes.h"
#import "JLRRouteDefinition.h"
#import "JLRRouteHandler.h"


#define JLValidateParameterCount(expectedCount)\
XCTAssertNotNil(self.lastMatch, @"Matched something");\
XCTAssertEqual((NSInteger)[self.lastMatch count] - 3, (NSInteger)expectedCount, @"Expected parameter count")

#define JLValidateParameterCountIncludingWildcard(expectedCount)\
XCTAssertNotNil(self.lastMatch, @"Matched something");\
XCTAssertEqual((NSInteger)[self.lastMatch count] - 4, (NSInteger)expectedCount, @"Expected parameter count")

#define JLValidateParameter(parameter) {\
NSString *key = [[parameter allKeys] lastObject];\
NSString *value = [[parameter allValues] lastObject];\
XCTAssertEqualObjects(self.lastMatch[key], value, @"Exact parameter pair not found");}

#define JLValidateAnyRouteMatched()\
XCTAssertTrue(self.didRoute, @"Expected any route to match")

#define JLValidateNoLastMatch()\
XCTAssertFalse(self.didRoute, @"Expected not to route successfully")

#define JLValidatePattern(pattern)\
XCTAssertEqualObjects(self.lastMatch[JLRoutePatternKey], pattern, @"Pattern did not match")

#define JLValidateScheme(scheme)\
XCTAssertEqualObjects(self.lastMatch[JLRouteSchemeKey], scheme, @"Scheme did not match")


#pragma mark -


@interface JLRMockTargetObject : NSObject <JLRRouteHandlerTarget>

@property (nonatomic, copy) NSDictionary *routeParams;

@end


@interface JLRMockRouteDefinition : JLRRouteDefinition
@end


@interface JLRoutesTests : XCTestCase

@property (assign) BOOL didRoute;
@property (strong) NSDictionary *lastMatch;

+ (BOOL (^)(NSDictionary *))defaultRouteHandler;

- (void)route:(NSString *)URLString;

@end


static JLRoutesTests *testsInstance = nil;


@implementation JLRoutesTests

+ (void)setUp
{
    [super setUp];
    [JLRoutes setVerboseLoggingEnabled:YES];
}

- (void)setUp
{
    [super setUp];
    
    testsInstance = self;
    
    // reset settings
    [JLRoutes setShouldDecodePlusSymbols:YES];
    [JLRoutes setAlwaysTreatsHostAsPathComponent:NO];
    [JLRoutes setDefaultRouteDefinitionClass:[JLRRouteDefinition class]];
}

- (void)tearDown
{
    [super tearDown];
    [JLRoutes unregisterAllRouteSchemes];
}

#pragma mark - Tests

- (void)testRoutesArray
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/global1" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/global2" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/global3" handler:defaultHandler];
    
    NSArray <JLRRouteDefinition *> *globalRoutes = [[JLRoutes globalRoutes] routes];
    
    XCTAssertEqual(globalRoutes.count, 3UL);
    XCTAssertEqualObjects(globalRoutes[0].pattern, @"/global1");
    XCTAssertEqualObjects(globalRoutes[1].pattern, @"/global2");
    XCTAssertEqualObjects(globalRoutes[2].pattern, @"/global3");
    
    [[JLRoutes routesForScheme:@"scheme"] addRoute:@"/scheme1" handler:defaultHandler];
    [[JLRoutes routesForScheme:@"scheme"] addRoute:@"/scheme2" handler:defaultHandler];
    
    NSArray <JLRRouteDefinition *> *schemeRoutes = [[JLRoutes routesForScheme:@"scheme"] routes];
    
    XCTAssertEqual(schemeRoutes.count, 2UL);
    XCTAssertEqualObjects(schemeRoutes[0].pattern, @"/scheme1");
    XCTAssertEqualObjects(schemeRoutes[1].pattern, @"/scheme2");
    
    NSArray <JLRRouteDefinition *> *nonexistant = [[JLRoutes routesForScheme:@"foo"] routes];
    XCTAssertEqual(nonexistant.count, 0UL);
}

- (void)testAllRoutes
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/global1" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/global2" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/global3" handler:defaultHandler];
    [[JLRoutes routesForScheme:@"scheme"] addRoute:@"/scheme1" handler:defaultHandler];
    [[JLRoutes routesForScheme:@"scheme"] addRoute:@"/scheme2" handler:defaultHandler];
    
    NSDictionary <NSString *, NSArray <JLRRouteDefinition *> *> *allRoutes = [JLRoutes allRoutes];
    
    NSArray <JLRRouteDefinition *> *globalRoutes = allRoutes[JLRoutesGlobalRoutesScheme];
    XCTAssertEqual(globalRoutes.count, 3UL);
    XCTAssertEqualObjects(globalRoutes[0].pattern, @"/global1");
    XCTAssertEqualObjects(globalRoutes[1].pattern, @"/global2");
    XCTAssertEqualObjects(globalRoutes[2].pattern, @"/global3");
    
    NSArray <JLRRouteDefinition *> *schemeRoutes = allRoutes[@"scheme"];
    XCTAssertEqual(schemeRoutes.count, 2UL);
    XCTAssertEqualObjects(schemeRoutes[0].pattern, @"/scheme1");
    XCTAssertEqualObjects(schemeRoutes[1].pattern, @"/scheme2");
}

- (void)testRouting
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/test" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/test/slash/" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/user/view/:userID" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/:object/:action/:primaryKey" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/:" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/interleaving/:param1/foo/:param2" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/xyz/wildcard/*" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/route/:param/*" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/required/:requiredParam(/optional/:optionalParam)(/moreOptional/:moreOptionalParam)" handler:defaultHandler];
    
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

    [self route:@"tests://test/slash/"];
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
    
    [self route:@"tests://xyz/wildcard"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCountIncludingWildcard(0);
    
    [self route:@"tests://xyz/wildcard/matches/with/extra/path/components"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    NSArray *wildcardMatches = @[@"matches", @"with", @"extra", @"path", @"components"];
    JLValidateParameter(@{JLRouteWildcardComponentsKey: wildcardMatches});
    
    [self route:@"tests://route/matches/with/wildcard"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(2);
    JLValidateParameter(@{@"param": @"matches"});
    NSArray *parameterWildcardMatches = @[@"with", @"wildcard"];
    JLValidateParameter(@{JLRouteWildcardComponentsKey: parameterWildcardMatches});
    
    [self route:@"tests://doesnt/exist/and/wont/match"];
    JLValidateNoLastMatch();
    
    [self routeURL:[NSURL URLWithString:@"/test" relativeToURL:[NSURL URLWithString:@"http://localhost"]] withParameters:nil];
    JLValidateAnyRouteMatched();
    JLValidatePattern(@"/test");
    JLValidateParameterCount(0);
    
    [self route:@"tests://required/mustExist"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"requiredParam": @"mustExist"});
    
    [self route:@"tests://required/mustExist/optional/mightExist"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(2);
    JLValidateParameter(@{@"requiredParam": @"mustExist"});
    JLValidateParameter(@{@"optionalParam": @"mightExist"});
    
    [self route:@"tests://required/mustExist/optional/mightExist/moreOptional/mightExistToo"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(3);
    JLValidateParameter(@{@"requiredParam": @"mustExist"});
    JLValidateParameter(@{@"optionalParam": @"mightExist"});
    JLValidateParameter(@{@"moreOptionalParam": @"mightExistToo"});
}

- (void)testRoutingWithParameters
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/foo/:routeParam" handler:defaultHandler];
    
    [self route:@"/foo/bar" withParameters:@{@"stringParam": @"stringValue", @"nonStringParam": @(123)}];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(3);
    JLValidateParameter(@{@"routeParam": @"bar"});
    JLValidateParameter(@{@"stringParam": @"stringValue"});
    JLValidateParameter(@{@"nonStringParam": @(123)});
}

- (void)testFragmentRouting
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/user#/view/:userID" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/:object#/:action/:primaryKey" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/interleaving/:param1#/foo/:param2" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/xyz/wildcard#/*" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/route#/:param/*" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/required#/:requiredParam(/optional/:optionalParam)(/moreOptional/:moreOptionalParam)" handler:defaultHandler];
    
    [self route:nil];
    JLValidateNoLastMatch();
    
    [self route:@"tests://user#/view/joeldev"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joeldev"});
    
    [self route:@"tests://user#/view/joeldev/"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joeldev"});
    
    [self route:@"tests://user#/view/joel%20levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel levin"});
    
    [self route:@"tests://user#/view/joeldev?foo=bar&thing=stuff"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(3);
    JLValidateParameter(@{@"userID": @"joeldev"});
    JLValidateParameter(@{@"foo" : @"bar"});
    JLValidateParameter(@{@"thing" : @"stuff"});
    
    [self route:@"tests://user#/view/joeldev?userID=evilPerson"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joeldev"});
    
    [self route:@"tests://user#/view/joeldev?userID=evilPerson&search=evilSearch&evilThing=evil"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(3);
    JLValidateParameter(@{@"userID": @"joeldev"});
    JLValidateParameter(@{@"search": @"evilSearch"});
    
    [self route:@"tests://user?search=niceSearch&go=home#/view/joeldev?userID=evilPerson&&evilThing=evil"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(4);
    JLValidateParameter(@{@"userID": @"joeldev"});
    JLValidateParameter(@{@"go": @"home"});
    
    [self route:@"tests://post#/edit/123"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(3);
    JLValidateParameter(@{@"object": @"post"});
    JLValidateParameter(@{@"action": @"edit"});
    JLValidateParameter(@{@"primaryKey": @"123"});
    
    [self route:@"tests://interleaving/paramvalue1#/foo/paramvalue2"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(2);
    JLValidateParameter(@{@"param1": @"paramvalue1"});
    JLValidateParameter(@{@"param2": @"paramvalue2"});
    
    [self route:@"tests://xyz/wildcard#"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCountIncludingWildcard(0);
    
    [self route:@"tests://xyz/wildcard#/matches/with/extra/path/components"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    NSArray *wildcardMatches = @[@"matches", @"with", @"extra", @"path", @"components"];
    JLValidateParameter(@{JLRouteWildcardComponentsKey: wildcardMatches});
    
    [self route:@"tests://route#/matches/with/wildcard"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(2);
    JLValidateParameter(@{@"param": @"matches"});
    NSArray *parameterWildcardMatches = @[@"with", @"wildcard"];
    JLValidateParameter(@{JLRouteWildcardComponentsKey: parameterWildcardMatches});
    
    [self route:@"tests://doesnt/exist#/and/wont/match"];
    JLValidateNoLastMatch();
    
    [self route:@"tests://required#/mustExist"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"requiredParam": @"mustExist"});
    
    [self route:@"tests://required#/mustExist/optional/mightExist"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(2);
    JLValidateParameter(@{@"requiredParam": @"mustExist"});
    JLValidateParameter(@{@"optionalParam": @"mightExist"});
    
    [self route:@"tests://required#/mustExist/optional/mightExist/moreOptional/mightExistToo"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(3);
    JLValidateParameter(@{@"requiredParam": @"mustExist"});
    JLValidateParameter(@{@"optionalParam": @"mightExist"});
    JLValidateParameter(@{@"moreOptionalParam": @"mightExistToo"});
}

- (void)testMultipleRoutePatterns
{
    [[JLRoutes globalRoutes] addRoutes:@[@"/multiple1", @"/multiple2"] handler:[[self class] defaultRouteHandler]];
    
    [self route:@"tests://multiple1"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(0);
    
    [self route:@"tests://multiple2"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(0);
}

- (void)testPriority
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/test/priority/:level" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/test/priority/high" priority:20 handler:defaultHandler];
    
    // this should match the /test/priority/high route even though there's one before it that would match if priority wasn't being set
    [self route:@"tests://test/priority/high"];
    JLValidateAnyRouteMatched();
    JLValidatePattern(@"/test/priority/high");
    
    // test for adding only routes with non-zero priority (https://github.com/joeldev/JLRoutes/issues/46)
    [[JLRoutes routesForScheme:@"priorityTest"] addRoute:@"/:foo/bar/:baz" priority:20 handler:[[self class] defaultRouteHandler]];
    [[JLRoutes routesForScheme:@"priorityTest"] addRoute:@"/:foo/things/:baz" priority:10 handler:[[self class] defaultRouteHandler]];
    [[JLRoutes routesForScheme:@"priorityTest"] addRoute:@"/:foo/:baz" priority:1 handler:[[self class] defaultRouteHandler]];
    
    [self route:@"priorityTest://stuff/things/foo"];
    JLValidateAnyRouteMatched();
    
    [self route:@"priorityTest://one/two"];
    JLValidateAnyRouteMatched();
    
    [self route:@"priorityTest://stuff/bar/baz"];
    JLValidateAnyRouteMatched();
}

- (void)testBlockReturnValue
{
    [[JLRoutes globalRoutes] addRoute:@"/return/:value" handler:^BOOL(NSDictionary *parameters) {
        testsInstance.lastMatch = parameters;
        NSString *value = parameters[@"value"];
        return [value isEqualToString:@"yes"];
    }];
    
    // even though this matches a route, the block returns NO here so there won't be a valid match
    [self route:@"tests://return/no"];
    JLValidateNoLastMatch();
    
    // this one is the same route but will return yes, causing it to be flagged as a match
    [self route:@"tests://return/yes"];
    JLValidateAnyRouteMatched();
}

- (void)testSchemes
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/test" handler:defaultHandler];
    [[JLRoutes routesForScheme:@"namespaceTest1"] addRoute:@"/test" handler:defaultHandler];
    [[JLRoutes routesForScheme:@"namespaceTest2"] addRoute:@"/test" handler:defaultHandler];
    
    // test that the same route can be handled differently for three different scheme namespaces
    [self route:@"tests://test"];
    JLValidateAnyRouteMatched();
    JLValidateScheme(JLRoutesGlobalRoutesScheme);
    
    [self route:@"namespaceTest1://test"];
    JLValidateAnyRouteMatched();
    JLValidateScheme(@"namespaceTest1");
    
    [self route:@"namespaceTest2://test"];
    JLValidateAnyRouteMatched();
    JLValidateScheme(@"namespaceTest2");
}

- (void)testFallbackToGlobal
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/user/view/:userID" handler:defaultHandler];
    [[JLRoutes routesForScheme:@"namespaceTest1"] addRoute:@"/test" handler:defaultHandler];
    [[JLRoutes routesForScheme:@"namespaceTest2"] addRoute:@"/test" handler:defaultHandler];
    [JLRoutes routesForScheme:@"namespaceTest2"].shouldFallbackToGlobalRoutes = YES;
    
    // first case, fallback is off and so this should fail because this route isnt declared as part of namespaceTest1
    [self route:@"namespaceTest1://user/view/joeldev"];
    JLValidateNoLastMatch();
    
    // fallback is on, so this should route
    [self route:@"namespaceTest2://user/view/joeldev"];
    JLValidateAnyRouteMatched();
    JLValidateScheme(JLRoutesGlobalRoutesScheme);
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID" : @"joeldev"});
}

- (void)testForRouteExistence
{
    // This should return yes and no for whether we have a matching route.
    
    NSURL *shouldHaveRouteURL = [NSURL URLWithString:@"tests:/test"];
    NSURL *shouldNotHaveRouteURL = [NSURL URLWithString:@"tests:/dfjkbsdkjfbskjdfb/sdasd"];
    
    [[JLRoutes globalRoutes] addRoute:@"/test" handler:[[self class] defaultRouteHandler]];
    
    XCTAssertTrue([[JLRoutes globalRoutes] canRouteURL:shouldHaveRouteURL], @"Should state it can route known URL");
    XCTAssertFalse([[JLRoutes globalRoutes] canRouteURL:shouldNotHaveRouteURL], @"Should not state it can route unknown URL");
}

- (void)testSubscripting
{
    JLRoutes.globalRoutes[@"/subscripting"] = [[self class] defaultRouteHandler];
    
    NSURL *shouldHaveRouteURL = [NSURL URLWithString:@"subscripting"];
    
    XCTAssertTrue([[JLRoutes globalRoutes] canRouteURL:shouldHaveRouteURL], @"Should state it can route known URL");
}

- (void)testNonSingletonUsage
{
    JLRoutes *routes = [JLRoutes new];
    NSURL *trivialURL = [NSURL URLWithString:@"/success"];
    [routes addRoute:[trivialURL absoluteString] handler:nil];
    XCTAssertTrue([routes routeURL:trivialURL], @"Non-singleton instance should route known URL");
}

- (void)testRouteRemoval
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/:" handler:defaultHandler];
    [[JLRoutes routesForScheme:@"namespaceTest3"] addRoute:@"/test1" handler:defaultHandler];
    [[JLRoutes routesForScheme:@"namespaceTest3"] addRoute:@"/test2" handler:defaultHandler];
    
    [self route:@"namespaceTest3://test1"];
    JLValidateAnyRouteMatched();
    
    [[JLRoutes routesForScheme:@"namespaceTest3"] removeRouteWithPattern:@"/test1"];
    [self route:@"namespaceTest3://test1"];
    JLValidateNoLastMatch();
    
    [self route:@"namespaceTest3://test2"];
    JLValidateAnyRouteMatched();
    JLValidateScheme(@"namespaceTest3");
    
    [JLRoutes unregisterRouteScheme:@"namespaceTest3"];
    
    // this will get matched by our "/:" route in the global namespace - we just want to make sure it doesn't get matched by namespaceTest3
    [self route:@"namespaceTest3://test2"];
    JLValidateAnyRouteMatched();
    JLValidateScheme(JLRoutesGlobalRoutesScheme);
}

- (void)testPercentEncoding
{
    /*
     from http://en.wikipedia.org/wiki/Percent-encoding
     !   #   $   &   '   (   )   *   +   ,   /   :   ;   =   ?   @   [   ]
     %21 %23 %24 %26 %27 %28 %29 %2A %2B %2C %2F %3A %3B %3D %3F %40 %5B %5D
     */
    
    // NOTE: %2F is not supported.
    //  [URL pathComponents] automatically expands values with %2F as if it was just a regular slash.
    
    [[JLRoutes globalRoutes] addRoute:@"/user/view/:userID" handler:[[self class] defaultRouteHandler]];
    
    [JLRoutes setShouldDecodePlusSymbols:NO];
    
    [self route:@"tests://user/view/joel%21levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel!levin"});
    
    [self route:@"tests://user/view/joel%23levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel#levin"});
    
    [self route:@"tests://user/view/joel%24levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel$levin"});
    
    [self route:@"tests://user/view/joel%26levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel&levin"});
    
    [self route:@"tests://user/view/joel%27levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel'levin"});
    
    [self route:@"tests://user/view/joel%28levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel(levin"});
    
    [self route:@"tests://user/view/joel%29levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel)levin"});
    
    [self route:@"tests://user/view/joel%2Alevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel*levin"});
    
    [self route:@"tests://user/view/joel%2Blevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel+levin"});
    
    [self route:@"tests://user/view/joel%2Clevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel,levin"});
    
    [self route:@"tests://user/view/joel%3Alevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel:levin"});
    
    [self route:@"tests://user/view/joel%3Blevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel;levin"});
    
    [self route:@"tests://user/view/joel%3Dlevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel=levin"});
    
    [self route:@"tests://user/view/joel%3Flevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel?levin"});
    
    [self route:@"tests://user/view/joel%40levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel@levin"});
    
    [self route:@"tests://user/view/joel%5Blevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel[levin"});
    
    [self route:@"tests://user/view/joel%5Dlevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel]levin"});
}

- (void)testDecodePlusSymbols
{
    [[JLRoutes globalRoutes] addRoute:@"/user/view/:userID" handler:[[self class] defaultRouteHandler]];
    
    [JLRoutes setShouldDecodePlusSymbols:YES];
    
    [self route:@"tests://user/view/joel%2Blevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel levin"});
    
    [self route:@"tests://user/view/joel+levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel levin"});
    
    [self route:@"tests://user/view/test?name=joel+levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(2);
    JLValidateParameter(@{@"name": @"joel levin"});
    
    [self route:@"tests://user/view/test?people=joel+levin&people=foo+bar"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(2);
    JLValidateParameter((@{@"people": @[@"joel levin", @"foo bar"]}));
    
    [JLRoutes setShouldDecodePlusSymbols:NO];
    
    [self route:@"tests://user/view/joel%2Blevin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel+levin"});
    
    [self route:@"tests://user/view/joel+levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(1);
    JLValidateParameter(@{@"userID": @"joel+levin"});
    
    [self route:@"tests://user/view/test?name=joel+levin"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(2);
    JLValidateParameter(@{@"name": @"joel+levin"});
    
    [self route:@"tests://user/view/test?people=joel+levin&people=foo+bar"];
    JLValidateAnyRouteMatched();
    JLValidateParameterCount(2);
    JLValidateParameter((@{@"people": @[@"joel+levin", @"foo+bar"]}));
}

- (void)testVariableEmptyFollowedByWildcard
{
    [[JLRoutes routesForScheme:@"wildcardTests"] addRoute:@"list/:variable/detail/:variable2/*" handler:nil];
    
    [self route:@"wildcardTests://list/variable/detail/"];
    JLValidateNoLastMatch();
    
    [self route:@"wildcardTests://list/variable/detail/variable2"];
    JLValidateAnyRouteMatched();
}

- (void)testOptionalRoutesAtEnd
{
    [[JLRoutes globalRoutes] addRoute:@"/path/:thing(/new)(/anotherpath/:anotherthing)" handler:[[self class] defaultRouteHandler]];
    
    XCTAssert([[JLRoutes globalRoutes] routes].count == 4);
    
    [self route:@"foo://path/abc/new/anotherpath/def"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"thing": @"abc"});
    JLValidateParameter(@{@"anotherthing": @"def"});
    
    [self route:@"foo://path/foo/anotherpath/bar"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"thing": @"foo"});
    JLValidateParameter(@{@"anotherthing": @"bar"});
    
    [self route:@"foo://path/yyy/new"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"thing": @"yyy"});
    
    [self route:@"foo://path/zzz"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"thing": @"zzz"});
    
    [self route:@"foo://path/zzz/anotherpath"];
    JLValidateNoLastMatch();
}

- (void)testOptionalRoutesAtStart
{
    [[JLRoutes globalRoutes] addRoute:@"/(rest/)(app/):object/:id" handler:[[self class] defaultRouteHandler]];
    
    XCTAssert([[JLRoutes globalRoutes] routes].count == 4);
    
    [self route:@"foo://rest/app/aaa/bbb"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"object": @"aaa"});
    JLValidateParameter(@{@"id": @"bbb"});
    
    [self route:@"foo://app/aaa/bbb"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"object": @"aaa"});
    JLValidateParameter(@{@"id": @"bbb"});
    
    [self route:@"foo://rest/aaa/bbb"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"object": @"aaa"});
    JLValidateParameter(@{@"id": @"bbb"});
    
    [self route:@"foo://aaa/bbb"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"object": @"aaa"});
    JLValidateParameter(@{@"id": @"bbb"});
}

- (void)testOptionalRoutesInterleaved
{
    [[JLRoutes globalRoutes] addRoute:@"/(rest/):object/(app/):id" handler:[[self class] defaultRouteHandler]];
    
    XCTAssert([[JLRoutes globalRoutes] routes].count == 4);
    
    [self route:@"foo://rest/aaa/app/bbb"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"object": @"aaa"});
    JLValidateParameter(@{@"id": @"bbb"});
    
    [self route:@"foo://aaa/app/bbb"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"object": @"aaa"});
    JLValidateParameter(@{@"id": @"bbb"});
    
    [self route:@"foo://rest/aaa/bbb"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"object": @"aaa"});
    JLValidateParameter(@{@"id": @"bbb"});
    
    [self route:@"foo://aaa/bbb"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"object": @"aaa"});
    JLValidateParameter(@{@"id": @"bbb"});
}

- (void)testPassingURLStringsAsParams
{
    [[JLRoutes globalRoutes] addRoute:@"/web/:URLString" handler:[[self class] defaultRouteHandler]];
    [[JLRoutes globalRoutes] addRoute:@"/web" handler:[[self class] defaultRouteHandler]];
    
    [self route:@"tests://web/http%3A%2F%2Ffoobar.com%2Fbaz"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"URLString": @"http://foobar.com/baz"});
    
    [self route:@"tests://web?URLString=http%3A%2F%2Ffoobar.com%2Fbaz"];
    JLValidateAnyRouteMatched();
    JLValidateParameter(@{@"URLString": @"http://foobar.com/baz"});
}

- (void)testArrayQueryParams
{
    [[JLRoutes globalRoutes] addRoute:@"/test/foo" handler:[[self class] defaultRouteHandler]];
    
    [self route:@"tests://test/foo?key=1&key=2&key=3&text=hi&text=there"];
    JLValidateAnyRouteMatched();
    JLValidateParameter((@{@"key": @[@"1", @"2", @"3"]}));
    JLValidateParameter((@{@"text": @[@"hi", @"there"]}));
}

- (void)testAddingCustomRouteDefinition
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    JLRMockRouteDefinition *customRoute = [[JLRMockRouteDefinition alloc] initWithPattern:@"/test" priority:0 handlerBlock:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:customRoute];
    
    [self route:@"tests://test"];
    
    JLValidateAnyRouteMatched();
    JLValidateScheme(JLRoutesGlobalRoutesScheme);
    
    [[JLRoutes globalRoutes] removeRoute:customRoute];
    
    [self route:@"tests://test"];
    
    JLValidateNoLastMatch();
}

- (void)testChangeDefaultRouteDefinitionClass
{
    [JLRoutes setDefaultRouteDefinitionClass:[JLRMockRouteDefinition class]];
    
    id defaultHandler = [[self class] defaultRouteHandler];
    [[JLRoutes globalRoutes] addRoute:@"/foo" handler:defaultHandler];
    
    JLRRouteDefinition *route = [JLRoutes globalRoutes].routes.firstObject;
    XCTAssert([route isKindOfClass:[JLRMockRouteDefinition class]]);
}

- (void)testTreatsHostAsPathComponent
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    [[JLRoutes globalRoutes] addRoute:@"/sign_in" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/path/:pathid" handler:defaultHandler];
    
    [JLRoutes setAlwaysTreatsHostAsPathComponent:NO];
    
    [self route:@"https://www.mydomain.com/sign_in"];
    JLValidateAnyRouteMatched();
    JLValidatePattern(@"/sign_in");
    
    [self route:@"https://www.mydomain.com/path/3"];
    JLValidateAnyRouteMatched();
    JLValidatePattern(@"/path/:pathid");
    JLValidateParameter((@{@"pathid": @"3"}));
    
    [JLRoutes setAlwaysTreatsHostAsPathComponent:YES];
    
    [self route:@"https://www.mydomain2.com/sign_in"];
    JLValidateNoLastMatch();
    
    [self route:@"https://www.mydomain2.com/path/3"];
    JLValidateNoLastMatch();
    
    [[JLRoutes globalRoutes] addRoute:@"/www.mydomain2.com/sign_in" handler:defaultHandler];
    [[JLRoutes globalRoutes] addRoute:@"/www.mydomain2.com/path/:pathid" handler:defaultHandler];
    
    [self route:@"https://www.mydomain2.com/sign_in"];
    JLValidateAnyRouteMatched();
    JLValidatePattern(@"/www.mydomain2.com/sign_in");
    
    [self route:@"https://www.mydomain2.com/path/3"];
    JLValidateAnyRouteMatched();
    JLValidatePattern(@"/www.mydomain2.com/path/:pathid");
    JLValidateParameter((@{@"pathid": @"3"}));
}

- (void)testRouteDefinitionEquality
{
    id defaultHandler = [[self class] defaultRouteHandler];
    
    JLRRouteDefinition *routeA = [[JLRRouteDefinition alloc] initWithPattern:@"/foo" priority:0 handlerBlock:defaultHandler];
    JLRRouteDefinition *routeB = [routeA copy];
    
    XCTAssertTrue([routeA isEqual:routeB]);
    
    [routeB didBecomeRegisteredForScheme:@"scheme"];
    
    XCTAssertFalse([routeA isEqual:routeB]);
    
    JLRRouteDefinition *routeC = [[JLRRouteDefinition alloc] initWithPattern:@"/foo/bar" priority:0 handlerBlock:defaultHandler];
    
    XCTAssertFalse([routeA isEqual:routeC]);
}

- (void)testHandlerBlockForWeakTarget
{
    JLRMockTargetObject *object = [[JLRMockTargetObject alloc] init];
    id handlerBlock = [JLRRouteHandler handlerBlockForWeakTarget:object];
    
    [[JLRoutes globalRoutes] addRoute:@"/test" handler:handlerBlock];
    
    [self route:@"/test"];
    JLValidateAnyRouteMatched();
    XCTAssertEqualObjects(testsInstance.lastMatch, object.routeParams);
    
    object = nil; // ensure that the object is not retained by handler block
    
    [self route:@"/test"];
    JLValidateNoLastMatch();
}

- (void)testHandlerBlockForTargetClass
{
    __block JLRMockTargetObject *createdObject = nil;
    id handlerBlock = [JLRRouteHandler handlerBlockForTargetClass:[JLRMockTargetObject class] completion:^BOOL (id<JLRRouteHandlerTarget> object) {
        createdObject = (JLRMockTargetObject *)object;
        return YES;
    }];
    
    [[JLRoutes globalRoutes] addRoute:@"/test" handler:handlerBlock];
    
    [self route:@"/test"];
    JLValidateAnyRouteMatched();
    XCTAssertEqualObjects(testsInstance.lastMatch, createdObject.routeParams);
    
    XCTAssertNotNil(createdObject);
}

#pragma mark - Convenience Methods

+ (BOOL (^)(NSDictionary *))defaultRouteHandler
{
    return ^BOOL (NSDictionary *params) {
        testsInstance.lastMatch = params;
        return YES;
    };
}

- (void)route:(NSString *)URLString
{
    [self route:URLString withParameters:nil];
}

- (void)route:(NSString *)URLString withParameters:(NSDictionary *)parameters
{
    [self routeURL:[NSURL URLWithString:URLString] withParameters:parameters];
}

- (void)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
    NSLog(@"*** Routing %@", URL);
    self.lastMatch = nil;
    self.didRoute = [JLRoutes routeURL:URL withParameters:parameters];
}

@end


@implementation JLRMockTargetObject

- (instancetype)initWithRouteParameters:(NSDictionary<NSString *,id> *)parameters
{
    self = [super init];
    self.routeParams = parameters;
    testsInstance.lastMatch = parameters;
    return self;
}

- (BOOL)handleRouteWithParameters:(NSDictionary<NSString *, id> *)parameters
{
    self.routeParams = parameters;
    testsInstance.lastMatch = parameters;
    return YES;
}

@end


@implementation JLRMockRouteDefinition

@end

