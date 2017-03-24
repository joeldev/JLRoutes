/*
 Copyright (c) 2017, Joel Levin
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of JLRoutes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "JLRRouteDefinition.h"
#import "JLRoutes.h"


@interface JLRRouteDefinition ()

@property (nonatomic, strong) NSString *pattern;
@property (nonatomic, strong) NSString *scheme;
@property (nonatomic, assign) NSUInteger priority;
@property (nonatomic, strong) BOOL (^handlerBlock)(NSDictionary *parameters);

@property (nonatomic, strong) NSArray *patternComponents;

@end


@implementation JLRRouteDefinition

- (instancetype)initWithScheme:(NSString *)scheme pattern:(NSString *)pattern priority:(NSUInteger)priority handlerBlock:(BOOL (^)(NSDictionary *parameters))handlerBlock
{
    if ((self = [super init])) {
        self.scheme = scheme;
        self.pattern = pattern;
        self.priority = priority;
        self.handlerBlock = handlerBlock;
        
        if ([pattern characterAtIndex:0] == '/') {
            pattern = [pattern substringFromIndex:1];
        }
        
        self.patternComponents = [pattern componentsSeparatedByString:@"/"];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> - %@ (priority: %@)", NSStringFromClass([self class]), self, self.pattern, @(self.priority)];
}

- (JLRRouteResponse *)routeResponseForRequest:(JLRRouteRequest *)request decodePlusSymbols:(BOOL)decodePlusSymbols
{
    BOOL patternContainsWildcard = [self.patternComponents containsObject:@"*"];
    
    if (request.pathComponents.count != self.patternComponents.count && !patternContainsWildcard) {
        // definitely not a match, nothing left to do
        return [JLRRouteResponse invalidMatchResponse];
    }
    
    JLRRouteResponse *response = [JLRRouteResponse invalidMatchResponse];
    NSMutableDictionary *routeParams = [NSMutableDictionary dictionary];
    BOOL isMatch = YES;
    NSUInteger index = 0;
    
    for (NSString *patternComponent in self.patternComponents) {
        NSString *URLComponent = nil;
        
        // figure out which URLComponent it is, taking wildcards into account
        if (index < [request.pathComponents count]) {
            URLComponent = request.pathComponents[index];
        } else if ([patternComponent isEqualToString:@"*"]) {
            // match /foo by /foo/*
            URLComponent = [request.pathComponents lastObject];
        }
        
        if ([patternComponent hasPrefix:@":"]) {
            // this is a variable, set it in the params
            NSString *variableName = [self variableNameForValue:patternComponent];
            NSString *variableValue = [self variableValueForValue:URLComponent decodePlusSymbols:decodePlusSymbols];
            routeParams[variableName] = variableValue;
        } else if ([patternComponent isEqualToString:@"*"]) {
            // match wildcards
            NSUInteger minRequiredParams = index;
            if (request.pathComponents.count >= minRequiredParams) {
                // match: /a/b/c/* has to be matched by at least /a/b/c
                routeParams[JLRouteWildcardComponentsKey] = [request.pathComponents subarrayWithRange:NSMakeRange(index, request.pathComponents.count - index)];
                isMatch = YES;
            } else {
                // not a match: /a/b/c/* cannot be matched by URL /a/b/
                isMatch = NO;
            }
            break;
        } else if (![patternComponent isEqualToString:URLComponent]) {
            // break if this is a static component and it isn't a match
            isMatch = NO;
            break;
        }
        index++;
    }
    
    if (isMatch) {
        // if it's a match, set up the param dictionary and create a valid match response
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params addEntriesFromDictionary:[request queryParamsDecodingPlusSymbols:decodePlusSymbols]];
        [params addEntriesFromDictionary:routeParams];
        [params addEntriesFromDictionary:[self baseMatchParametersForRequest:request]];
        response = [JLRRouteResponse validMatchResponseWithParameters:[params copy]];
    }
    
    return response;
}

- (NSString *)variableNameForValue:(NSString *)value
{
    NSString *name = [value substringFromIndex:1];
    
    if (name.length > 1 && [name characterAtIndex:0] == ':') {
        name = [name substringFromIndex:1];
    }
    
    if (name.length > 1 && [name characterAtIndex:name.length - 1] == '#') {
        name = [name substringToIndex:name.length - 1];
    }
    
    return name;
}

- (NSString *)variableValueForValue:(NSString *)value decodePlusSymbols:(BOOL)decodePlusSymbols
{
    NSString *var = [value stringByRemovingPercentEncoding];
    
    if (var.length > 1 && [var characterAtIndex:var.length - 1] == '#') {
        var = [var substringToIndex:var.length - 1];
    }
    
    var = [JLRRouteRequest variableValueFrom:var decodePlusSymbols:decodePlusSymbols];
    
    return var;
}

- (NSDictionary *)baseMatchParametersForRequest:(JLRRouteRequest *)request
{
    return @{JLRoutePatternKey: self.pattern ?: [NSNull null], JLRouteURLKey: request.URL ?: [NSNull null], JLRouteSchemeKey: self.scheme ?: [NSNull null]};
}

- (BOOL)callHandlerBlockWithParameters:(NSDictionary *)parameters
{
    if (self.handlerBlock == nil) {
        return YES;
    }
    
    return self.handlerBlock(parameters);
}

@end
