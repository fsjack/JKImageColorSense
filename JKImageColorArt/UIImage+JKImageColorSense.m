//
//  UIImage+JKImageColorArt.m
//  JKImageColorArt
//
//  Created by Jackie CHEUNG on 14-1-7.
//  Copyright (c) 2014年 Jackie. All rights reserved.
//

#import "UIImage+JKImageColorSense.h"
#import "JKImageColorSense.h"
#import <objc/runtime.h>
@implementation UIImage (JKImageColorSense)

- (JKImageColorSense *)imageColorSense{
    static NSString *JKImageColorSenseAssociationKey = nil;
    JKImageColorSense *colorSense = objc_getAssociatedObject(self, &JKImageColorSenseAssociationKey);
    if(!colorSense){
        colorSense = [[JKImageColorSense alloc] initWithImage:self];
        objc_setAssociatedObject(self, &JKImageColorSenseAssociationKey, colorSense, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return colorSense;
}

- (UIColor *)backgroundColor{
    return [self.imageColorSense backgroundColor];
}

- (UIColor *)primaryColor{
    return [self.imageColorSense primaryColor];
}

- (UIColor *)secondaryColor{
    return [self.imageColorSense secondaryColor];
}
@end
