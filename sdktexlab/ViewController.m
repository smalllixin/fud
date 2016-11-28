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

//#define USE_GPUIMAGE 1

//
static LMFilterPos LMFilterPosBeauty = 100;
static LMFilterPos LMFilterPosFilter = 120;
//static LMFilterPos LMFilterPosReshape = 140;
//static LMFilterPos LMFilterPosSticker = 160;

@interface ViewController ()<LMCameraOutput>

@property (nonatomic, strong) LMCamera *camera;
@property (nonatomic, strong) LMGLContext *ctx;
#ifdef USE_GPUIMAGE
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) GPUFacekitOutput *facekitOutput;
#else
@property (nonatomic, strong) LMGLPreviewView *previewView;
#endif
@property (nonatomic, strong) LMRenderEngine *renderEngine;

@property (nonatomic, strong) NSArray *sandbox;

@property (nonatomic, strong) UILabel *tipsLabel;
@property (nonatomic, strong) NSTimer *tipsTimer;

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@end

@implementation ViewController {
    NSBundle *_resBundle;
    LMFilterPos _effectPos;
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
    LMRenderEngine *renderEngine = [LMRenderEngine engineForFacelessWithGLContext:[GPUImageContext sharedImageProcessingContext].context queue:[GPUImageContext sharedContextQueue]];
    _facekitOutput = [[GPUFacekitOutput alloc] initWithRenderEngine:renderEngine];
    _gpuImageView = [[GPUImageView alloc] initWithFrame:self.view.bounds];
    _gpuImageView.fillMode = kGPUImageFillModeStretch;
    [_facekitOutput addTarget:_gpuImageView];
    [self.view addSubview:_gpuImageView];
    
    _facekitOutput.horizontallyMirrorFrontFacingCamera = YES;
    _facekitOutput.outputImageOrientation = UIInterfaceOrientationPortrait;
#else
    _ctx = [[LMGLContext alloc] initWithShareGroup:nil];
    LMRenderEngine *renderEngine = [LMRenderEngine engineForFacelessWithGLContext:_ctx.c queue:_ctx.contextQueue];
    _previewView = [[LMGLPreviewView alloc] initWithFrame:self.view.bounds andContext:_ctx];
    [self.view addSubview:_previewView];
    _previewView.renderEngine = renderEngine;
#endif
    NSBundle *resBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"LMEffectResource" ofType:@"bundle"]];
    _resBundle = resBundle;

    _renderEngine = renderEngine;
    [self setupButtons];
    [self setupUI];
    [self setupAudioPlayer];
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
                 
                 @{@"tag":@(110), @"name": @"filter/filter0", @"title": @"滤镜1"},
                 @{@"tag":@(111), @"name": @"filter/filter1", @"title": @"滤镜2"},
                 @{@"tag":@(112), @"name": @"filter/filter2", @"title": @"滤镜3"},
                 @{@"tag":@(113), @"name": @"filter/filter3", @"title": @"滤镜4"},
                 @{@"tag":@(114), @"name": @"filter/filter4", @"title": @"滤镜5"},
                 ];
    
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
        [self.view addSubview:btn];
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
                           ];
    for (int i = 0; i < closeBtns.count; i ++) {
        NSDictionary *s = closeBtns[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(x, y, width, height);
        btn.tag = [s[@"tag"] integerValue];
        [btn setTitle:s[@"title"] forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(onClosePressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btn];
        y += height + 1;
        
        if (y + height > winHeight) {
            y = yStartPos;
            x += width + 1;
        }
    }
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
        [_renderEngine processPixelBuffer:pixelBuffer];
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
