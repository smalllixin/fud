//
//  LMGLContext.h
//  sdktexlab
//
//  Created by xin li on 7/28/16.
//  Copyright © 2016 faceu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>

@interface LMGLContext : NSObject

@property (nonatomic, readonly) EAGLContext *c;
@property (nonatomic, readonly) EAGLSharegroup *shareGroup;

- (id)initWithShareGroup:(EAGLSharegroup*)shareGroup;

- (void)setCurrentContext;
- (void)syncRunOnQueue:(void (^)())block;
- (void)asyncRunOnQueue:(void (^)())block;
- (dispatch_queue_t)contextQueue;
@end
