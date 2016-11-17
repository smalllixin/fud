//
//  LMRenderEngineNotifications.h
//  facekit
//
//  Created by xin li on 8/22/16.
//  Copyright © 2016 faceu. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef struct lm_ext_face {
    CGPoint points[106];
    int sampleImageWidth;
    int sampleImageHeight;
} lm_ext_face;

typedef struct lm_ext_faces {
    lm_ext_face faces[5];
    int count;
} lm_ext_faces;

typedef NS_OPTIONS(NSUInteger, LMSmallMode) {
    kLMSmallModeOff,
    kLMSmallModeSpriteOut,
    kLMSmallModeFrame,
};

#define kLMNotifyUserInfoKey @"data"

#define kLMShowTipsNotification @"kLMShowTipsNotification"

@interface LMShowTipsNotification : NSObject

@property (nonatomic, assign) NSInteger durationSecond;
@property (nonatomic, copy) NSString *text;

@end

#define kLMPlayAudioNotification @"kLMPlayAudioNotification"

@interface LMPlayAudioNotification : NSObject

@property (nonatomic, assign) BOOL doPlay;
@property (nonatomic, assign) BOOL forceRestart;
@property (nonatomic, copy) NSString *audioPath;
@property (nonatomic, assign) BOOL repeat;

@end

#define kLMFaceRequireAlertNotification @"kLMFaceRequireAlertNotification"


#define kLMExchCloneFaceTipsNotification    @"kLMExchCloneFaceTipsNotification"

typedef enum : NSUInteger {
    kLMExchangeFaceTypeClone,
    kLMExchangeFaceTypeDouble,
} LMExchangeFaceType;

@interface LMExchCloneFaceNotification : NSObject

@property (nonatomic, assign) LMExchangeFaceType filterType;
@property (nonatomic, assign) UIInterfaceOrientation orientation;
@property (nonatomic, assign) BOOL show;

@end


