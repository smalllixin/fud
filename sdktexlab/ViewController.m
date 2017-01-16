//
//  ViewController.m
//  sdktexlab
//
//  Created by xin li on 7/28/16.
//  Copyright © 2016 faceu. All rights reserved.
//

#import "ViewController.h"
#import "LMCamera.h"
#import "LMGLPreviewView.h"
#import "GPUFacekitOutput.h"

#define USE_GPUIMAGE 1

//
static LMFilterPos LMFilterPosBeauty = 100;
static LMFilterPos LMFilterPosFilter = 120;
static LMFilterPos LMFilterPosReshape = 140;
static LMFilterPos LMFilterPosSticker = 160;

@interface ViewController ()<LMCameraOutput>

@property (nonatomic, strong) LMCamera *camera;
@property (nonatomic, strong) LMGLContext *ctx;
#ifdef USE_GPUIMAGE
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) GPUFacekitOutput *facekitOutput;
@property (nonatomic, strong) GPUImageFilter *passthroughFilter;
#else
@property (nonatomic, strong) LMGLPreviewView *previewView;
#endif
@property (nonatomic, strong) LMRenderEngine *renderEngine;

@property (nonatomic, strong) NSArray *sandbox;

@property (nonatomic, strong) UILabel *tipsLabel;
@property (nonatomic, strong) NSTimer *tipsTimer;

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) UIView *containerView;

@end

@implementation ViewController {
    NSBundle *_resBundle;
    LMFilterPos _effectPos;
    NSTimer *_fadeTimer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    _camera = [[LMCamera alloc]
               initWithPosition:AVCaptureDevicePositionFront
               cameraSessionPreset:AVCaptureSessionPreset1280x720//AVCaptureSessionPreset640x480
               pixelFormatType: kCVPixelFormatType_32BGRA/* kCVPixelFormatType_420YpCbCr8BiPlanarFullRange */];
    [_camera setFrameRate:25];
    [_camera setCameraOutput: self];
    [_camera startCameraCapture];

#ifdef USE_GPUIMAGE
    LMRenderEngine *renderEngine = [LMRenderEngine engineForTextureWithGLContext:[GPUImageContext sharedImageProcessingContext].context queue:[GPUImageContext sharedContextQueue]];
    _facekitOutput = [[GPUFacekitOutput alloc] initWithRenderEngine:renderEngine];
    _gpuImageView = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    _gpuImageView.fillMode = kGPUImageFillModeStretch;
    [_facekitOutput addTarget:_gpuImageView];
    [self.view addSubview:_gpuImageView];
    
    _facekitOutput.horizontallyMirrorFrontFacingCamera = YES;
    _facekitOutput.outputImageOrientation = UIInterfaceOrientationPortrait;
#else
    _ctx = [[LMGLContext alloc] initWithShareGroup:nil];
    LMRenderEngine *renderEngine = [LMRenderEngine engineForTextureWithGLContext:_ctx.c queue:_ctx.contextQueue faceless:NO portraitOutput:YES];
    _previewView = [[LMGLPreviewView alloc] initWithFrame:self.view.bounds andContext:_ctx];
    [self.view addSubview:_previewView];
    _previewView.renderEngine = renderEngine;
    [_previewView setProcessPixelbuffer:^(CVPixelBufferRef pixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        size_t w = CVPixelBufferGetWidth(pixelBuffer);
        size_t h = CVPixelBufferGetHeight(pixelBuffer);
//        void *addr = CVPixelBufferGetBaseAddress(pixelBuffer);
        NSLog(@"%ld %ld", w, h);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        
    }];
#endif
    NSBundle *resBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"LMEffectResource" ofType:@"bundle"]];
    _resBundle = resBundle;

    _renderEngine = renderEngine;
    [self setupButtons];
    [self setupUI];
    [self setupAudioPlayer];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapFocus:)];
    [self.view addGestureRecognizer:tap];
    [self.camera enableContinuousAutoFocus];
    [self.camera enableContinuousAutoExposure];
    [self.camera enableContinuousAutoWhiteBalance];
    [self.camera setVideoHDREnable:YES];
    //    [_renderEngine applyWithPath:[resBundle pathForResource:BeautySandbox(2) ofType:@""]];
    //    [_renderEngine applyWithPath:[resBundle pathForResource:@"effect/maopa" ofType:@""]];
    //    [_renderEngine applyWithPath:[resBundle pathForResource:@"effect/maoyao_mz" ofType:@""]];
    //    [_renderEngine applyWithPath:[resBundle pathForResource:@"effect/shuijing_b" ofType:@""]];
    //    [_renderEngine applyWithPath:[resBundle pathForResource:@"effect/animal_zhuzhu_b" ofType:@""]];
    //    [_renderEngine applyWithPath:[resBundle pathForResource:@"effect/animal_mycat" ofType:@""]];
    //    [_renderEngine applyWithPath:[resBundle pathForResource:@"effect/SikaDeer" ofType:@""]];
    //    [_renderEngine applyBeautyLevelV2:kLMBeautyFilterLevel2];
    //    [_renderEngine applyStickerWithName:@"effect/boomhair"];
    //    [_renderEngine applyDayan];
    
    //    [_renderEngine applyStickerWithName:@"effect/indian"];
    //    [_renderEngine applyStickerWithName:@"effect/cat_ear"];
    //    [_renderEngine applyStickerWithName:@"effect/hiphop"];
    //    [_renderEngine applyStickerWithName:@"effect/zhangcao"];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupButtons {
    _sandbox = @[
                 @{@"tag":@(100), @"name": @"beauty/beauty0", @"title": @"美颜1"},
                 @{@"tag":@(101), @"name": @"beauty/beauty1", @"title": @"美颜2"},
                 @{@"tag":@(102), @"name": @"beauty/beauty2", @"title": @"美颜3"},
                 @{@"tag":@(103), @"name": @"beauty/beauty3", @"title": @"美颜4"},
                 @{@"tag":@(104), @"name": @"beauty/beauty4", @"title": @"美颜5"},
                 @{@"tag":@(200), @"name": @"beauty/new_beauty0", @"title": @"new美颜1"},
                 @{@"tag":@(201), @"name": @"beauty/new_beauty1", @"title": @"new美颜2"},
                 @{@"tag":@(202), @"name": @"beauty/new_beauty2", @"title": @"new美颜3"},
                 
                 @{@"tag":@(110), @"name": @"filter/filter0", @"title": @"滤镜1"},
                 @{@"tag":@(111), @"name": @"filter/filter1", @"title": @"滤镜2"},
                 @{@"tag":@(112), @"name": @"filter/filter2", @"title": @"滤镜3"},
                 @{@"tag":@(113), @"name": @"filter/filter3", @"title": @"滤镜4"},
                 @{@"tag":@(114), @"name": @"filter/filter4", @"title": @"滤镜5"},
                 
                 @{@"tag":@(150), @"name": @"surgery/bigeyes", @"title": @"大眼"},
                 @{@"tag":@(151), @"name": @"surgery/bigeyesAndSlimface", @"title": @"大颜瘦脸"},
                 @{@"tag":@(152), @"name": @"surgery/lovely", @"title": @"Cute脸"},
                 @{@"tag":@(153), @"name": @"surgery/snakeface", @"title": @"蛇脸"},
                 
                 @{@"tag":@(1), @"name": @"effect/cat_ear", @"title": @"猫耳"},
                 @{@"tag":@(2), @"name": @"effect/hiphop", @"title": @"嘻哈"},
                 @{@"tag":@(3), @"name": @"effect/zhangcao", @"title": @"长草"},
                 @{@"tag":@(4), @"name": @"effect/rifeng_b", @"title": @"扇子"},
                 @{@"tag":@(5), @"name": @"effect/SikaDeer", @"title": @"鹿"},
                 @{@"tag":@(6), @"name": @"effect/j3_gaibang", @"title": @"丐帮"},
                 @{@"tag":@(8), @"name": @"effect/maopa", @"title": @"猫趴"},
                 @{@"tag":@(9), @"name": @"effect/maoyao_mz", @"title": @"猫妖"},
                 @{@"tag":@(10), @"name": @"effect/moshou", @"title": @"魔兽"},
                 @{@"tag":@(11), @"name": @"effect/animal_zhuzhu_b", @"title": @"猪猪"},
                 @{@"tag":@(12), @"name": @"effect/animal_mycat", @"title": @"手猫"},
                 ];
    _containerView = [[UIView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_containerView];
    CGFloat yStartPos = 22;
    CGFloat width = 100;
    CGFloat height = 44;
    CGFloat y = yStartPos;
    CGFloat x = 0;
    
    //    CGFloat winWidth = self.view.bounds.size.width;
    CGFloat winHeight = self.view.bounds.size.height;
    
    for (int i = 0; i < _sandbox.count; i ++) {
        NSDictionary *s = _sandbox[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(x, y, width, height);
        btn.tag = [s[@"tag"] integerValue];
        [btn setTitle:s[@"title"] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(onPressed:) forControlEvents:UIControlEventTouchUpInside];
        [_containerView addSubview:btn];
        y += height + 1;
        
        if (y + height > winHeight) {
            y = yStartPos;
            x += width + 1;
        }
    }
    
    y = yStartPos;
    x += width + 1;
    
    NSArray *closeBtns = @[
                           @{@"tag":@(LMFilterPosBeauty), @"title": @"关闭美颜" },
                           @{@"tag":@(LMFilterPosFilter), @"title": @"关闭滤镜" },
                           @{@"tag":@(LMFilterPosReshape), @"title": @"关闭整形" },
                           @{@"tag":@(LMFilterPosSticker), @"title": @"关闭贴纸" },
                           ];
    for (int i = 0; i < closeBtns.count; i ++) {
        NSDictionary *s = closeBtns[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(x, y, width, height);
        btn.tag = [s[@"tag"] integerValue];
        [btn setTitle:s[@"title"] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(onClosePressed:) forControlEvents:UIControlEventTouchUpInside];
        [_containerView addSubview:btn];
        y += height + 1;
        
        if (y + height > winHeight) {
            y = yStartPos;
            x += width + 1;
        }
    }
    
    UIButton *cameraRotateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_containerView addSubview:cameraRotateButton];
    [cameraRotateButton setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    [cameraRotateButton setTitle:@"切换摄像头" forState:UIControlStateNormal];
    [cameraRotateButton addTarget:self action:@selector(rotateCamera) forControlEvents:UIControlEventTouchUpInside];
    [cameraRotateButton sizeToFit];
    cameraRotateButton.frame = CGRectMake(self.view.frame.size.width - cameraRotateButton.frame.size.width,
                                          self.view.frame.size.height - cameraRotateButton.frame.size.height,
                                          cameraRotateButton.frame.size.width, cameraRotateButton.frame.size.height);
}

- (void)onPressed:(UIButton*)btn {
    for (NSDictionary *d in _sandbox) {
        NSInteger t = [d[@"tag"] integerValue];
        if (t == btn.tag) {
            NSString *sandboxPath = [_resBundle pathForResource:d[@"name"] ofType:@""];
            LMFilterPos pos = [_renderEngine applyWithPath:sandboxPath];
            NSLog(@"applied pos:%d", pos);
            break;
        }
    }
}

- (void)onClosePressed:(UIButton*)btn {
    LMFilterPos pos =  (LMFilterPos)btn.tag;
    [_renderEngine stopFilter:pos];
}

- (void)effectSelect:(UIButton*)button {
    int num = (int)button.tag;
    if (num == -1) {
        [_renderEngine stopFilter:_effectPos];
        return;
    }
    NSString *name = [NSString stringWithFormat:@"filter/filter%d", num];
    NSString *sandboxFolder = [_resBundle pathForResource:name ofType:@""];
    _effectPos = [_renderEngine applyWithPath:sandboxFolder];
    
}

- (void)onFace {
    [_renderEngine enableFaceDetect:YES];
}

- (void)offFace {
    [_renderEngine enableFaceDetect:NO];
}

- (void)rotateCamera {
    [_camera rotateCamera];
    NSLog(@"rotateCamera");
}

- (void)singleTapFocus:(UITapGestureRecognizer*)gesture {
    [_fadeTimer invalidate];
    _fadeTimer = [NSTimer scheduledTimerWithTimeInterval:2.5f target:self selector:@selector(fadeInContainer) userInfo:nil repeats:NO];
    _containerView.hidden = YES;
    [self.camera lockExposureAndFocusAtPointOfInterest:[gesture locationInView:self.view]];
}

- (void)fadeInContainer {
    _containerView.hidden = NO;
}

#pragma mark - tips

- (void)setupUI {
    _tipsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, self.view.bounds.size.width, 40)];
    _tipsLabel.textColor = [UIColor blackColor];
    _tipsLabel.font = [UIFont systemFontOfSize:22];
    _tipsLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_tipsLabel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showTipsNotify:) name:kLMShowTipsNotification object:nil];
}

- (void)showTipsNotify:(NSNotification*)notification {
    [_tipsTimer invalidate];
    LMShowTipsNotification *data = (LMShowTipsNotification *)notification.userInfo[kLMNotifyUserInfoKey];
    _tipsLabel.text = data.text;
    _tipsTimer = [NSTimer scheduledTimerWithTimeInterval:data.durationSecond target:self selector:@selector(tipsTimeup:) userInfo:nil repeats:NO];
}

- (void)tipsTimeup:(NSTimer*)timer {
    _tipsLabel.text = @"";
}

#pragma mark - Sound
- (void)setupAudioPlayer {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playAudioNotify:) name:kLMPlayAudioNotification object:nil];
}

- (void)playAudioNotify:(NSNotification*)notification {
    LMPlayAudioNotification *data = (LMPlayAudioNotification *)notification.userInfo[kLMNotifyUserInfoKey];
    [_audioPlayer stop];
    if (data.doPlay) {
        NSError *error;
        _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:data.audioPath] error:&error];
        if (error) {
            NSLog(@"initial audio player err");
            return;
        }
        _audioPlayer.numberOfLoops = data.repeat?10000:1;
        [_audioPlayer play];
    }
}

#pragma mark - LMCameraOutput protocol
- (void)camera:(LMCamera*)camera withSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    OSType formatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (formatType == kCVPixelFormatType_32BGRA) {
#ifdef USE_GPUIMAGE
        [_facekitOutput processSampleBuffer:sampleBuffer];
#else
        [_previewView renderSampleBuffer:sampleBuffer];
#endif
    } else {
        NSLog(@"previewView only support BGRA pixelBuffer");
    }
}

@end
