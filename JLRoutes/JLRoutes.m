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


@interface JLRoutes ()

@property (strong) NSMutableArray *routes;

+ (JLRoutes *)sharedInstance;

@end


@interface _JLRoute : NSObject

@property (strong) NSString *pattern;
@property (strong) BOOL (^block)(NSDictionary *parameters);
@property (assign) NSUInteger priority;
@property (strong) NSArray *patternPathComponents;

- (NSDictionary *)parametersForURL:(NSURL *)URL components:(NSArray *)URLComponents;

@end


@implementation _JLRoute

- (NSDictionary *)parametersForURL:(NSURL *)URL components:(NSArray *)URLComponents {
	NSMutableDictionary *routeParameters = nil;
	
	if (!self.patternPathComponents) {
		self.patternPathComponents = [self.pattern pathComponents];
	}
	
	// do a quick component count check to quickly eliminate incorrect patterns
	if (self.patternPathComponents.count == URLComponents.count) {
		// now that we've identified a possible match, move component by component to check if it's a match
		NSUInteger componentIndex = 0;
		NSMutableDictionary *variables = [NSMutableDictionary dictionary];
		BOOL isMatch = YES;
		
		for (NSString *patternComponent in self.patternPathComponents) {
			NSString *URLComponent = URLComponents[componentIndex];
			if ([patternComponent hasPrefix:@":"]) {
				// this component is a variable
				NSString *variableName = [patternComponent substringFromIndex:1];
				NSString *variableValue = URLComponent;
				variables[variableName] = variableValue;
			} else if (![patternComponent isEqualToString:URLComponent]) {
				// a non-variable component did not match, so this route doesn't match up - on to the next one
				isMatch = NO;
				break;
			}
			componentIndex++;
		}
		
		if (isMatch) {
			// we found a match, start loading up the route parameters
			routeParameters = [NSMutableDictionary dictionary];
			routeParameters[kJLRoutePatternKey] = self.pattern;
			routeParameters[kJLRouteURLKey] = URL;
			routeParameters[kJLRouteParametersKey] = variables;
		}
	}
	
	return routeParameters;
}


@end


@implementation JLRoutes

+ (JLRoutes *)sharedInstance {
	static JLRoutes *staticInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		staticInstance = [[JLRoutes alloc] init];
	});
	
	return staticInstance;
}


- (id)init {
	if ((self = [super init])) {
		self.routes = [NSMutableArray array];
	}
	return self;
}


+ (void)addRoute:(NSString *)routePattern handler:(BOOL (^)(NSDictionary *parameters))handlerBlock {
	[[self class] addRoute:routePattern priority:0 handler:handlerBlock];
}


+ (void)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^)(NSDictionary *parameters))handlerBlock {
	_JLRoute *route = [[_JLRoute alloc] init];
	route.pattern = routePattern;
	route.priority = priority;
	route.block = [handlerBlock copy];
	
	if (!route.block) {
		route.block = [^BOOL (NSDictionary *params) {
			return YES;
		} copy];
	}
	
	if (priority == 0) {
		[[self sharedInstance].routes addObject:route];
	} else {
		NSArray *existingRoutes = [self sharedInstance].routes;
		NSUInteger index = 0;
		for (_JLRoute *existingRoute in existingRoutes) {
			if (existingRoute.priority < priority) {
				[[self sharedInstance].routes insertObject:route atIndex:index];
				break;
			}
			index++;
		}
	}
}


+ (BOOL)routeURL:(NSURL *)URL {
	BOOL didRoute = NO;
	NSArray *routes = [self sharedInstance].routes;
	NSMutableDictionary *URLParameters = [NSMutableDictionary dictionary];
	
	NSString *URLString = [URL absoluteString];
	NSRange URLParamsRange = [URLString rangeOfString:@"?"];
	// if there are any URL params, parse and hold on to them
	if (URLParamsRange.location != NSNotFound) {
		if (![URLString hasSuffix:@"?"]) {
			NSString *keyValueParams = [URLString substringFromIndex:URLParamsRange.location + 1];
			NSArray *keyValuePairs = [keyValueParams componentsSeparatedByString:@"&"];
			for (NSString *keyValuePair in keyValuePairs) {
				NSArray *pair = [keyValuePair componentsSeparatedByString:@"="];
				// don't assume we actually got a real key=value pair. start by assuming we only got @[key] before checking count
				NSString *paramValue = pair[0];
				if (pair.count == 2) {
					// we got two params, so we can now use the second param as the value
					paramValue = pair[1];
				}
				URLParameters[pair[0]] = paramValue;
			}
		}
		// strip the URL params out
		URLString = [URLString substringToIndex:URLParamsRange.location];
	}
	
	// break the URL down into path components
	URLString = [URLString substringFromIndex:[[URL scheme] length] + 2]; // scheme + ':/'
	NSArray *URLComponents = [URLString pathComponents];
	
	for (_JLRoute *route in routes) {
		NSDictionary *matchParameters = [route parametersForURL:URL components:URLComponents];
		if (matchParameters) {
			// add the URL parameters
			NSMutableDictionary *mutableParameters = matchParameters[kJLRouteParametersKey]; // this is mutable because we created it as mutable in _JLRoute
			[mutableParameters addEntriesFromDictionary:URLParameters];
			didRoute = route.block(matchParameters);
			if (didRoute) {
				break;
			}
		}
	}
	
	return didRoute;
}


@end
