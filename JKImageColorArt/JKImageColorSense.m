//
//  JKImageColorArt.m
//  JKImageColorArt
//
//  Created by Jackie CHEUNG on 14-1-7.
//  Copyright (c) 2014年 Jackie. All rights reserved.
//

#import "JKImageColorSense.h"
#import "JKImageColorSenseCore.h"

static NSInteger const _DefaultJKImageColorSenseAccuracy = 5;
static NSInteger const _JKImageColorSenseBackgroundColorAccuracy = 4;

@interface JKImageColorSense ()
@property (nonatomic, strong) NSArray *paletteColors;
@property (nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic, weak) UIImage *image;
@end

@implementation JKImageColorSense

- (id)initWithImage:(UIImage *)inputImage{
    self = [super init];
    if(self){
        self.image = inputImage;
        self.accuracy = _DefaultJKImageColorSenseAccuracy;
    }
    return self;
}

- (NSUInteger)color:(UIColor *)mainColor distanceWithBackgroundColor:(UIColor *)bgColor{
    
    CGFloat redA,greenA,blueA;
    CGFloat redB,greenB,blueB;
    
    [bgColor getRed:&redA green:&greenA blue:&blueA alpha:nil];
    [mainColor getRed:&redB green:&greenB blue:&blueB alpha:nil];
    
    redA = redA * 255;
    greenA = greenA * 255;
    blueA = blueA*255;
    
    redB = redB * 255;
    greenB = greenB * 255;
    blueB = blueB * 255;
    
    return powf( (redA-redB), 2) + powf((greenA-greenB), 2) + powf((blueA-blueB), 2);
}

- (NSArray *)allPaletteColors{
    return self.paletteColors;
}

- (void)setAccuracy:(NSInteger)accuracy{
    if(_accuracy != accuracy){
        _accuracy = accuracy;
        _paletteColors = nil;
    }
}

- (NSArray *)paletteColors{
    if(!_paletteColors){
        
        NSUInteger pixelCount;
        JKImagePixel *pixels = JKImageColorMapGetPixels(self.image.CGImage, &pixelCount, JKImageColorMapThresholdCompletion);
        JKImageColorMapRef coreRef = JKImageColorMapCreate(pixels, pixelCount);
        CGColorRef *colors = JKImageColorMapGetPaletteColors(coreRef, self.accuracy);
        
        NSMutableArray *paletteColors = [NSMutableArray array];
        for (NSInteger index = 0; index < self.accuracy; index++) {
            UIColor *color = [UIColor colorWithCGColor:colors[index]];
            [paletteColors addObject:color];
        }
        
        _paletteColors = paletteColors;
    }
    return _paletteColors;
}

- (UIColor *)backgroundColor{
    if(!_backgroundColor){
        
        NSUInteger pixelCount;
        JKImagePixel *pixels = JKImageColorMapGetPixels(self.image.CGImage, &pixelCount, JKImageColorMapThresholdBackgroundColor);
        JKImageColorMapRef coreRef = JKImageColorMapCreate(pixels, pixelCount);
        CGColorRef *colors = JKImageColorMapGetPaletteColors(coreRef, _JKImageColorSenseBackgroundColorAccuracy);
        
        NSMutableArray *paletteColors = [NSMutableArray array];
        for (NSInteger index = 0; index < _JKImageColorSenseBackgroundColorAccuracy; index++) {
            UIColor *color = [UIColor colorWithCGColor:colors[index]];
            [paletteColors addObject:color];
        }
        
        _backgroundColor = paletteColors.lastObject;
    }
    return _backgroundColor;
}

- (NSArray *)sortColorsWithColorDistanceCompareWithColor:(UIColor *)backgroundColor{
    NSMutableDictionary *colorDistances = [NSMutableDictionary dictionary];
    for (UIColor *color in self.paletteColors) {
        CGFloat colorDistance = [self color:color distanceWithBackgroundColor:backgroundColor];
        colorDistances[color] = @(colorDistance);
    }
    return [colorDistances keysSortedByValueUsingSelector:@selector(compare:)];
}

- (UIColor *)primaryColor{
    if(!self.paletteColors.count) return nil;    
    return [self sortColorsWithColorDistanceCompareWithColor:self.backgroundColor].lastObject;
}

- (UIColor *)secondaryColor{
    if(!self.paletteColors.count) return nil;
    NSArray *colors = [self sortColorsWithColorDistanceCompareWithColor:self.backgroundColor];
    return colors.count < 2 ? colors.lastObject : colors[colors.count-2];
}

@end
