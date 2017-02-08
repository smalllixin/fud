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

- (id)initWithRenderEngine:(LMRenderEngine*)renderEngine;
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@property (nonatomic, strong) void (^processPixelbuffer)(CVPixelBufferRef pixelbuffer);
@end
