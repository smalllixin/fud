//
//  LMGLContext.m
//  sdktexlab
//
//  Created by xin li on 7/28/16.
//  Copyright © 2016 faceu. All rights reserved.
//

#import "LMGLContext.h"

@implementation LMGLContext {
    EAGLContext *_context;
    dispatch_queue_t _process_queue;
}

- (id)init {
    if (self = [self initWithShareGroup:nil]) {
    }
    return self;
}

- (id)initWithShareGroup:(EAGLSharegroup*)shareGroup {
    if (self = [super init]) {
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:shareGroup];
        if (!_context) {
            NSLog(@"Failed to initialize OpenGLES 2.0 context");
        }
//        _context.multiThreaded = YES;
        //_process_queue = dispatch_queue_create("lmglcontext.queue", DISPATCH_QUEUE_SERIAL);
        _process_queue = dispatch_queue_create("lmglcontext.queue", DISPATCH_QUEUE_SERIAL);
        [self setCurrentContext];
    }
    return self;
}

- (void)setCurrentContext {
    if ([EAGLContext currentContext] != _context) {
        if (![EAGLContext setCurrentContext:_context]) {
            NSLog(@"Failed to set current Opengl context");
        }
    }
}

- (EAGLContext*)c {
    return _context;
}

- (EAGLSharegroup*)shareGroup {
    return _context.sharegroup;
}

- (void)syncRunOnQueue:(void (^)())block {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == _process_queue) {
#pragma clang diagnostic pop
        block();
    } else {
        dispatch_sync(_process_queue, block);
    }
}

- (void)asyncRunOnQueue:(void (^)())block {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (dispatch_get_current_queue() == _process_queue) {
#pragma clang diagnostic pop
        block();
    } else {
        dispatch_async(_process_queue, block);
    }
}

- (dispatch_queue_t)contextQueue {
    return _process_queue;
}

@end
