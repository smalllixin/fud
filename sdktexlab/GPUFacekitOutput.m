//
//  GPUFacekitOutput.m
//  sdktexlab
//
//  Created by xin li on 8/26/16.
//  Copyright © 2016 faceu. All rights reserved.
//

#import "GPUFacekitOutput.h"
#import <GPUImageContext.h>

@interface GPUFacekitOutput() {
    GPUImageRotationMode _outputRotation, _internalRotation;
    BOOL _frameRendering;
    BOOL _openGLInavailable;
}

@property (nonatomic, strong) LMRenderEngine *renderEngine;
@end

@implementation GPUFacekitOutput

- (id)initWithRenderEngine:(LMRenderEngine*)renderEngine {
    if (self = [super init]) {
        _renderEngine = renderEngine;
        _cameraPosition = AVCaptureDevicePositionFront;
        _outputRotation = kGPUImageNoRotation;
        _internalRotation = kGPUImageNoRotation;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}


#pragma mark - UIApplication Notifications
- (void)applicationWillResignActive {
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        glFinish();
    });
    _openGLInavailable = YES;
}

- (void)applicationWillBecomeActive {
    _openGLInavailable = NO;
}

#pragma mark - process samplebuffer
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_openGLInavailable || _frameRendering) {
        return;
    }
    _frameRendering = YES;
    CFRetain(sampleBuffer);
    runAsynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        
        CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        
        CVOpenGLESTextureRef videoTextureRef = NULL;
        GLuint _videoTexture;
        
        CVReturn err;
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[GPUImageContext sharedImageProcessingContext] coreVideoTextureCache], pixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, (int)width, (int)height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &videoTextureRef);
        _videoTexture = CVOpenGLESTextureGetName(videoTextureRef);
        glBindTexture(GL_TEXTURE_2D, _videoTexture);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        GLuint tex = _videoTexture;
        
        CGSize size = CGSizeMake(width,height);
        if (outputFramebuffer && CGSizeEqualToSize(size, outputFramebuffer.size)) {
            [outputFramebuffer overrideTexture:tex];
        } else {
            outputFramebuffer = [[GPUImageFramebuffer alloc] initWithSize:size overriddenTexture:tex];
            outputFramebuffer.preventReleaseTexture = YES;
        }
        for (id<GPUImageInput> currentTarget in targets) {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [currentTarget setInputRotation:_outputRotation atIndex:textureIndexOfTarget];
            [currentTarget setInputSize:CGSizeMake(width, height) atIndex:textureIndexOfTarget];
            
            [currentTarget setCurrentlyReceivingMonochromeInput:NO];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
        }
        //        outputFramebuffer = nil;
        
        // Finally, trigger rendering as needed
        for (id<GPUImageInput> currentTarget in targets)
        {
            if ([currentTarget enabled])
            {
                NSInteger indexOfObject = [targets indexOfObject:currentTarget];
                NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
                
                if (currentTarget != self.targetToIgnoreForUpdates)
                {
                    [currentTarget newFrameReadyAtTime:currentTime atIndex:textureIndexOfTarget];
                }
            }
        }
        if (videoTextureRef) {
            CFRelease(videoTextureRef);
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        
        CFRelease(sampleBuffer);
        _frameRendering = NO;
    });
    
}

- (void)updateOrientationSendToTargets;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        //    From the iOS 5.0 release notes:
        //    In previous iOS versions, the front-facing camera would always deliver buffers in AVCaptureVideoOrientationLandscapeLeft and the back-facing camera would always deliver buffers in AVCaptureVideoOrientationLandscapeRight.
        if (_cameraPosition == AVCaptureDevicePositionBack)
        {
            if (_horizontallyMirrorRearFacingCamera)
            {
                switch(_outputImageOrientation)
                {
                    case UIInterfaceOrientationPortrait:_outputRotation = kGPUImageRotateRightFlipVertical; break;
                    case UIInterfaceOrientationPortraitUpsideDown:_outputRotation = kGPUImageRotate180; break;
                    case UIInterfaceOrientationLandscapeLeft:_outputRotation = kGPUImageFlipHorizonal; break;
                    case UIInterfaceOrientationLandscapeRight:_outputRotation = kGPUImageFlipVertical; break;
                    default:_outputRotation = kGPUImageNoRotation;
                }
            }
            else
            {
                switch(_outputImageOrientation)
                {
                    case UIInterfaceOrientationPortrait:_outputRotation = kGPUImageRotateRight; break;
                    case UIInterfaceOrientationPortraitUpsideDown:_outputRotation = kGPUImageRotateLeft; break;
                    case UIInterfaceOrientationLandscapeLeft:_outputRotation = kGPUImageRotate180; break;
                    case UIInterfaceOrientationLandscapeRight:_outputRotation = kGPUImageNoRotation; break;
                    default:_outputRotation = kGPUImageNoRotation;
                }
            }
        }
        else
        {
            if (_horizontallyMirrorFrontFacingCamera)
            {
                switch(_outputImageOrientation)
                {
                    case UIInterfaceOrientationPortrait:_outputRotation = kGPUImageRotateRightFlipVertical; break;
                    case UIInterfaceOrientationPortraitUpsideDown:_outputRotation = kGPUImageRotateRightFlipHorizontal; break;
                    case UIInterfaceOrientationLandscapeLeft:_outputRotation = kGPUImageFlipHorizonal; break;
                    case UIInterfaceOrientationLandscapeRight:_outputRotation = kGPUImageFlipVertical; break;
                    default:_outputRotation = kGPUImageNoRotation;
                }
            }
            else
            {
                switch(_outputImageOrientation)
                {
                    case UIInterfaceOrientationPortrait:_outputRotation = kGPUImageRotateRight; break;
                    case UIInterfaceOrientationPortraitUpsideDown:_outputRotation = kGPUImageRotateLeft; break;
                    case UIInterfaceOrientationLandscapeLeft:_outputRotation = kGPUImageNoRotation; break;
                    case UIInterfaceOrientationLandscapeRight:_outputRotation = kGPUImageRotate180; break;
                    default:_outputRotation = kGPUImageNoRotation;
                }
            }
        }
    });
}

- (void)setOutputImageOrientation:(UIInterfaceOrientation)newValue;
{
    _outputImageOrientation = newValue;
    [self updateOrientationSendToTargets];
}

- (void)setHorizontallyMirrorFrontFacingCamera:(BOOL)newValue
{
    _horizontallyMirrorFrontFacingCamera = newValue;
    [self updateOrientationSendToTargets];
}

- (void)setHorizontallyMirrorRearFacingCamera:(BOOL)newValue
{
    _horizontallyMirrorRearFacingCamera = newValue;
    [self updateOrientationSendToTargets];
}
@end
