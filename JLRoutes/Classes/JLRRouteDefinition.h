/*
 Copyright (c) 2017, Joel Levin
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 Neither the name of JLRoutes nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import "JLRRouteRequest.h"
#import "JLRRouteResponse.h"

NS_ASSUME_NONNULL_BEGIN


/**
 JLRRouteDefinition is a model object representing a registered route, including the URL scheme, route pattern, and priority.
 
 This class can be subclassed to customize route parsing behavior by overriding -routeResponseForRequest:decodePlusSymbols:.
 -callHandlerBlockWithParameters can also be overriden to customize the parameters passed to the handlerBlock.
 */

@interface JLRRouteDefinition : NSObject

/// The URL scheme for which this route applies, or JLRoutesGlobalRoutesScheme if global.
@property (nonatomic, copy, readonly) NSString *scheme;

/// The route pattern.
@property (nonatomic, copy, readonly) NSString *pattern;

/// The priority of this route pattern.
@property (nonatomic, assign, readonly) NSUInteger priority;

/// The handler block to invoke when a match is found.
@property (nonatomic, copy, readonly) BOOL (^handlerBlock)(NSDictionary *parameters);


///---------------------------------
/// @name Creating Route Definitions
///---------------------------------


/**
 Creates a new route definition. The created definition can be directly added to an instance of JLRoutes.
 
 This is the designated initializer.
 
 @param scheme The URL scheme this route applies for, or JLRoutesGlobalRoutesScheme if global.
 @param pattern The full route pattern ('/foo/:bar')
 @param priority The route priority, or 0 if default.
 @param handlerBlock The handler block to call when a successful match is found.
 
 @returns The newly initialized route definition.
 */
- (instancetype)initWithScheme:(NSString *)scheme pattern:(NSString *)pattern priority:(NSUInteger)priority handlerBlock:(BOOL (^)(NSDictionary *parameters))handlerBlock NS_DESIGNATED_INITIALIZER;

/// Unavailable, use initWithScheme:pattern:priority:handlerBlock: instead.
- (instancetype)init NS_UNAVAILABLE;

/// Unavailable, use initWithScheme:pattern:priority:handlerBlock: instead.
+ (instancetype)new NS_UNAVAILABLE;


///-------------------------------
/// @name Matching Route Requests
///-------------------------------


/**
 Creates and returns a JLRRouteResponse for the provided JLRRouteRequest. The response specifies if there was a match or not.
 
 @param request The JLRRouteRequest to create a response for.
 @param decodePlusSymbols The global plus symbol decoding option value.
 
 @returns An JLRRouteResponse instance representing the result of attempting to match request to thie route definition.
 */
- (JLRRouteResponse *)routeResponseForRequest:(JLRRouteRequest *)request decodePlusSymbols:(BOOL)decodePlusSymbols;


/**
 Invoke handlerBlock with the given parameters. This may be overriden by subclasses.
 
 @param parameters The parameters to pass to handlerBlock.
 
 @returns The value returned by calling handlerBlock (YES if it is considered handled and NO if not).
 */
- (BOOL)callHandlerBlockWithParameters:(NSDictionary *)parameters;

@end


NS_ASSUME_NONNULL_END
