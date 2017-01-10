//
//  LMGLPreviewView.h
//  sdktexlab
//
//  Created by xin li on 7/28/16.
//  Copyright © 2016 faceu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LMGLContext.h"
#import <facekit/facekit.h>

@interface LMGLPreviewView : UIView

- (id)initWithFrame:(CGRect)frame andContext:(LMGLContext*)context;
@property (nonatomic, strong) LMRenderEngine *renderEngine;
@property (nonatomic, strong) void (^processPixelbuffer)(CVPixelBufferRef pixelbuffer);

// ONLY BGRA format PixelBuffer accepted.
- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end
