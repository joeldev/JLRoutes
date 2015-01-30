/*
 Copyright (c) 2013, Joel Levin
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of JLRoutes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "JLRoutes.h"


static NSMutableDictionary *routeControllersMap = nil;
static BOOL verboseLoggingEnabled = NO;
static BOOL shouldDecodePlusSymbols = YES;


@interface JLRoutes ()

@property (nonatomic, strong) NSMutableArray *routes;
@property (nonatomic, strong) NSString *namespaceKey;

+ (void)verboseLogWithFormat:(NSString *)format, ...;
+ (BOOL)routeURL:(NSURL *)URL withController:(JLRoutes *)routesController parameters:(NSDictionary *)parameters;
- (BOOL)isGlobalRoutesController;

@end


@interface NSString (JLRoutes)

- (NSString *)JLRoutes_URLDecodedString;
- (NSDictionary *)JLRoutes_URLParameterDictionary;

@end


@implementation NSString (JLRoutes)

- (NSString *)JLRoutes_URLDecodedString {
	NSString *input = shouldDecodePlusSymbols ? [self stringByReplacingOccurrencesOfString:@"+" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, self.length)] : self;
	return [input stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSDictionary *)JLRoutes_URLParameterDictionary {
	NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

	if (self.length && [self rangeOfString:@"="].location != NSNotFound) {
		NSArray *keyValuePairs = [self componentsSeparatedByString:@"&"];
		for (NSString *keyValuePair in keyValuePairs) {
			NSArray *pair = [keyValuePair componentsSeparatedByString:@"="];
			// don't assume we actually got a real key=value pair. start by assuming we only got @[key] before checking count
			NSString *paramValue = pair.count == 2 ? pair[1] : @"";
			// CFURLCreateStringByReplacingPercentEscapesUsingEncoding may return NULL
			parameters[pair[0]] = [paramValue JLRoutes_URLDecodedString] ?: @"";
		}
	}

	return parameters;
}

@end


@interface _JLRoute : NSObject

@property (nonatomic, weak) JLRoutes *parentRoutesController;
@property (nonatomic, strong) NSString *pattern;
@property (nonatomic, strong) BOOL (^block)(NSDictionary *parameters);
@property (nonatomic, assign) NSUInteger priority;
@property (nonatomic, strong) NSArray *patternPathComponents;

- (NSDictionary *)parametersForURL:(NSURL *)URL components:(NSArray *)URLComponents;

@end


@implementation _JLRoute

- (NSDictionary *)parametersForURL:(NSURL *)URL components:(NSArray *)URLComponents {
	NSDictionary *routeParameters = nil;
	
	if (!self.patternPathComponents) {
		self.patternPathComponents = [[self.pattern pathComponents] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF like '/'"]];
	}
	
	// do a quick component count check to quickly eliminate incorrect patterns
	BOOL componentCountEqual = self.patternPathComponents.count == URLComponents.count;
	BOOL routeContainsWildcard = !NSEqualRanges([self.pattern rangeOfString:@"*"], NSMakeRange(NSNotFound, 0));
	if (componentCountEqual || routeContainsWildcard) {
		// now that we've identified a possible match, move component by component to check if it's a match
		NSUInteger componentIndex = 0;
		NSMutableDictionary *variables = [NSMutableDictionary dictionary];
		BOOL isMatch = YES;
		
		for (NSString *patternComponent in self.patternPathComponents) {
			NSString *URLComponent = nil;
			if (componentIndex < [URLComponents count]) {
				URLComponent = URLComponents[componentIndex];
			} else if ([patternComponent isEqualToString:@"*"]) { // match /foo by /foo/*
				URLComponent = [URLComponents lastObject];
			}
			
			if ([patternComponent hasPrefix:@":"]) {
				// this component is a variable
				NSString *variableName = [patternComponent substringFromIndex:1];
				NSString *variableValue = URLComponent;
				NSString *urlDecodedVariableValue = [variableValue JLRoutes_URLDecodedString];
				if ([variableName length] > 0 && [urlDecodedVariableValue length] > 0) {
					variables[variableName] = urlDecodedVariableValue;
				}
			} else if ([patternComponent isEqualToString:@"*"]) {
				// match wildcards
				variables[kJLRouteWildcardComponentsKey] = [URLComponents subarrayWithRange:NSMakeRange(componentIndex, URLComponents.count-componentIndex)];
				isMatch = YES;
				break;
			} else if (![patternComponent isEqualToString:URLComponent]) {
				// a non-variable component did not match, so this route doesn't match up - on to the next one
				isMatch = NO;
				break;
			}
			componentIndex++;
		}
		
		if (isMatch) {
			routeParameters = variables;
		}
	}
	
	return routeParameters;
}


- (NSString *)description {
	return [NSString stringWithFormat:@"JLRoute %@ (%@)", self.pattern, @(self.priority)];
}


@end


@implementation JLRoutes

- (id)init {
	if ((self = [super init])) {
		self.routes = [NSMutableArray array];
	}
	return self;
}

+ (void)setShouldDecodePlusSymbols:(BOOL)shouldDecode {
	shouldDecodePlusSymbols = shouldDecode;
}

+ (BOOL)shouldDecodePlusSymbols {
	return shouldDecodePlusSymbols;
}

#pragma mark -
#pragma mark Routing API

+ (instancetype)globalRoutes {
	return [self routesForScheme:kJLRoutesGlobalNamespaceKey];
}


+ (instancetype)routesForScheme:(NSString *)scheme {
	JLRoutes *routesController = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		routeControllersMap = [[NSMutableDictionary alloc] init];
	});
	
	if (!routeControllersMap[scheme]) {
		routesController = [[self alloc] init];
		routesController.namespaceKey = scheme;
		routeControllersMap[scheme] = routesController;
	}
	
	routesController = routeControllersMap[scheme];
	
	return routesController;
}


+ (void)addRoute:(NSString *)routePattern handler:(BOOL (^)(NSDictionary *parameters))handlerBlock {
	[[self globalRoutes] addRoute:routePattern handler:handlerBlock];
}


+ (void)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock {
	[[self globalRoutes] addRoute:routePattern priority:priority handler:handlerBlock];
}


- (void)addRoute:(NSString *)routePattern handler:(BOOL (^)(NSDictionary *parameters))handlerBlock {
	[self addRoute:routePattern priority:0 handler:handlerBlock];
}


- (void)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock {
	_JLRoute *route = [[_JLRoute alloc] init];
	route.pattern = routePattern;
	route.priority = priority;
	route.block = [handlerBlock copy];
	route.parentRoutesController = self;
	
	if (!route.block) {
		route.block = [^BOOL (NSDictionary *params) {
			return YES;
		} copy];
	}
	
	if (priority == 0 || self.routes.count == 0) {
		[self.routes addObject:route];
	} else {
		NSArray *existingRoutes = self.routes;
		NSUInteger index = 0;
        BOOL addedRoute = NO;
        
        // search through existing routes looking for a lower priority route than this one
		for (_JLRoute *existingRoute in existingRoutes) {
			if (existingRoute.priority < priority) {
                // if found, add the route after it
				[self.routes insertObject:route atIndex:index];
                addedRoute = YES;
				break;
			}
			index++;
		}
        
        // if we weren't able to find a lower priority route, this is the new lowest priority route (or same priority as self.routes.lastObject) and should just be added
        if (!addedRoute)
            [self.routes addObject:route];
	}
}


+ (void)removeRoute:(NSString *)routePattern {
	[[JLRoutes globalRoutes] removeRoute:routePattern];
}


- (void)removeRoute:(NSString *)routePattern {
	if (![routePattern hasPrefix:@"/"]) {
		routePattern = [NSString stringWithFormat:@"/%@", routePattern];
	}
	
	NSInteger routeIndex = NSNotFound;
	NSInteger index = 0;
	
	for (_JLRoute *route in self.routes) {
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


+ (void)removeAllRoutes {
	[[JLRoutes globalRoutes] removeAllRoutes];
}


- (void)removeAllRoutes {
	[self.routes removeAllObjects];
}


+ (void)unregisterRouteScheme:(NSString *)scheme {
	[routeControllersMap removeObjectForKey:scheme];
}


+ (BOOL)routeURL:(NSURL *)URL {
	return [self routeURL:URL withParameters:nil executeRouteBlock:YES];
}

+ (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters {
    return [self routeURL:URL withParameters:parameters executeRouteBlock:YES];
}


+ (BOOL)canRouteURL:(NSURL *)URL {
    return [self routeURL:URL withParameters:nil executeRouteBlock:NO];
}

+ (BOOL)canRouteURL:(NSURL *)URL withParameters:(NSDictionary *)parameters {
    return [self routeURL:URL withParameters:parameters executeRouteBlock:NO];
}

+ (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters executeRouteBlock:(BOOL)execute {
	if (!URL) {
		return NO;
	}

	// figure out which routes controller to use based on the scheme
	JLRoutes *routesController = routeControllersMap[[URL scheme]] ?: [self globalRoutes];

	return [self routeURL:URL withController:routesController parameters:parameters executeBlock:execute];
}

- (BOOL)routeURL:(NSURL *)URL {
	return [[self class] routeURL:URL withController:self];
}

- (BOOL)routeURL:(NSURL *)URL withParameters:(NSDictionary *)parameters {
	return [[self class] routeURL:URL withController:self parameters:parameters];
}

- (BOOL)canRouteURL:(NSURL *)URL {
	return [[self class] routeURL:URL withController:self parameters:nil executeBlock:NO];
}

- (BOOL)canRouteURL:(NSURL *)URL withParameters:(NSDictionary *)parameters {
	return [[self class] routeURL:URL withController:self parameters:parameters executeBlock:NO];
}

#pragma mark -
#pragma mark Debugging Aids

- (NSString *)description {
	return [self.routes description];
}


+ (NSString *)description {
	NSMutableString *descriptionString = [NSMutableString stringWithString:@"\n"];
	
	for (NSString *routesNamespace in routeControllersMap) {
		JLRoutes *routesController = routeControllersMap[routesNamespace];
		[descriptionString appendFormat:@"\"%@\":\n%@\n\n", routesController.namespaceKey, routesController.routes];
	}
	
	return descriptionString;
}


+ (void)setVerboseLoggingEnabled:(BOOL)loggingEnabled {
	verboseLoggingEnabled = loggingEnabled;
}


+ (BOOL)isVerboseLoggingEnabled {
	return verboseLoggingEnabled;
}


#pragma mark -
#pragma mark Internal API

+ (BOOL)routeURL:(NSURL *)URL withController:(JLRoutes *)routesController {
    return [self routeURL:URL withController:routesController parameters:nil executeBlock:YES];
}

+ (BOOL)routeURL:(NSURL *)URL withController:(JLRoutes *)routesController parameters:(NSDictionary *)parameters {
    return [self routeURL:URL withController:routesController parameters:parameters executeBlock:YES];
}

+ (BOOL)routeURL:(NSURL *)URL withController:(JLRoutes *)routesController parameters:(NSDictionary *)parameters executeBlock:(BOOL)executeBlock {
	[self verboseLogWithFormat:@"Trying to route URL %@", URL];
	BOOL didRoute = NO;
	NSArray *routes = routesController.routes;
	NSDictionary *queryParameters = [URL.query JLRoutes_URLParameterDictionary];
	[self verboseLogWithFormat:@"Parsed query parameters: %@", queryParameters];

	NSDictionary *fragmentParameters = [URL.fragment JLRoutes_URLParameterDictionary];
	[self verboseLogWithFormat:@"Parsed fragment parameters: %@", fragmentParameters];

	// break the URL down into path components and filter out any leading/trailing slashes from it
	NSArray *pathComponents = [(URL.pathComponents ?: @[]) filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF like '/'"]];
	
	if ([URL.host rangeOfString:@"."].location == NSNotFound && ![URL.host isEqualToString:@"localhost"]) {
		// For backward compatibility, handle scheme://path/to/ressource as if path was part of the
		// path if it doesn't look like a domain name (no dot in it)
		pathComponents = [@[URL.host] arrayByAddingObjectsFromArray:pathComponents];
	}
	
	[self verboseLogWithFormat:@"URL path components: %@", pathComponents];
	
	for (_JLRoute *route in routes) {
		NSDictionary *matchParameters = [route parametersForURL:URL components:pathComponents];
		if (matchParameters) {
			[self verboseLogWithFormat:@"Successfully matched %@", route];
            if (!executeBlock) {
                return YES;
            }

			// add the URL parameters
			NSMutableDictionary *finalParameters = [NSMutableDictionary dictionary];

			// in increasing order of precedence: query, fragment, route, builtin
			[finalParameters addEntriesFromDictionary:queryParameters];
			[finalParameters addEntriesFromDictionary:fragmentParameters];
			[finalParameters addEntriesFromDictionary:matchParameters];
			[finalParameters addEntriesFromDictionary:parameters];
			finalParameters[kJLRoutePatternKey] = route.pattern;
			finalParameters[kJLRouteURLKey] = URL;
            __strong __typeof(route.parentRoutesController) strongParentRoutesController = route.parentRoutesController;
			finalParameters[kJLRouteNamespaceKey] = strongParentRoutesController.namespaceKey ?: [NSNull null];

			[self verboseLogWithFormat:@"Final parameters are %@", finalParameters];
			didRoute = route.block(finalParameters);
			if (didRoute) {
				break;
			}
		}
	}
	
	if (!didRoute) {
		[self verboseLogWithFormat:@"Could not find a matching route, returning NO"];
	}
	
	// if we couldn't find a match and this routes controller specifies to fallback and its also not the global routes controller, then...
	if (!didRoute && routesController.shouldFallbackToGlobalRoutes && ![routesController isGlobalRoutesController]) {
		[self verboseLogWithFormat:@"Falling back to global routes..."];
		didRoute = [self routeURL:URL withController:[self globalRoutes] parameters:parameters executeBlock:executeBlock];
	}
	
	// if, after everything, we did not route anything and we have an unmatched URL handler, then call it
	if (!didRoute && routesController.unmatchedURLHandler) {
		routesController.unmatchedURLHandler(routesController, URL, parameters);
	}
	
	return didRoute;
}


- (BOOL)isGlobalRoutesController {
	return [self.namespaceKey isEqualToString:kJLRoutesGlobalNamespaceKey];
}


+ (void)verboseLogWithFormat:(NSString *)format, ... {
	if (verboseLoggingEnabled && format) {
		va_list argsList;
		va_start(argsList, format);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
		NSString *formattedLogMessage = [[NSString alloc] initWithFormat:format arguments:argsList];
#pragma clang diagnostic pop
		
		va_end(argsList);
		NSLog(@"[JLRoutes]: %@", formattedLogMessage);
	}
}

#pragma mark -
#pragma mark Subscripting

- (void)setObject:(id)handlerBlock forKeyedSubscript:(NSString *)routePatten {
  [self addRoute:routePatten handler:handlerBlock];
}

@end
