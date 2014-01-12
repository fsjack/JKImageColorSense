//
//  JKImageColorMap.h
//  JKImageColorSense
//
//  Created by Jackie CHEUNG on 14-1-10.
//  Copyright (c) 2014年 Jackie. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef const struct __JKImageColorUnit * JKImageColorUnitRef;
typedef const struct __JKImageColorMap * JKImageColorMapRef;

extern CGFloat const JKImageColorMapThresholdCompletion;
extern CGFloat const JKImageColorMapThresholdBackgroundColor;

typedef struct JKImagePixel {
    NSInteger red;
    NSInteger green;
    NSInteger blue;
    NSInteger alpha;
} JKImagePixel;

extern JKImagePixel *JKImageColorMapGetPixels(CGImageRef imageRef, NSUInteger *pixelCount, CGFloat threshold);

extern JKImageColorMapRef JKImageColorMapCreate(JKImagePixel *pixels,NSInteger pixelCount);

extern NSUInteger *JKImageColorMapGetColorMap(JKImageColorMapRef coreRef,NSInteger *length);

extern CGColorRef *JKImageColorMapGetPaletteColors(JKImageColorMapRef core, NSInteger paletteColorCount);

extern JKImageColorUnitRef JKImageColorUnitCreate(JKImageColorMapRef core);

extern JKImageColorUnitRef JKImageColorUnitCopy(JKImageColorUnitRef box, JKImageColorMapRef core);

extern CGColorRef JKImageColorUnitGetAverageColor(JKImageColorUnitRef box,JKImageColorMapRef core);