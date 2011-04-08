//
//  MPWTestAssertionHandler.m
//  MPWTest
//
//  Created by Marcel Weiher on 26/10/2004.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import "MPWTestAssertionHandler.h"

id MPWTestFailedException = @"MPWTestFailedException";

@implementation MPWTestAssertionHandler

-initWithTester:aTester
{
    self=[super init];
    tester=[aTester retain];
    return self;
}


+failureException
{
	return MPWTestFailedException;
}

+assertionHandlerWithTester:aTester
{
    return [[[self alloc] initWithTester:aTester] autorelease];
}


- (void) handleFailureInFunction: (NSString*)functionName 
                            file: (NSString*)fileName 
                      lineNumber: (NSInteger)line 
                     description: (NSString*)format,...
{
    id            message;
    va_list       ap;
    NSLog(@"failure in method");
    
    va_start(ap, format);
    message =
        [NSString
      stringWithFormat: @"%@:%d: error: Test failed in %@.  %@",
            fileName, line, functionName, format];
//    NSLogv(message, ap);
    
    [NSException raise: [[self class] failureException]
                format: message arguments: ap];
    va_end(ap);
    /* NOT REACHED */
}

- (void) handleFailureInMethod: (SEL) aSelector
                        object: object
                          file: (NSString *) fileName
                    lineNumber: (NSInteger) line
                   description: (NSString *) format,...
{
    id            message;
    va_list       ap;
    NSLog(@"failure in method");
    va_start(ap, format);
    message =
        [NSString
      stringWithFormat: @"%@:%d: error: Test failed in %@(%@), method %@.  %@",
            fileName, line, NSStringFromClass([object class]), 
      [object isInstance] ? @"instance" : @"class",
            NSStringFromSelector(aSelector), format];
//    NSLogv(message, ap);
#if WINDOWS	
    NSLog(@"failure: %@",format);
	NSLog(@"lineNumber: %d",line);

    [NSException raise: [[self class] failureException] 
                format: @"%@",message];
	
#else
    [NSException raise: [[self class] failureException] 
                format: message arguments: ap];
	
#endif
	
    va_end(ap);
    /* NOT REACHED */
}


@end


@implementation NSObject(isInstance)

+(BOOL)isInstance{
    return NO;
}

-(BOOL)isInstance
{
    return YES;
}

@end
