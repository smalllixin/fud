//
//  GPUFacekitOutput.h
//  sdktexlab
//
//  Created by xin li on 8/26/16.
//  Copyright © 2016 faceu. All rights reserved.
//

#import <GPUImage/GPUImage.h>
#import <facekit/facekit.h>

@interface GPUFacekitOutput : GPUImageOutput

/// These properties determine whether or not the two camera orientations should be mirrored. By default, both are NO.
@property(readwrite, nonatomic) BOOL horizontallyMirrorFrontFacingCamera, horizontallyMirrorRearFacingCamera;

/// This determines the rotation applied to the output image, based on the source material
@property(readwrite, nonatomic) UIInterfaceOrientation outputImageOrientation;

@property (readwrite, nonatomic) AVCaptureDevicePosition cameraPosition;


- (id)initWithRenderEngine:(LMRenderEngine*)renderEngine;
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end
