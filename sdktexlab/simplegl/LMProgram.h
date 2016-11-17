//
//  LMProgram.h
//  useframework
//
//  Created by lixin on 7/14/16.
//  Copyright © 2016 lxtap. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

@interface LMProgram : NSObject

+ (instancetype)programWithVS:(NSString*)vertexShader fs:(NSString*)fragmentShader;
- (void)use;
- (GLuint)addAttribute:(NSString*)name;
- (GLuint)addUniformAttribute:(NSString*)name;
- (GLuint)attributeIndex:(NSString*)name;
- (GLuint)uniformIndex:(NSString*)name;
@end
