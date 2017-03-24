/*
 Copyright (c) 2017, Joel Levin
 All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of JLRoutes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "JLRoutes.h"
#import "JLRRouteDefinition.h"
#import "JLROptionalRouteParser.h"


NSString *const JLRoutePatternKey = @"JLRoutePattern";
NSString *const JLRouteURLKey = @"JLRouteURL";
NSString *const JLRouteSchemeKey = @"JLRouteScheme";
NSString *const JLRouteWildcardComponentsKey = @"JLRouteWildcardComponents";
NSString *const JLRoutesGlobalRoutesScheme = @"JLRoutesGlobalRoutesScheme";


static NSMutableDictionary *routeControllersMap = nil;
static BOOL verboseLoggingEnabled = NO;
static BOOL shouldDecodePlusSymbols = YES;


@interface JLRoutes ()

@property (nonatomic, strong) NSMutableArray *routes;
@property (nonatomic, strong) NSString *scheme;

@end


#pragma mark -

@implementation JLRoutes

- (instancetype)init
{
    if ((self = [super init])) {
        self.routes = [NSMutableArray array];
    }
    return self;
}

- (NSString *)description
{
    return [self.routes description];
}

+ (NSString *)allRoutes
{
    NSMutableString *descriptionString = [NSMutableString stringWithString:@"\n"];
    
    for (NSString *routesNamespace in routeControllersMap) {
        JLRoutes *routesController = routeControllersMap[routesNamespace];
        [descriptionString appendFormat:@"\"%@\":\n%@\n\n", routesController.scheme, routesController.routes];
    }
    
    return descriptionString;
}


#pragma mark - Routing Schemes

+ (instancetype)globalRoutes
{
    return [self routesForScheme:JLRoutesGlobalRoutesScheme];
}

+ (instancetype)routesForScheme:(NSString *)scheme
{
    JLRoutes *routesController = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        routeControllersMap = [[NSMutableDictionary alloc] init];
    });
    
    if (!routeControllersMap[scheme]) {
        routesController = [[self alloc] init];
        routesController.scheme = scheme;
        routeControllersMap[scheme] = routesController;
    }
    
    routesController = routeControllersMap[scheme];
    
    return routesController;
}

+ (void)unregisterRouteScheme:(NSString *)scheme
{
    [routeControllersMap removeObjectForKey:scheme];
}

+ (void)unregisterAllRouteSchemes
{
    [routeControllersMap removeAllObjects];
}


#pragma mark - Registering Routes

- (void)addRoute:(NSString *)routePattern handler:(BOOL (^)(NSDictionary<NSString *, id> *parameters))handlerBlock
{
    [self addRoute:routePattern priority:0 handler:handlerBlock];
}

- (void)addRoutes:(NSArray<NSString *> *)routePatterns handler:(BOOL (^)(NSDictionary<NSString *, id> *parameters))handlerBlock
{
    for (NSString *routePattern in routePatterns) {
        [self addRoute:routePattern handler:handlerBlock];
    }
}

- (void)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary<NSString *, id> *parameters))handlerBlock
{
    NSArray <NSString *> *optionalRoutePatterns = [JLROptionalRouteParser expandOptionalRoutePatternsForPattern:routePattern];
    
    if (optionalRoutePatterns.count > 0) {
        // there are optional params, parse and add them
        for (NSString *route in optionalRoutePatterns) {
            [self _verboseLog:@"Automatically created optional route: %@", route];
            [self _registerRoute:route priority:priority handler:handlerBlock];
        }
        return;
    }
    
    [self _registerRoute:routePattern priority:priority handler:handlerBlock];
}

- (void)removeRoute:(NSString *)routePattern
{
    if (![routePattern hasPrefix:@"/"]) {
        routePattern = [NSString stringWithFormat:@"/%@", routePattern];
    }
    
    NSInteger routeIndex = NSNotFound;
    NSInteger index = 0;
    
    for (JLRRouteDefinition *route in [self.routes copy]) {
        if ([route.pattern isEqualToString:routePattern]) {
            routeIndex = index;
            break;
        }
        index++;
    }
    
    if (routeIndex != NSNotFound) {
        [self.routes removeObjectAtIndex:(NSUInteger)routeIndex];
    }
}

- (void)removeAllRoutes
{
    [self.routes removeAllObjects];
}

- (void)setObject:(id)handlerBlock forKeyedSubscript:(NSString *)routePatten
{
    [self addRoute:routePatten handler:handlerBlock];
}


#pragma mark - Routing URLs

+ (BOOL)canRouteURL:(NSURL *)URL
{
    return [[self _routesControllerForURL:URL] canRouteURL:URL];
}

- (BOOL)canRouteURL:(NSURL *)URL
{
    return [self _routeURL:URL withParameters:nil executeRouteBlock:NO];
}

+ (BOOL)routeURL:(NSURL *)URL
{
    return [[self _routesControllerForURL:URL] routeURL:URL];
}

- (BOOL)routeURL:(NSURL *)URL
{
    return [self _routeURL:URL withParameters:nil executeRouteBlock:YES];
}

+ (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
    return [[self _routesControllerForURL:URL] routeURL:URL withParameters:parameters];
}

- (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
    return [self _routeURL:URL withParameters:parameters executeRouteBlock:YES];
}


#pragma mark - Private

+ (instancetype)_routesControllerForURL:(NSURL *)URL
{
    if (URL == nil) {
        return nil;
    }
    
    return routeControllersMap[URL.scheme] ?: [JLRoutes globalRoutes];
}

- (void)_registerRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
    JLRRouteDefinition *route = [[JLRRouteDefinition alloc] initWithScheme:self.scheme pattern:routePattern priority:priority handlerBlock:handlerBlock];
    
    if (priority == 0 || self.routes.count == 0) {
        [self.routes addObject:route];
    } else {
        NSUInteger index = 0;
        BOOL addedRoute = NO;
        
        // search through existing routes looking for a lower priority route than this one
        for (JLRRouteDefinition *existingRoute in [self.routes copy]) {
            if (existingRoute.priority < priority) {
                // if found, add the route after it
                [self.routes insertObject:route atIndex:index];
                addedRoute = YES;
                break;
            }
            index++;
        }
        
        // if we weren't able to find a lower priority route, this is the new lowest priority route (or same priority as self.routes.lastObject) and should just be added
        if (!addedRoute) {
            [self.routes addObject:route];
        }
    }
}

- (BOOL)_routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters executeRouteBlock:(BOOL)executeRouteBlock
{
    if (!URL) {
        return NO;
    }
    
    [self _verboseLog:@"Trying to route URL %@", URL];
    
    BOOL didRoute = NO;
    JLRRouteRequest *request = [[JLRRouteRequest alloc] initWithURL:URL];
    
    for (JLRRouteDefinition *route in [self.routes copy]) {
        // check each route for a matching response
        JLRRouteResponse *response = [route routeResponseForRequest:request decodePlusSymbols:shouldDecodePlusSymbols];
        if (!response.isMatch) {
            continue;
        }
        
        [self _verboseLog:@"Successfully matched %@", route];
        
        if (!executeRouteBlock) {
            // if we shouldn't execute but it was a match, we're done now
            return YES;
        }
        
        // configure the final parameters
        NSMutableDictionary *finalParameters = [NSMutableDictionary dictionary];
        [finalParameters addEntriesFromDictionary:response.parameters];
        [finalParameters addEntriesFromDictionary:parameters];
        [self _verboseLog:@"Final parameters are %@", finalParameters];
        
        didRoute = [route callHandlerBlockWithParameters:finalParameters];
        
        if (didRoute) {
            // if it was routed successfully, we're done
            break;
        }
    }
    
    if (!didRoute) {
        [self _verboseLog:@"Could not find a matching route"];
    }
    
    // if we couldn't find a match and this routes controller specifies to fallback and its also not the global routes controller, then...
    if (!didRoute && self.shouldFallbackToGlobalRoutes && ![self _isGlobalRoutesController]) {
        [self _verboseLog:@"Falling back to global routes..."];
        didRoute = [[JLRoutes globalRoutes] _routeURL:URL withParameters:parameters executeRouteBlock:executeRouteBlock];
    }
    
    // if, after everything, we did not route anything and we have an unmatched URL handler, then call it
    if (!didRoute && executeRouteBlock && self.unmatchedURLHandler) {
        [self _verboseLog:@"Falling back to the unmatched URL handler"];
        self.unmatchedURLHandler(self, URL, parameters);
    }
    
    return didRoute;
}

- (BOOL)_isGlobalRoutesController
{
    return [self.scheme isEqualToString:JLRoutesGlobalRoutesScheme];
}

- (void)_verboseLog:(NSString *)format, ...
{
    if (!verboseLoggingEnabled || format.length == 0) {
        return;
    }
    
    va_list argsList;
    va_start(argsList, format);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
    NSString *formattedLogMessage = [[NSString alloc] initWithFormat:format arguments:argsList];
#pragma clang diagnostic pop
    
    va_end(argsList);
    NSLog(@"[JLRoutes]: %@", formattedLogMessage);
}

@end


#pragma mark - Global Options

@implementation JLRoutes (GlobalOptions)

+ (void)setVerboseLoggingEnabled:(BOOL)loggingEnabled
{
    verboseLoggingEnabled = loggingEnabled;
}

+ (BOOL)isVerboseLoggingEnabled
{
    return verboseLoggingEnabled;
}

+ (void)setShouldDecodePlusSymbols:(BOOL)shouldDecode
{
    shouldDecodePlusSymbols = shouldDecode;
}

+ (BOOL)shouldDecodePlusSymbols
{
    return shouldDecodePlusSymbols;
}

@end


#pragma mark - Deprecated

// deprecated
NSString *const kJLRoutePatternKey = @"JLRoutePattern";
NSString *const kJLRouteURLKey = @"JLRouteURL";
NSString *const kJLRouteSchemeKey = @"JLRouteScheme";
NSString *const kJLRouteWildcardComponentsKey = @"JLRouteWildcardComponents";
NSString *const kJLRoutesGlobalRoutesScheme = @"JLRoutesGlobalRoutesScheme";

NSString *const kJLRouteNamespaceKey = @"JLRouteScheme"; // deprecated
NSString *const kJLRoutesGlobalNamespaceKey = @"JLRoutesGlobalRoutesScheme"; // deprecated

@implementation JLRoutes (Deprecated)

+ (void)addRoute:(NSString *)routePattern handler:(BOOL (^)(NSDictionary<NSString *, id> *parameters))handlerBlock
{
    [[self globalRoutes] addRoute:routePattern handler:handlerBlock];
}

+ (void)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary<NSString *, id> *parameters))handlerBlock
{
    [[self globalRoutes] addRoute:routePattern priority:priority handler:handlerBlock];
}

+ (void)addRoutes:(NSArray<NSString *> *)routePatterns handler:(BOOL (^)(NSDictionary<NSString *, id> *parameters))handlerBlock
{
    [[self globalRoutes] addRoutes:routePatterns handler:handlerBlock];
}

+ (void)removeRoute:(NSString *)routePattern
{
    [[self globalRoutes] removeRoute:routePattern];
}

+ (void)removeAllRoutes
{
    [[self globalRoutes] removeAllRoutes];
}

+ (BOOL)canRouteURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
    return [[self globalRoutes] canRouteURL:URL];
}

- (BOOL)canRouteURL:(NSURL *)URL withParameters:(NSDictionary *)parameters
{
    return [self canRouteURL:URL];
}

@end
