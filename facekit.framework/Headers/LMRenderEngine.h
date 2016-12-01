//
//  LMRenderEngine.h
//  facekit
//
//  Created by xin li on 7/21/16.
//  Copyright © 2016 faceu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <AVFoundation/AVFoundation.h>
#import "LMRenderEngineNotifications.h"

typedef int LMFilterPos;

@interface LMRenderEngine : NSObject

@property (nonatomic, assign) BOOL useExternalFaceDetect;

+ (LMRenderEngine*)engineForSamplebufferWithRenderQueue:(dispatch_queue_t)queue resBundle:(NSBundle*)resBundle;
+ (LMRenderEngine*)engineForTextureWithGLContext:(EAGLContext*)context queue:(dispatch_queue_t)queue;
+ (LMRenderEngine*)engineForTextureWithGLContext:(EAGLContext*)context queue:(dispatch_queue_t)queue faceless:(BOOL)faceless;
+ (LMRenderEngine*)engineForFacelessWithGLContext:(EAGLContext*)context queue:(dispatch_queue_t)queue;


#pragma mark - Input processors
// All of process are syncrhonise method
- (CMSampleBufferRef)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (CVPixelBufferRef)processPixelBuffer:(CVPixelBufferRef)pixelBuffer;
// Call process texture on the rendering thread. RenderEngine manage outputTexId resource.
// After get the processed outputTexId you can draw to the framebuffer for free.
// The outputTexId will be validate before the next call of processTexture.
- (void)processTexture:(GLuint)texId size:(CGSize)width outputTexture:(GLuint*)outputTexId;

// faceDetectPoints should be 106 points. NOT READY
- (void)processTexture:(GLuint)texId size:(CGSize)width outputTexture:(GLuint *)outputTexId faces:(lm_ext_faces*)faces;

#pragma mark - API for liberty
- (LMFilterPos)applyWithPath:(NSString*)path;
- (LMFilterPos)applyWithPath:(NSString*)path positionOffset:(int)positionOffset;
- (LMFilterPos)applyWithPathes:(NSArray<NSString*>*)pathes positionOffset:(int)positionOffset;
- (void)stopFilter:(LMFilterPos)pos;
- (void)switchSmallMode:(LMSmallMode)smallMode;

#pragma mark - Face Detect
- (void)enableFaceDetect:(BOOL)enable;

//- (UIView*)previewView;

@end
