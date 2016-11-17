//
//  LMProgram.m
//  useframework
//
//  Created by lixin on 7/14/16.
//  Copyright © 2016 lxtap. All rights reserved.
//

#import "LMProgram.h"

@implementation LMProgram {
    GLuint _program;
    NSMutableDictionary *attributes;
}


+ (instancetype)programWithVS:(NSString*)vertexShader fs:(NSString*)fragmentShader {
    NSString *vertexShaderString = vertexShader;
    NSString *fragmentShaderString = fragmentShader;
    return [[LMProgram alloc] initWithVS:vertexShaderString fs:fragmentShaderString];
}

- (id)initWithVS:(NSString*)vertextShader fs:(NSString*)fragmentShader {
    if (self = [super init]) {
        GLuint prog = glCreateProgram();
        compile_link(prog, [vertextShader UTF8String], [fragmentShader UTF8String]);
        _program = prog;
        attributes = [NSMutableDictionary dictionary];
    }
    return self;
}

- (GLuint)addAttribute:(NSString*)name {
    GLuint attributeSlot = glGetAttribLocation(_program, [name UTF8String]);
    attributes[name] = [NSNumber numberWithUnsignedInteger:attributeSlot];
    glEnableVertexAttribArray(attributeSlot);
    return attributeSlot;
}

- (GLuint)addUniformAttribute:(NSString*)name {
    GLuint attributeSlot = glGetUniformLocation(_program, [name UTF8String]);
    attributes[name] = [NSNumber numberWithUnsignedInteger:attributeSlot];
    return attributeSlot;
}

- (GLuint)attributeIndex:(NSString*)name {
    //todo
    // use glBindAttribLocation
    return glGetAttribLocation(_program, [name UTF8String]);
    //return (GLuint)[attributes[name] unsignedIntegerValue];
}

- (GLuint)uniformIndex:(NSString*)name {
    return glGetUniformLocation(_program, [name UTF8String]);
}

- (void)use {
    glUseProgram(_program);
}

static GLuint compileShader(const char* source, GLenum type) {
    GLint status;
    
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    
    if (status == GL_FALSE) {
        char buf[1024];
        GLint len;
        glGetShaderInfoLog(shader, 1024, &len, buf);
        
        NSLog(@"compile failed:%s\n"
                   "source:\n %s\n",
                   buf, source);
        glDeleteShader(shader);
        return 0;
    }
    
    return shader;
}

static int compile_link(GLuint prog, const char *vertexShader, const char *fragmentShader) {
    
    GLuint vs = compileShader(vertexShader, GL_VERTEX_SHADER);
    if (vs == 0) {
        return 0;
    }
    glAttachShader(prog, vs);
    
    GLuint fs = compileShader(fragmentShader, GL_FRAGMENT_SHADER);
    if (fs == 0) {
        return 0;
    }
    glAttachShader(prog, fs);
    
    if (link_prog(prog) == 0) {
        return 0;
    }
    glUseProgram(prog);
    return prog;
}

static int link_prog(GLuint prog) {
    glLinkProgram(prog);
    
    GLint status;
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        GLchar message[256];
        glGetProgramInfoLog(prog, sizeof(message), 0, &message[0]);
        NSString *messageString = [NSString stringWithUTF8String:message];
        NSLog(@"%@", messageString);
        return 0;
    }
    
    return prog;
}

@end
