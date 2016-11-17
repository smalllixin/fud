//
//  LMGLPreviewView.m
//  sdktexlab
//
//  Created by xin li on 7/28/16.
//  Copyright © 2016 faceu. All rights reserved.
//

#import "LMGLPreviewView.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "LMProgram.h"

#include <glm/vec3.hpp> // glm::vec3
#include <glm/vec4.hpp> // glm::vec4
#include <glm/mat4x4.hpp> // glm::mat4
#include <glm/gtc/matrix_transform.hpp> // glm::translate, glm::rotate, glm::scale, glm::perspective
#include <glm/gtc/constants.hpp> // glm::pi

#import <AVFoundation/AVFoundation.h>

NSString *const VideoVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 uniform mat4 Modelview;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = Modelview * position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
);

NSString *const VideoFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture, textureCoordinate);
 }
);


typedef struct LMVec3 {
    GLfloat x,y,z;
} LMVec3;

typedef struct LMVec2 {
    GLfloat x,y;
} LMVec2;

typedef struct {
    LMVec3 Position;
    LMVec2 TexCoord;
} Vertex;


const Vertex Vertices[] = {
    {{ 1, -1, 0}, {1, 1}},
    {{ 1,  1, 0}, {1, 0}},
    {{-1,  1, 0}, {0, 0}},
    {{-1, -1, 0}, {0, 1}},
};

const GLubyte Indices[] = {
    0, 1, 2,
    2, 3, 0
};

//rotate texture 90 degree
/*
 2        1
 
 3        0
 
 rotate 90 degree
 to
 3        2
 0        1
 */
/*
const Vertex Rotate90Vertices[] = {
    {{ 1, -1, 0}, {1, 0}},
    {{ 1,  1, 0}, {0, 0}},
    {{-1,  1, 0}, {0, 1}},
    {{-1, -1, 0}, {1, 1}},
};
 */

/*
 90 then mirror
 2     3
 1     0
 */
/*
const Vertex Rotate_90_Flip_Vertices[] = {
    {{ 1, -1, 0}, {1, 1}},
    {{ 1,  1, 0}, {0, 1}},
    {{-1,  1, 0}, {0, 0}},
    {{-1, -1, 0}, {1, 0}},
};
 */

#define USE_CORE_VIDEO_TEXTURE 1

@interface LMGLPreviewView()

@property (nonatomic, strong) LMGLContext *ctx;
@property (nonatomic, strong) LMProgram *program;
@end

@implementation LMGLPreviewView {
    GLuint _renderBuffer;
    GLuint _displayFrameBuffer;
    GLint _rbWidth;
    GLint _rbHeight;
    
#ifdef USE_CORE_VIDEO_TEXTURE
    CVOpenGLESTextureCacheRef _coreVideoTextureCache;
#else
    GLuint _videoTexture;
#endif
    GLuint _videoVertexBuffer;
    GLuint _videoIndiceBuffer;
    
    BOOL _uploadedTexture;
    
    dispatch_semaphore_t _frameRenderingSemaphore;
}

- (id)initWithFrame:(CGRect)frame andContext:(LMGLContext*)context {
    if (self = [super initWithFrame:frame]) {
        _ctx = context;
        _frameRenderingSemaphore = dispatch_semaphore_create(1);
        [self setupRenderFramebuffer];
        [context syncRunOnQueue:^{
            [_ctx setCurrentContext];
#ifndef USE_CORE_VIDEO_TEXTURE
            glGenTextures(1, &_videoTexture);
            glBindTexture(GL_TEXTURE_2D, _videoTexture);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
#endif
            _program = [LMProgram programWithVS:VideoVertexShaderString fs:VideoFragmentShaderString];
            [_program addAttribute:@"position"];
            [_program addAttribute:@"inputTextureCoordinate"];
            [_program addUniformAttribute:@"inputImageTexture"];
            [_program addUniformAttribute:@"ModelView"];
            
            [self setupVBO];
#ifdef USE_CORE_VIDEO_TEXTURE
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _ctx.c, NULL, &_coreVideoTextureCache);
            NSAssert(err == kCVReturnSuccess, @"cv err");
#endif
        }];
        [self render];
    }
    return self;
}

- (void)dealloc {
    [_ctx syncRunOnQueue:^{
        [_ctx setCurrentContext];
        glDeleteRenderbuffers(1, &_renderBuffer);
        glDeleteFramebuffers(1, &_displayFrameBuffer);
    }];
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)setupRenderFramebuffer {
    CAEAGLLayer *eaglLayer = (CAEAGLLayer*)self.layer;
    eaglLayer.opaque = YES;
    [_ctx syncRunOnQueue:^{
        glGenRenderbuffers(1, &_renderBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
        [_ctx.c renderbufferStorage:GL_RENDERBUFFER fromDrawable:eaglLayer];
        glGenFramebuffers(1, &_displayFrameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _displayFrameBuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
        glDisable(GL_DEPTH_TEST);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_rbWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_rbHeight);
    }];
}

- (void)setupVBO {
    glGenBuffers(1, &_videoVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _videoVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_videoIndiceBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _videoIndiceBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
}

- (void)render {
    [_ctx syncRunOnQueue:^{
        [_ctx setCurrentContext];
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);
        glViewport(0, 0, _rbWidth, _rbHeight);
        [_ctx.c presentRenderbuffer:GL_RENDERBUFFER];
    }];
}

- (void)renderSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (dispatch_semaphore_wait(_frameRenderingSemaphore, DISPATCH_TIME_NOW) != 0)
    {
        NSLog(@"drop frame");
        return;
    }
    CFRetain(sampleBuffer);
    [_ctx syncRunOnQueue:^{
        [_ctx setCurrentContext];
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
       
        glBindFramebuffer(GL_FRAMEBUFFER, _displayFrameBuffer);
#ifdef USE_CORE_VIDEO_TEXTURE
        
        GLuint _videoTexture;
        CVOpenGLESTextureRef videoTextureRef = NULL;
        
        CVReturn err;
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _coreVideoTextureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_RGBA, (int)width, (int)height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &videoTextureRef);
        _videoTexture = CVOpenGLESTextureGetName(videoTextureRef);
        
        glBindTexture(GL_TEXTURE_2D, _videoTexture);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
#else
        //bind texture
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _videoTexture);
        if (!_uploadedTexture) {
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(pixelBuffer));
            _uploadedTexture = YES;
        } else {
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, (int)width, (int)height, GL_BGRA, GL_UNSIGNED_BYTE, CVPixelBufferGetBaseAddress(pixelBuffer));
        }
#endif
        GLuint renderedTexId;
        if (_renderEngine) {
            [_renderEngine processTexture:_videoTexture size:CGSizeMake(width,height) outputTexture:&renderedTexId];
        } else {
            renderedTexId = _videoTexture;
        }
        
        [_program use];
        glBindFramebuffer(GL_FRAMEBUFFER, _displayFrameBuffer);
        
        glViewport(0, 0, _rbWidth, _rbHeight);
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, renderedTexId);
        
        glUniform1i([_program uniformIndex:@"inputImageTexture"], 0);
        
        //load vbo
        glBindBuffer(GL_ARRAY_BUFFER, _videoVertexBuffer);
        
        //upload params
        glVertexAttribPointer([_program attributeIndex:@"position"], 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
        glVertexAttribPointer([_program attributeIndex:@"inputTextureCoordinate"], 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*) (sizeof(LMVec3)));
        
        //calculate modelview
        glm::mat4 m;
        m = glm::rotate(m, glm::pi<float>()/2, glm::vec3(0.0f, 0.0f, -1.0f));
        //then flip
        m = glm::scale(m, glm::vec3(1, -1, 1));
        glUniformMatrix4fv([_program uniformIndex:@"Modelview"], 1, GL_FALSE, &m[0][0]);
        
        //render video
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _videoIndiceBuffer);
        glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
        
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        
        //render sprite engine
        //        [ss.director render];
        
        //refresh render buffer
        glBindFramebuffer(GL_FRAMEBUFFER, _displayFrameBuffer);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        [_ctx.c presentRenderbuffer:GL_RENDERBUFFER];
#ifdef USE_CORE_VIDEO_TEXTURE
        if (videoTextureRef != NULL) {
            CFRelease(videoTextureRef);
        }
#endif
        CFRelease(sampleBuffer);
        dispatch_semaphore_signal(_frameRenderingSemaphore);
    }];
}

//- (void)renderYuvPixelBuffer;

@end
