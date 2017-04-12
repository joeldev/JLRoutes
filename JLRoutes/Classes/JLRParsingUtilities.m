/*
 Copyright (c) 2017, Joel Levin
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of JLRoutes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "JLRParsingUtilities.h"


@interface NSArray (Combinations)

- (NSArray<NSArray *> *)JLRoutes_allOrderedCombinations;

@end


@implementation JLRParsingUtilities

+ (NSString *)variableValueFrom:(NSString *)value decodePlusSymbols:(BOOL)decodePlusSymbols
{
    if (!decodePlusSymbols) {
        return value;
    }
    return [value stringByReplacingOccurrencesOfString:@"+" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, value.length)];
}

+ (NSDictionary *)queryParams:(NSDictionary *)queryParams decodePlusSymbols:(BOOL)decodePlusSymbols
{
    if (!decodePlusSymbols) {
        return queryParams;
    }
    
    NSMutableDictionary *updatedQueryParams = [NSMutableDictionary dictionary];
    
    for (NSString *name in queryParams) {
        id value = queryParams[name];
        
        if ([value isKindOfClass:[NSArray class]]) {
            NSMutableArray *variables = [NSMutableArray array];
            for (NSString *arrayValue in (NSArray *)value) {
                [variables addObject:[self variableValueFrom:arrayValue decodePlusSymbols:YES]];
            }
            updatedQueryParams[name] = [variables copy];
        } else if ([value isKindOfClass:[NSString class]]) {
            NSString *variable = [self variableValueFrom:value decodePlusSymbols:YES];
            updatedQueryParams[name] = variable;
        } else {
            NSAssert(NO, @"Unexpected query parameter type: %@", NSStringFromClass([value class]));
        }
    }
    
    return [updatedQueryParams copy];
}

+ (NSArray <NSString *> *)expandOptionalRoutePatternsForPattern:(NSString *)routePattern
{
    /* this method exists to take a route pattern that is known to contain optional params, such as:
     
     /path/:thing/(/a)(/b)(/c)
     
     and create the following paths:
     
     /path/:thing/a/b/c
     /path/:thing/a/b
     /path/:thing/a/c
     /path/:thing/b/a
     /path/:thing/a
     /path/:thing/b
     /path/:thing/c
     */
    
    if ([routePattern rangeOfString:@"("].location == NSNotFound) {
        return @[];
    }
    
    NSString *baseRoute = nil;
    NSArray *components = [self _optionalComponentsForPattern:routePattern baseRoute:&baseRoute];
    NSArray *routes = [self _routesForOptionalComponents:components baseRoute:baseRoute];
    
    return routes;
}

+ (NSArray <NSString *> *)_optionalComponentsForPattern:(NSString *)routePattern baseRoute:(NSString *__autoreleasing *)outBaseRoute;
{
    if (routePattern.length == 0) {
        return @[];
    }
    
    NSMutableArray *optionalComponents = [NSMutableArray array];
    
    NSScanner *scanner = [NSScanner scannerWithString:routePattern];
    NSString *nonOptionalRouteSubpath = nil;
    
    BOOL parsedBaseRoute = NO;
    BOOL parseError = NO;
    
    // first, we need to parse the string and find the array of optional params.
    // aka, take (/a)(/b)(/c) and turn it into ["/a", "/b", "/c"]
    while ([scanner scanUpToString:@"(" intoString:&nonOptionalRouteSubpath]) {
        if ([scanner isAtEnd]) {
            break;
        }
        
        if (nonOptionalRouteSubpath.length > 0 && outBaseRoute != NULL && !parsedBaseRoute) {
            // the first 'non optional subpath' is always the base route
            *outBaseRoute = nonOptionalRouteSubpath;
            parsedBaseRoute = YES;
        }
        
        scanner.scanLocation = scanner.scanLocation + 1;
        
        NSString *component = nil;
        if (![scanner scanUpToString:@")" intoString:&component]) {
            parseError = YES;
            break;
        }
        
        [optionalComponents addObject:component];
    }
    
    if (parseError) {
        NSLog(@"[JLRoutes]: Parse error, unsupported route: %@", routePattern);
        return @[];
    }
    
    return [optionalComponents copy];
}

+ (NSArray <NSString *> *)_routesForOptionalComponents:(NSArray <NSString *> *)optionalComponents baseRoute:(NSString *)baseRoute
{
    if (optionalComponents.count == 0 || baseRoute.length == 0) {
        return @[];
    }
    
    NSMutableArray *routes = [NSMutableArray array];
    
    // generate all possible combinations of the components that could exist (taking order into account)
    // aka, "/path/:thing/(/a)(/b)(/c)" should never generate a route for "/path/:thing/(/b)(/a)"
    NSArray *combinations = [optionalComponents JLRoutes_allOrderedCombinations];
    
    // generate the actual final route path strings
    for (NSArray *components in combinations) {
        NSString *path = [components componentsJoinedByString:@""];
        [routes addObject:[baseRoute stringByAppendingString:path]];
    }
    
    // sort them so that the longest routes are first (since they are the most selective)
    [routes sortUsingSelector:@selector(length)];
    
    return [routes copy];
}

@end


@implementation NSArray (JLRoutes)

- (NSArray<NSArray *> *)JLRoutes_allOrderedCombinations
{
    NSInteger length = self.count;
    if (length == 0) {
        return [NSArray arrayWithObject:[NSArray array]];
    }
    
    id lastObject = [self lastObject];
    NSArray *subarray = [self subarrayWithRange:NSMakeRange(0, length - 1)];
    NSArray *subarrayCombinations = [subarray JLRoutes_allOrderedCombinations];
    NSMutableArray *combinations = [NSMutableArray arrayWithArray:subarrayCombinations];
    
    for (NSArray *subarrayCombos in subarrayCombinations) {
        [combinations addObject:[subarrayCombos arrayByAddingObject:lastObject]];
    }
    
    return [NSArray arrayWithArray:combinations];
}

@end
