//
//  LMCamera.h
//  FaceU
//
//  Created by 李兴鹏 on 16/7/27.
//  Copyright © 2016年 miantanteam. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

extern NSString *const kCameraKey;
extern NSString *const kVideoChatReqKey;
extern NSString *const kVideoChatRspKey;
extern NSString *const kVideoChatTalkingKey;

@class LMCamera;
@protocol LMCameraOutput <NSObject>

@required
- (void)camera:(LMCamera*)camera withSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

@interface LMCamera : NSObject

- (id)initWithPosition:(AVCaptureDevicePosition)cameraPosition cameraSessionPreset:(NSString*)preset pixelFormatType:(OSType)pixelFormatType;

- (AVCaptureDevice *)inputCamera;

- (AVCaptureDevicePosition)cameraPosition;

- (AVCaptureAudioDataOutput *)audioOutput;

- (CALayer *)previewLayer;

- (void)setCameraOutput:(id<LMCameraOutput>)outPut;

/**
 *  暂停捕捉
 */
- (void)pauseCameraCapture;

/**
 *  恢复捕捉
 */
- (void)resumeCameraCapture;

/**
 *  停止捕捉
 */
- (void)stopCameraCapture;

/**
 *  开始捕捉
 */
- (void)startCameraCapture;

/**
 *  切换前后摄像头
 */
- (void)rotateCamera;

/**
 *  设置闪光灯
 *
 *  @param flashSwitch 开关
 */
- (void)setFlashOnOrOff:(BOOL)flashSwitch;

/**
 *  设置相机 自动曝光模式
 */
- (void)enableContinuousAutoExposure;

/**
 *  设置相机 自动白平衡模式
 */
- (void)enableContinuousAutoWhiteBalance;

/**
 *  设置相机 自动对焦
 */
- (void)enableContinuousAutoFocus;

/**
 *  设置相机 ISO
 *
 *  @param iso
 */
- (void)setCustomExposureWithISO:(float)iso;
/**
 *  设置相机 曝光时间
 *
 *  @param duration
 */
- (void)setCustomExposureWithDuration:(float)duration;

/**
 *  按步长 增加/减少 当前 iso
 *
 *  @param isoStep
 */
- (void)updateCustomExposureWithISOStep:(float)isoStep;

/**
 *  按步长 增加/减少 当前 曝光时间
 *
 *  @param durationStep
 */
- (void)updateCustomExposureWithDurationStep:(float)durationStep;

/**
 *  设置相机 曝光补偿
 *
 *  @param bias
 */
- (void)setExposureTargetBias:(float)bias;

/**
 *  设置焦距
 */
- (void)upZoomFactor;

/**
 *  焦距设回
 */
- (void)setZoomFactorBack;

/**
 *  还原相机放大倍数
 */
- (void)resetCameraZoomFactor;

/**
 *  定点一次性自动曝光
 *
 *  @param pointInView
 */
- (void)lockExposureAtPointOfInterest:(CGPoint)pointInView;

/**
 *  定点对焦
 *
 *  @param pointInView
 */
- (void)lockFocusAtPointOfInterest:(CGPoint)pointInView;

/**
 *  手动定点对焦同时定点一次性曝光
 *
 *  @param pointInView
 */
- (void)lockExposureAndFocusAtPointOfInterest:(CGPoint)pointInView;

/**
 *  设置相机HDR使能
 *
 *  @param enable
 */
- (void)setVideoHDREnable:(BOOL)enable;

- (void)setFrameRate:(int32_t)frameRate;

@end
