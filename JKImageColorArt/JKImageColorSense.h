//
//  JKImageColorArt.h
//  JKImageColorArt
//
//  Created by Jackie CHEUNG on 14-1-7.
//  Copyright (c) 2014年 Jackie. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JKImageColorSense : NSObject

- (id)initWithImage:(UIImage *)inputImage;

- (NSArray *)allPaletteColors;

@property (nonatomic, readwrite) NSInteger accuracy; //Defualt is 5;

@property (nonatomic, strong, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIColor *primaryColor;
@property (nonatomic, readonly) UIColor *secondaryColor;

@end
