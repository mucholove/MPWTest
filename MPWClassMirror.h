//
//  MPWClassMirror.h
//  MPWTest
//
//  Created by Marcel Weiher on 5/29/11.
//  Copyright 2011 Marcel Weiher. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MPWClassMirror : NSObject
{
	Class theClass;
}


+mirrorWithClass:(Class)aClass;
-(NSString*)name;
+(NSArray*)allUsefulClasses;
-(Class)theClass;
-(BOOL)isInBundle:(NSBundle*)aBundle;
-(MPWClassMirror*)createAnonymousSubclass;

@end


@interface MPWClassMirror(objc)

-(const char*)cStringClassName;
+(Class)superclassOfClass:(Class)aClass;
+(NSArray*)allClasses;
-(Class)_createClass:(const char*)name;
-(NSArray*)methodMirrors;

@end
