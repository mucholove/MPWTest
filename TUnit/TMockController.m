//
//  TMockController.m
//  MPWTest
//
//  Created by Marcel Weiher on 4/10/11.
//  Copyright 2011 metaobject ltd. All rights reserved.
//

#import "TMockController.h"
#import "TMockRecorder.h"
#import "TMessageExpectation.h"
#import "AccessorMacros.h"
#import "MPWClassMirror.h"
#import "MPWMethodMirror.h"

#pragma .h #import <Foundation/Foundation.h>
#pragma .h @class TMessageExpectation;

@implementation TMockController : NSObject
{
	id originalObject;
	NSMutableArray* expectations;
	id mock;
	int recordNumberOfMessages;
	id  copyOfOriginalObject;
	int nextExpectedCount;
	BOOL partialMockAllowed;
	int  size;
	MPWClassMirror *originalClass,*mockingSubclass;
	MPWObjectMirror *objectMirror;
	NSMutableDictionary *mockedMessagesForClass;
}



static NSMapTable* mockControllers=nil;



boolAccessor( partialMockAllowed, setPartialMockAllowed )
objectAccessor( MPWClassMirror, originalClass, setOriginalClass )
objectAccessor( MPWClassMirror, mockingSubclass, setMockingSubclass )
objectAccessor( MPWObjectMirror, objectMirror, setObjectMirror  )
objectAccessor( NSMutableDictionary, mockedMessagesForClass, setMockedMessagesForClass  )

+(NSMapTable*)mockControllers
{
	if  (!mockControllers ) {
		mockControllers=[[NSMapTable mapTableWithStrongToStrongObjects] retain];
	}
	return mockControllers;
}

+(void)removeMocks
{
	[mockControllers release];
	mockControllers=nil;
}

+(void)addController:aController forObject:anObject
{
	[[self mockControllers] setObject:aController forKey:anObject];
}

+fetchControllerForObject:anObject
{
	return [[self mockControllers] objectForKey:anObject];
}

+mockControllerForObject:anObject
{
	TMockController* controller=[self fetchControllerForObject:anObject];
	if ( !controller ) {
//		NSLog(@"create controller for: %p",anObject);
		controller=[[[self alloc] initWithObject:anObject] autorelease];
		[self addController:controller forObject:anObject];
	}
//	NSLog(@"controller for object %p is %p",anObject,controller);
	return controller;
	
}

-initWithObject:anObject
{
	self=[super init];
	if ( self ) {
		originalObject=[anObject retain];
		expectations=[[NSMutableArray alloc] init];
		[self setMockedMessagesForClass:[NSMutableDictionary dictionary]];
		[self record];
	}
	return self;
}

- (void)record
{
    recordNumberOfMessages=100000;

}



+mockController
{
	return [[[self alloc] initWithObject:nil] autorelease];
}

-(void)mapMock
{
	[[self class] addController:self forObject:mock];
}

-mockForObject:anObject
{
	originalObject=[anObject retain];
	mock=NSAllocateObject(NSClassFromString(@"TMockRecorder"), 0, NSDefaultMallocZone());
	[mock initWithController:self];
	recordNumberOfMessages=100000;
	[self setExpectedCount:1];
	[self mapMock];
	return mock;
}

-mockForClass:(Class)aClass
{
	return [self mockForObject:[[[aClass alloc] init] autorelease]];
}


-inlineMock
{
	if ( !mock ) {
#if 1
		[self setOriginalClass:[MPWClassMirror mirrorWithClass:[originalObject class]]];
		[self setObjectMirror:[MPWObjectMirror mirrorWithObject:originalObject]];
		
		[self setMockingSubclass: [[self originalClass] createAnonymousSubclass]];
		[[self objectMirror] setObjectClass:[[self mockingSubclass] theClass]];
		mock=NSAllocateObject(NSClassFromString(@"TMockRecorder"), 0, NSDefaultMallocZone());
#else
		
		size =  class_getInstanceSize( [originalObject class] );
		copyOfOriginalObject=malloc( size );
		memcpy( copyOfOriginalObject, originalObject, size );
		mock=originalObject;
		memset( mock,0, size );
#endif		
		[mock initWithController:self];
		[self mapMock];
	}
	return mock;
}

#if 0
-inlineMockClass
{
	if ( !mock ) {
		size =  class_getInstanceSize( object_getClass(originalObject) );
		NSLog(@"size for inlineMockClass: %d",size);
		copyOfOriginalObject=malloc( size );
		memcpy( copyOfOriginalObject, originalObject, size );
		mock=originalObject;
		memset( mock,0, size );
		memcpy( mock, NSClassFromString(@"TMockRecorder"), size );
//		[mock initWithController:self];
	}
	return mock;
}
#else
-inlineMockClass
{
	return originalObject;
}
#endif

-mockForMetaClassOfClass:(Class)aClass
{
	originalObject = aClass;
	mock=NSAllocateObject(NSClassFromString(@"TMockRecorder"), 0, NSDefaultMallocZone());
	recordNumberOfMessages=100000;
	[mock initWithController:self];
	[self setExpectedCount:1];
	[self mapMock];
	return mock;
}

-(void)setExpectedCount:(int)newCount
{
	nextExpectedCount=newCount;
}

-(TMessageExpectation*)currentExpectation
{
	return [expectations lastObject];
}

-(void)setCurrentExpectedCount:(int)newCount
{
	[[self currentExpectation] setExpectedCount:newCount];
}

-skipParameterChecks
{
	[[self currentExpectation] skipParameterChecks];
	return self;
}


-skipParameterCheck:(int)parameterToIgnore
{
	[[self currentExpectation] skipParameterCheck:parameterToIgnore];
	return self;
}

-ordered
{
	[[self currentExpectation] ordered];
	return self;
}




-(void)replay
{
	recordNumberOfMessages=0;
}

static id forward( id self, SEL selector, NSInvocation *invocation ) {
	[[TMockController fetchControllerForObject:self] handleMockedInvocation:invocation];
}

-(NSMethodSignature*)methodSignatureForMockedSelector:(SEL)sel
{
//	NSLog(@"methodSignatureForMockedSelector: %@",NSStringFromSelector(sel));
//	NSLog(@"originalObject: %@",originalObject);
	return [copyOfOriginalObject ? copyOfOriginalObject : originalObject methodSignatureForSelector:sel];
}


extern id _objc_msgForward(id receiver, SEL sel, ...);

-(void)addMockedMessage:(SEL)selector
{
	NSString *messageName = NSStringFromSelector(selector);
	id alreadyMocked = [[self mockedMessagesForClass] objectForKey:messageName];
	if ( !alreadyMocked ) {
		MPWMethodMirror *method=[[self mockingSubclass] methodMirrorForSelector:selector];
		[[self mockedMessagesForClass] setObject:method forKey:messageName];
		[[self mockingSubclass] replaceMethod:_objc_msgForward  forSelector:selector typeString:[method typestring]];

	}
}

-(void)recordInvocation:(NSInvocation *)invocation
{
//	NSLog(@"recordInvocation %@",invocation);
	[expectations addObject:[TMessageExpectation expectationWithInvocation: invocation]];
	[self setCurrentExpectedCount:nextExpectedCount];
	[self addMockedMessage:[invocation selector]];
}

-(BOOL)matchesInvocation:(NSInvocation*)invocation
{
	for ( int i = [expectations count]-1 ; i >= 0 ; i-- ) {
		TMessageExpectation *expectation = [expectations objectAtIndex:i];
//		NSLog(@"checking expectations[%d]=%@ against %@",i,expectation,invocation);
		if ( [expectation matchesInvocation:invocation] ) {
//			NSLog(@"did match at %d",i);
			if ( [expectation exceptionToThrow] ) {
				@throw [expectation exceptionToThrow];
			}
			if ( [expectation isOrdered] ) {
				for (int j=0;j<i;j++) {
					TMessageExpectation  *orderCheck=[expectations objectAtIndex:j];
					if ( [orderCheck isOrdered] && [orderCheck unfulfilled] ) {
						if ( [orderCheck matchesInvocation:invocation] ){
							expectation=orderCheck;
							break;
						} else {
							return NO;
						}
					}
				}
			}
			char buf[128];
			if  ( *[[invocation methodSignature] methodReturnType] != 'v' ) {
				[expectation getReturnValue:buf];
				[invocation setReturnValue:buf];
			}
			[expectation increateActualMatch];
			return YES;
		}
	}
//	NSLog(@"no match!");
	return NO;
}

-(void)setExceptionResult:obj
{
	[[self currentExpectation] setExceptionToThrow:obj];
}

-(void)checkAndRunInvocation:(NSInvocation *)invocation
{
//	NSLog(@"checkAndRunInvocation %@",invocation);
//	[invocation setReturnValue:&empty];
	if (! [self matchesInvocation:invocation]) {
		if ( [self partialMockAllowed] ) {
			[invocation invokeWithTarget:copyOfOriginalObject];
		} else {
			[NSException raise:@"mock" format:@"mock doesn't match: %@ %@",NSStringFromSelector([invocation selector]),expectations];
		}
	}
}

-(void)recordOneMessage
{
	recordNumberOfMessages=1;
}

-(BOOL)shouldRecordMessage
{
	return recordNumberOfMessages>0 ;
}

-(void)handleMockedInvocation:(NSInvocation *)invocation
{
//	NSLog(@"handleMockedInvocation %@",invocation);
	if ( [self shouldRecordMessage] ) {
//		NSLog(@"recording %@",NSStringFromSelector([invocation selector]));
		recordNumberOfMessages--;
		[self recordInvocation:invocation];
#if 1		
		if  ( *[[invocation methodSignature] methodReturnType] != 'v' ) {
//			[[expectations objectAtIndex:0] getReturnValue:buf];
			[invocation setReturnValue:&mock];
		}
#endif		
	} else {
//		NSLog(@"replay / check %@",NSStringFromSelector([invocation selector]));
		[self checkAndRunInvocation:invocation];
	}
	
}

#define setSomeResult( type, methodName ) \
/**/   -(void)methodName:(type)aResult {\
	[(NSInvocation*)[self currentExpectation] setReturnValue:&aResult];\
}\

setSomeResult( void*, setResult )
setSomeResult( double, setDoubleResult )
setSomeResult( float, setFloatResult )
setSomeResult( long long, setLongLongResult )
setSomeResult( int, setIntResult )
setSomeResult( short, setShortResult )
setSomeResult( char, setCharResult )


-(void)expect:(id)dummy withIntResult:(int)result
{
	[self setIntResult:result];
}

-(void)expect:(id)dummy withResult:(id)result
{
	[self setResult:result];
}

-(void)verify
{
	for ( TMessageExpectation *expectation in expectations ) {
//		NSLog(@"verify expectation: %@",expectation);
		if ( [expectation unfulfilled] ) {
			[NSException raise:@"mock"  format:@"remaining expected messages: %@",expectations];
		}
	}
}

-(void)verifyMocks
{
	[self verify];
}

-(void)cleanup
{
	if ( copyOfOriginalObject  && size) {
		memcpy( originalObject, copyOfOriginalObject, size );
	}
}

void verifyAndCleanupMocks() 
{
	@try {
		for ( TMockController* controller in [[TMockController mockControllers] objectEnumerator]  ) {
	//		NSLog(@"verify controller: %@",controller);
			[controller cleanup];
			[controller verify];
		}
	} @finally {
		[TMockController removeMocks];
	}
}


-(NSArray*)recorded {
	return expectations;
}

-(void)dealloc
{
//	NSDeallocateObject(mock);
	[originalObject release];
	[expectations release];
	[super dealloc];
}



@end
