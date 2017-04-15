//
//  JLRRouteHandler.m
//  JLRoutes
//
//  Created by Joel Levin on 4/14/17.
//  Copyright © 2017 Afterwork Studios. All rights reserved.
//

#import "JLRRouteHandler.h"


@implementation JLRRouteHandler

+ (BOOL (^)(NSDictionary<NSString *, id> *parameters))handlerBlockForWeakTarget:(__weak id <JLRRouteHandlerTarget>)weakTarget
{
    return ^BOOL(NSDictionary<NSString *, id> *parameters) {
        return [weakTarget handleRouteWithParameters:parameters];
    };
}

+ (BOOL (^)(NSDictionary<NSString *, id> *parameters))handlerBlockForTargetClass:(Class)targetClass completion:(void (^)(id <JLRRouteHandlerTarget> createdObject))completionHandler
{
    NSParameterAssert([targetClass conformsToProtocol:@protocol(JLRRouteHandlerTarget)]);
    
    return ^BOOL(NSDictionary<NSString *, id> *parameters) {
        id <JLRRouteHandlerTarget> createdObject = [[targetClass alloc] init];
        BOOL didHandle = [createdObject handleRouteWithParameters:parameters];
        
        completionHandler(createdObject); // declared nonnull, as we want to force external ownership of createdObject.
        
        return didHandle;
    };
}

@end
