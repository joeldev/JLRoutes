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

NS_ASSUME_NONNULL_BEGIN


extern NSString *const JLRoutePatternKey;
extern NSString *const JLRouteURLKey;
extern NSString *const JLRouteSchemeKey;
extern NSString *const JLRouteWildcardComponentsKey;
extern NSString *const JLRoutesGlobalRoutesScheme;


@interface JLRoutes : NSObject

/// Controls whether or not this router will try to match a URL with global routes if it can't be matched in the current namespace. Default is NO.
@property (nonatomic, assign) BOOL shouldFallbackToGlobalRoutes;

/// Called any time routeURL returns NO. Respects shouldFallbackToGlobalRoutes.
@property (nonatomic, copy) void (^__nullable unmatchedURLHandler)(JLRoutes *routes, NSURL *__nullable URL, NSDictionary<NSString *, id> *__nullable parameters);


#pragma mark - Routing Schemes

/// Returns the global routing scheme (this is used by the +addRoute methods by default)
+ (instancetype)globalRoutes;

/// Returns a routing namespace for the given scheme
+ (instancetype)routesForScheme:(NSString *)scheme;

/// Unregister and delete an entire scheme namespace
+ (void)unregisterRouteScheme:(NSString *)scheme;

/// Unregister all routes
+ (void)unregisterAllRouteSchemes;


#pragma mark - Registering Routes

/// Registers a routePattern with default priority (0) in the receiving scheme namespace.
- (void)addRoute:(NSString *)routePattern handler:(BOOL (^__nullable)(NSDictionary<NSString *, id> *parameters))handlerBlock;

/// Registers a routePattern in the global scheme namespace with a handlerBlock to call when the route pattern is matched by a URL.
/// The block returns a BOOL representing if the handlerBlock actually handled the route or not. If
/// a block returns NO, JLRoutes will continue trying to find a matching route.
- (void)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^__nullable)(NSDictionary<NSString *, id> *parameters))handlerBlock;

/// Registers multiple routePatterns for one handler with default priority (0) in the receiving scheme namespace.
- (void)addRoutes:(NSArray<NSString *> *)routePatterns handler:(BOOL (^__nullable)(NSDictionary<NSString *, id> *parameters))handlerBlock;

/// Removes a routePattern from the receiving scheme namespace.
- (void)removeRoute:(NSString *)routePattern;

/// Removes all routes from the receiving scheme namespace.
- (void)removeAllRoutes;

/// Registers a routePattern with default priority (0) using dictionary-style subscripting.
- (void)setObject:(nullable id)handlerBlock forKeyedSubscript:(NSString *)routePatten;


#pragma mark - Routing URLs

/// Returns whether a route will match a given URL in any routes scheme, but does not call any blocks.
+ (BOOL)canRouteURL:(nullable NSURL *)URL;

/// Returns whether a route will match a given URL in a specific scheme, but does not call any blocks.
- (BOOL)canRouteURL:(nullable NSURL *)URL;

/// Routes a URL in any routes scheme, calling handler blocks for patterns that match the URL until one returns YES.
/// If no matching route is found, the unmatchedURLHandler will be called (if set).
+ (BOOL)routeURL:(nullable NSURL *)URL;

/// Routes a URL in a specific scheme, calling handler blocks for patterns that match the URL until one returns YES.
/// If no matching route is found, the unmatchedURLHandler will be called (if set).
- (BOOL)routeURL:(nullable NSURL *)URL;

/// Routes a URL in any routes scheme, calling handler blocks (for patterns that match URL) until one returns YES.
/// Additional parameters get passed through to the matched route block.
+ (BOOL)routeURL:(nullable NSURL *)URL withParameters:(nullable NSDictionary<NSString *, id> *)parameters;

/// Routes a URL in a specific scheme, calling handler blocks (for patterns that match URL) until one returns YES.
/// Additional parameters get passed through to the matched route block.
- (BOOL)routeURL:(nullable NSURL *)URL withParameters:(nullable NSDictionary<NSString *, id> *)parameters;

@end


#pragma mark - Global Options

@interface JLRoutes (GlobalOptions)

/// Enable or disable verbose logging. Defaults to NO.
+ (void)setVerboseLoggingEnabled:(BOOL)loggingEnabled;

/// Returns current verbose logging enabled state.
+ (BOOL)isVerboseLoggingEnabled;

/// Tells JLRoutes that it should manually replace '+' in parsed values to ' '. Defaults to YES.
+ (void)setShouldDecodePlusSymbols:(BOOL)shouldDecode;

/// Returns current plus symbol decoding state.
+ (BOOL)shouldDecodePlusSymbols;

@end


#pragma mark - Deprecated

extern NSString *const kJLRoutePatternKey               DEPRECATED_MSG_ATTRIBUTE("Use JLRoutePatternKey instead.");
extern NSString *const kJLRouteURLKey                   DEPRECATED_MSG_ATTRIBUTE("Use JLRouteURLKey instead.");
extern NSString *const kJLRouteSchemeKey                DEPRECATED_MSG_ATTRIBUTE("Use JLRouteSchemeKey instead.");
extern NSString *const kJLRouteWildcardComponentsKey    DEPRECATED_MSG_ATTRIBUTE("Use JLRouteWildcardComponentsKey instead.");
extern NSString *const kJLRoutesGlobalRoutesScheme      DEPRECATED_MSG_ATTRIBUTE("Use JLRoutesGlobalRoutesScheme instead.");

extern NSString *const kJLRouteNamespaceKey             DEPRECATED_MSG_ATTRIBUTE("Use JLRouteSchemeKey instead.");
extern NSString *const kJLRoutesGlobalNamespaceKey      DEPRECATED_MSG_ATTRIBUTE("Use JLRoutesGlobalRoutesScheme instead.");

@interface JLRoutes (Deprecated)

// All the class method conveniences have been deprecated. They make the API/header confusing and are unncessary.
// If you're using these, please switch to calling the matching instance method on +globalRoutes instead for the same behavior.

+ (void)addRoute:(NSString *)routePattern handler:(BOOL (^__nullable)(NSDictionary<NSString *, id> *parameters))handlerBlock DEPRECATED_MSG_ATTRIBUTE("Use the matching instance method on +globalRoutes instead.");
+ (void)addRoute:(NSString *)routePattern priority:(NSUInteger)priority handler:(BOOL (^__nullable)(NSDictionary<NSString *, id> *parameters))handlerBlock DEPRECATED_MSG_ATTRIBUTE("Use the matching instance method on +globalRoutes instead.");
+ (void)addRoutes:(NSArray<NSString *> *)routePatterns handler:(BOOL (^__nullable)(NSDictionary<NSString *, id> *parameters))handlerBlock DEPRECATED_MSG_ATTRIBUTE("Use the matching instance method on +globalRoutes instead.");
+ (void)removeRoute:(NSString *)routePattern DEPRECATED_MSG_ATTRIBUTE("Use the matching instance method on +globalRoutes instead.");
+ (void)removeAllRoutes DEPRECATED_MSG_ATTRIBUTE("Use the matching instance method on +globalRoutes instead.");
+ (BOOL)canRouteURL:(nullable NSURL *)URL withParameters:(nullable NSDictionary<NSString *, id> *)parameters DEPRECATED_MSG_ATTRIBUTE("Use +canRouteURL: instead.");

// Other deprecations

- (BOOL)canRouteURL:(nullable NSURL *)URL withParameters:(nullable NSDictionary<NSString *, id> *)parameters DEPRECATED_MSG_ATTRIBUTE("Use -canRouteURL: instead.");

@end


NS_ASSUME_NONNULL_END
