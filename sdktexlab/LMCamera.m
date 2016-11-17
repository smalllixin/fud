//
//  LMCamera.m
//  FaceU
//
//  Created by 李兴鹏 on 16/7/27.
//  Copyright © 2016年 miantanteam. All rights reserved.
//

#import "LMCamera.h"
#import <CoreMedia/CoreMedia.h>

NSString *const kCameraKey = @"Camera";
NSString *const kVideoChatReqKey = @"VideoChatReq";
NSString *const kVideoChatRspKey = @"VideoChatRsp";
NSString *const kVideoChatTalkingKey = @"VideoChatTalking";

@interface LMCamera () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    
    dispatch_queue_t _cameraProcessingQueue;
    AVCaptureVideoPreviewLayer *_previewLayer;
    NSString *_currenPreset;
    dispatch_queue_t _cameraSessionQueue;
    __weak id<LMCameraOutput> _cameraOutput;
    BOOL _isPause;
    int32_t _frameRate;
}

@property(readonly, retain, nonatomic) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDevice *inputCamera;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, assign) CGFloat lastZoomFactor;

@end

@implementation LMCamera

- (id)initWithPosition:(AVCaptureDevicePosition)cameraPosition cameraSessionPreset:(NSString*)preset pixelFormatType:(OSType)pixelFormatType
{
    if (self = [super init])
    {
        _cameraProcessingQueue = dispatch_queue_create("com.faceu.camera.process", DISPATCH_QUEUE_SERIAL);
        _cameraSessionQueue = dispatch_queue_create("com.faceu.camera.settings", DISPATCH_QUEUE_SERIAL);
        _inputCamera = [self p_captureDeviceWithPosition:cameraPosition];
        _captureSession = [AVCaptureSession new];
        [self initCaptureIOput:_captureSession pixelFormatType:pixelFormatType];
        [self setCamerSessionPreset:preset];
        if (cameraPosition == AVCaptureDevicePositionBack) {
            [self updateCameraOrientation];
        }
    }
    return self;
}

- (void)initCaptureIOput:(AVCaptureSession *)session pixelFormatType:(OSType)pixelFormatType
{
    NSError *error = nil;
    //视频输入
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_inputCamera error:&error];
    if ([_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }
    
    //视频输出
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:pixelFormatType] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [_videoOutput setSampleBufferDelegate:self queue:_cameraProcessingQueue];
    if ([_captureSession canAddOutput:_videoOutput]) {
        [_captureSession addOutput:_videoOutput];
    }
}

- (AVCaptureDevicePosition)cameraPosition
{
    return _inputCamera.position;
}

- (AVCaptureAudioDataOutput *)audioOutput
{
    return _audioOutput;
}

- (AVCaptureDevice *)inputCamera
{
    return _inputCamera;
}

- (CALayer *)previewLayer
{
    if (!_previewLayer) {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _previewLayer;
}

- (void)setCameraOutput:(id<LMCameraOutput>)outPut
{
    _cameraOutput = outPut;
}

- (void)startCameraCapture
{
    dispatch_async(_cameraSessionQueue, ^{
        if (![_captureSession isRunning])
        {
            [_captureSession startRunning];
        }
    });
}

- (void)stopCameraCapture
{
    dispatch_async(_cameraSessionQueue, ^{
        if ([_captureSession isRunning])
        {
            [_captureSession stopRunning];
        }
    });
}

- (void)pauseCameraCapture
{
    _isPause = YES;
}

- (void)resumeCameraCapture
{
    _isPause = NO;
    [self startCameraCapture];
}

- (void)setFlashOnOrOff:(BOOL)flashSwitch
{
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if ([inputCamera isTorchModeSupported:flashSwitch] && _inputCamera.torchMode != flashSwitch) {
            [inputCamera setTorchMode:flashSwitch];
        }
    }];
}

- (void)enableContinuousAutoExposure
{
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if ([inputCamera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            inputCamera.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        }
    }];
}

//设置相机 自动白平衡模式
- (void)enableContinuousAutoWhiteBalance
{
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if ([inputCamera isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
            inputCamera.whiteBalanceMode = AVCaptureWhiteBalanceModeAutoWhiteBalance;
        }
    }];
}

//设置相机 自动对焦
- (void)enableContinuousAutoFocus
{
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if ([inputCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            inputCamera.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }
    }];
}

- (void)setCustomExposureWithISO:(float)iso
{
    AVCaptureDeviceFormat *activeFormat = _inputCamera.activeFormat;
    iso = MAX(iso, activeFormat.minISO);
    iso = MIN(iso, activeFormat.maxISO);
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if ([inputCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            [inputCamera setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:iso completionHandler:nil];
        }
    }];
}

- (void)setCustomExposureWithDuration:(float)duration
{
    AVCaptureDeviceFormat *activeFormat = _inputCamera.activeFormat;
    CMTime finalDuration = CMTimeMakeWithSeconds((Float64)duration, 1000000);
    CMTimeRange durationRange = CMTimeRangeFromTimeToTime(activeFormat.minExposureDuration, activeFormat.maxExposureDuration);
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if ([inputCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            if (CMTimeRangeContainsTime(durationRange, finalDuration))
            {
                [inputCamera setExposureModeCustomWithDuration:finalDuration ISO:AVCaptureISOCurrent completionHandler:nil];
            }
        }
    }];
}

//按步长 增加/减少 当前 iso
- (void)updateCustomExposureWithISOStep:(float)isoStep
{
    AVCaptureDeviceFormat *activeFormat = _inputCamera.activeFormat;
    float restIso = _inputCamera.ISO + isoStep;
    if (restIso < activeFormat.minISO || restIso > activeFormat.maxISO) {
        return;
    }
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        [inputCamera setExposureModeCustomWithDuration:AVCaptureExposureDurationCurrent ISO:restIso completionHandler:nil];
    }];
}

- (void)updateCustomExposureWithDurationStep:(float)duraStep
{
    __block float durationStep = duraStep;
    CMTime curDura = _inputCamera.exposureDuration;
    float duration = CMTimeGetSeconds(curDura);
    if (durationStep > 0) {
        durationStep = 0.01;
    }
    else
    {
        durationStep = -0.01;
    }
    duration += durationStep;
    
    AVCaptureDeviceFormat *activeFormat = _inputCamera.activeFormat;
    CMTime finalDuration = CMTimeMakeWithSeconds((Float64)duration, 1000000);
    
    CMTimeRange durationRange = CMTimeRangeFromTimeToTime(activeFormat.minExposureDuration, activeFormat.maxExposureDuration);
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if (CMTimeRangeContainsTime(durationRange, finalDuration))
        {
            [inputCamera setExposureModeCustomWithDuration:finalDuration ISO:AVCaptureISOCurrent completionHandler:nil];
        }
    }];
}

- (void)setExposureTargetBias:(float)bias
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
    {
        [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
            [inputCamera setExposureTargetBias:bias completionHandler:nil];
        }];
    }
}

- (void)upZoomFactor
{
    self.lastZoomFactor = _inputCamera.videoZoomFactor;
    CGFloat fator = MAX(_inputCamera.videoZoomFactor + 0.05, _inputCamera.activeFormat.videoMaxZoomFactor);
    fator = MIN(1.8, fator);
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        inputCamera.videoZoomFactor = fator;
    }];
}

- (void)setZoomFactorBack
{
    if (!self.lastZoomFactor) {
        return;
    }
    __weak typeof(self) wself = self;
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        inputCamera.videoZoomFactor = wself.lastZoomFactor;
    }];
}

- (void)resetCameraZoomFactor
{
    if ((self.lastZoomFactor!=1.0) || (_inputCamera.videoZoomFactor != 1.0))
    {
        [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
            inputCamera.videoZoomFactor = 1.0;
        }];
        self.lastZoomFactor = 1.0;
    }
}

//定点曝光
- (void)lockExposureAtPointOfInterest:(CGPoint)pointInView
{
    
    __block CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize scrnSize = [UIScreen mainScreen].bounds.size;
    
    if (_inputCamera.position == AVCaptureDevicePositionFront) {
        pointInView.x = scrnSize.width - pointInView.x;
    }
    pointOfInterest = CGPointMake(pointInView.y / scrnSize.height, 1.f - (pointInView.x / scrnSize.width));
    
    BOOL expInter = [_inputCamera isExposurePointOfInterestSupported];
    
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if (expInter==YES) {
            [inputCamera setExposurePointOfInterest:pointOfInterest];
            
            [inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
    }];
}

//定点对焦
- (void)lockFocusAtPointOfInterest:(CGPoint)pointInView
{
    __block CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize scrnSize = [UIScreen mainScreen].bounds.size;
    
    if (_inputCamera.position == AVCaptureDevicePositionFront) {
        pointInView.x = scrnSize.width - pointInView.x;
    }
    pointOfInterest = CGPointMake(pointInView.y / scrnSize.height, 1.f - (pointInView.x / scrnSize.width));
    
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if ([inputCamera isFocusPointOfInterestSupported]) {
            [inputCamera setFocusPointOfInterest:pointOfInterest];
            [inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
        }
    }];
    
}

//手动定点对焦同时定点一次性曝光
- (void)lockExposureAndFocusAtPointOfInterest:(CGPoint)pointInView
{
    
    __block CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize scrnSize = [UIScreen mainScreen].bounds.size;
    
    if (_inputCamera.position == AVCaptureDevicePositionFront) {
        pointInView.x = scrnSize.width - pointInView.x;
    }
    
    pointOfInterest = CGPointMake(pointInView.y / scrnSize.height, 1.f - (pointInView.x / scrnSize.width));
    
    BOOL focusInter = [_inputCamera isFocusPointOfInterestSupported];
    BOOL expInter = [_inputCamera isExposurePointOfInterestSupported];
    
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        if (expInter)
        {
            [inputCamera setExposurePointOfInterest:pointOfInterest];
            [inputCamera setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        }
        if (focusInter) {
            [inputCamera setFocusPointOfInterest:pointOfInterest];
            [inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
        }
    }];
}

//设置相机HDR使能
- (void)setVideoHDREnable:(BOOL)enable
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
    {
        [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
            [inputCamera setAutomaticallyAdjustsVideoHDREnabled:!enable];
            if (enable) {
                [inputCamera setVideoHDREnabled:YES];
            }
        }];
    }
}

- (void)rotateCamera
{
    __weak typeof(self) wself = self;
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        NSError *error;
        AVCaptureDeviceInput *newVideoInput;
        AVCaptureDevicePosition currentCameraPosition = [[wself.videoInput device] position];
        
        if (currentCameraPosition == AVCaptureDevicePositionBack)
        {
            currentCameraPosition = AVCaptureDevicePositionFront;
        }
        else
        {
            currentCameraPosition = AVCaptureDevicePositionBack;
        }
        
        AVCaptureDevice *backFacingCamera = nil;
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices)
        {
            if ([device position] == currentCameraPosition)
            {
                backFacingCamera = device;
            }
        }
        newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:backFacingCamera error:&error];
        
        if (newVideoInput != nil)
        {
            [wself.captureSession beginConfiguration];
            
            [wself.captureSession removeInput:wself.videoInput];
            if ([wself.captureSession canAddInput:newVideoInput])
            {
                [wself.captureSession addInput:newVideoInput];
                _videoInput = newVideoInput;
            }
            else
            {
                [wself.captureSession addInput:wself.videoInput];
            }
            wself.inputCamera = backFacingCamera;
            
            [wself updateCameraOrientation];
            
            [wself.captureSession commitConfiguration];
        }
        else
        {
            NSLog(@"newVideoInput==nil");
        }
    }];
}

// AVCaptureSessionPreset640x480
- (void)setCamerSessionPreset:(NSString*)preset
{
    if (_currenPreset == preset) {
        return;
    }
    _currenPreset = preset;
    __weak typeof(self) wself = self;
    [self addInputCameraSettingsTask:^(AVCaptureDevice *inputCamera) {
        [wself.captureSession beginConfiguration];
        if ([wself.captureSession canSetSessionPreset:preset]) {//设置分辨率
            wself.captureSession.sessionPreset = preset;
        }
        [wself.captureSession commitConfiguration];
    }];
}

- (void)setFrameRate:(int32_t)frameRate
{
    _frameRate = frameRate;
    
    dispatch_async(_cameraSessionQueue, ^{
        if (_frameRate > 0)
        {
            if ([_inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
                [_inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
                
                NSError *error;
                [_inputCamera lockForConfiguration:&error];
                if (error == nil) {
#if defined(__IPHONE_7_0)
                    [_inputCamera setActiveVideoMinFrameDuration:CMTimeMake(1, _frameRate)];
                    [_inputCamera setActiveVideoMaxFrameDuration:CMTimeMake(1, _frameRate)];
#endif
                }
                [_inputCamera unlockForConfiguration];
                
            } else {
                for (AVCaptureConnection *connection in _videoOutput.connections)
                {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                        connection.videoMinFrameDuration = CMTimeMake(1, _frameRate);
                    
                    if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                        connection.videoMaxFrameDuration = CMTimeMake(1, _frameRate);
#pragma clang diagnostic pop
                }
            }
            
        }
        else
        {
            if ([_inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
                [_inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
                
                NSError *error;
                [_inputCamera lockForConfiguration:&error];
                if (error == nil) {
#if defined(__IPHONE_7_0)
                    [_inputCamera setActiveVideoMinFrameDuration:kCMTimeInvalid];
                    [_inputCamera setActiveVideoMaxFrameDuration:kCMTimeInvalid];
#endif
                }
                [_inputCamera unlockForConfiguration];
                
            } else {
                
                for (AVCaptureConnection *connection in _videoOutput.connections)
                {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                        connection.videoMinFrameDuration = kCMTimeInvalid; // This sets videoMinFrameDuration back to default
                    
                    if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                        connection.videoMaxFrameDuration = kCMTimeInvalid; // This sets videoMaxFrameDuration back to default
#pragma clang diagnostic pop
                }
            }
            
        }
    });
}

#pragma mark -private
-(AVCaptureDevice *)p_captureDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}

- (void)addInputCameraSettingsTask:(void(^)(AVCaptureDevice *inputCamera))settingTask
{
    dispatch_async(_cameraSessionQueue, ^{
        NSError *error = nil;
        if ([_inputCamera lockForConfiguration:&error])
        {
            if(settingTask){
                @try {
                    settingTask(_inputCamera);
                } @catch (NSException *exception) {
                    NSLog(@"update camera settings error, exception name:%@, exception reason:%@",exception.name, exception.reason);
                } @finally {
                }
            }
            [_inputCamera unlockForConfiguration];
        }
        else {
            if (error) {
                NSLog(@"lock camera configuration failed,error:%@",error.userInfo);
            }
        }
    });
}

- (void)updateCameraOrientation
{
    AVCaptureConnection *videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (self.cameraPosition == AVCaptureDevicePositionBack) {
        [videoConnection setVideoMirrored:YES];
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
    }
    else {
        [videoConnection setVideoMirrored:NO];
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (_isPause) {
        return;
    }
    if (_cameraOutput) {
        [_cameraOutput camera:self withSampleBuffer:sampleBuffer];
    }
}

@end
