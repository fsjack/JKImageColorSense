//
//  JKImageColorMap.m
//  JKImageColorSense
//
//  Created by Jackie CHEUNG on 14-1-10.
//  Copyright (c) 2014年 Jackie. All rights reserved.
//

#import "JKImageColorSenseCore.h"

static NSInteger const _JKImageColorSigbits         = 5;
static NSInteger const _JKImageColorRightShiftBits  = ( 8 - _JKImageColorSigbits );
static NSInteger const _JKImageColorMaxIterations   = 1000;

CGFloat const JKImageColorMapThresholdCompletion = 1.0f;
CGFloat const JKImageColorMapThresholdBackgroundColor = 0.5f;

struct __JKImageColorUnit {
    NSRange redRange;
    NSRange greenRange;
    NSRange blueRange;
    NSUInteger weight;
    NSUInteger volume;
};

struct __JKImageColorMap {
    JKImagePixel *pixels;
    NSInteger pixelCount;
    
    NSUInteger *colorMap;
    NSInteger colorMapLength;
};

NSUInteger JKImageColorUnitGetWeight(JKImageColorUnitRef box, JKImageColorMapRef map);
NSUInteger JKImageColorUnitGetVolume(JKImageColorUnitRef box);
NSUInteger JKImageColorUnitGetMedianCutPoint(JKImageColorUnitRef box,NSUInteger totalPixelCount,NSUInteger *partialPixelScattergram,NSRange colorRange);

JKImageColorUnitRef *JKImageColorUnitApplyMedianCut(JKImageColorUnitRef box, JKImageColorMapRef map);
JKImageColorUnitRef *JKImageColorUnitSortArrayByBoxWeight(JKImageColorUnitRef *boxes, NSInteger boxesLength);
JKImageColorUnitRef *JKImageColorUnitSortArrayByBoxWeightAndVolume(JKImageColorUnitRef *boxes, NSInteger boxesLength);

NS_INLINE NSUInteger JKImageColorMapGetColorIndex(NSInteger redIndex,NSInteger greenIndex,NSInteger blueIndex){
    NSUInteger colorIndex = (redIndex << (2 * _JKImageColorSigbits)) + (greenIndex << _JKImageColorSigbits) + blueIndex;
    return colorIndex;
}

JKImagePixel *JKImageColorMapGetPixels(CGImageRef imageRef, NSUInteger *pixelCount, CGFloat threshold){
    
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(imageRef));
    const UInt8* rawData = CFDataGetBytePtr(pixelData);
    
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    NSUInteger bytesPerPixel = 4;
    
    NSUInteger totalPixelCount = (NSUInteger)(width * height * threshold);
    *pixelCount = totalPixelCount;
    
    JKImagePixel *pixels = calloc(sizeof(struct JKImagePixel), totalPixelCount);
    
    for (int i = 0; i < (width * height * threshold); i++) {
        
        JKImagePixel *pixel = malloc(sizeof(struct JKImagePixel));
        pixel -> red = rawData[ (bytesPerPixel*i) ];
        pixel -> green = rawData[ (bytesPerPixel*i) + 1 ];
        pixel -> blue = rawData[ (bytesPerPixel*i) + 2 ];
        pixel -> alpha = rawData[ (bytesPerPixel*i) + 3 ];
        
        pixels[i] = *pixel;
    }

    return pixels;
}

NSUInteger *JKImageColorMapGetColorMap(JKImageColorMapRef mapRef,NSInteger *length){
    NSInteger colorMapLength = 1 << (3 * _JKImageColorSigbits);
    NSUInteger *colorMap = calloc(sizeof(NSUInteger), colorMapLength);
    *length = colorMapLength;
    
    for (NSUInteger index = 0 ; index < mapRef->pixelCount ; index++ ) {
        
        JKImagePixel pixel = mapRef -> pixels[index];
        
        NSInteger redIndex = pixel.red >> _JKImageColorRightShiftBits;
        NSInteger greenIndex = pixel.green >> _JKImageColorRightShiftBits;
        NSInteger blueIndex = pixel.blue >> _JKImageColorRightShiftBits;
        
        NSUInteger colorIndex = JKImageColorMapGetColorIndex(redIndex, greenIndex, blueIndex);
        colorMap[colorIndex] = colorMap[colorIndex] + 1;
    }
    
    return colorMap;
}

JKImageColorMapRef JKImageColorMapCreate(JKImagePixel *pixels,NSInteger pixelCount){
    
    if(!pixels || !pixelCount) return NULL;
    
    struct __JKImageColorMap *map = malloc(sizeof(struct __JKImageColorMap));
    map -> pixels = pixels;
    map -> pixelCount = pixelCount;
    
    NSInteger colorMapLength;
    NSUInteger *colorMap = JKImageColorMapGetColorMap(map,&colorMapLength);
    map->colorMap = colorMap;
    map->colorMapLength = colorMapLength;
    
    return map;
}

NSUInteger JKImageColorUnitGetMedianCutPoint(JKImageColorUnitRef box,NSUInteger totalPixelCount,NSUInteger *partialPixelScattergram,NSRange colorRange){
    
    NSUInteger *restPixelScattergram = calloc(sizeof(NSUInteger), (1 << _JKImageColorSigbits));
    for (NSInteger index = 0; index < (1 << _JKImageColorSigbits); index++) {
        restPixelScattergram[index] = totalPixelCount - partialPixelScattergram[index];
    }
    
    NSInteger index;
    for (index = colorRange.location; index < colorRange.location + colorRange.length; index++)
        if(partialPixelScattergram[index] > totalPixelCount/2) break;
    
    NSInteger left = index - colorRange.location;
    NSInteger right = (colorRange.location + colorRange.length) - index;
    
    NSInteger cutPoint;
    if(left <= right)
        cutPoint = MIN((colorRange.location + colorRange.length) - 1, (index + right / 2) );
    else
        cutPoint = MAX(colorRange.location , (index - 1 - left / 2) );
    
    while (!partialPixelScattergram[cutPoint]) cutPoint++;
    
    NSInteger count = restPixelScattergram[cutPoint];
    while (!count && restPixelScattergram[cutPoint-1]) {
        --cutPoint;
        count = restPixelScattergram[cutPoint];
    }
    
    cutPoint = cutPoint < 0 ? 0 : cutPoint;
    
    return cutPoint;
}

JKImageColorUnitRef *JKImageColorUnitApplyMedianCut(JKImageColorUnitRef box, JKImageColorMapRef map){
    
    JKImageColorUnitRef *colorBoxes = malloc(sizeof(size_t) * 2);
    
    NSRange redRange = box->redRange;
    NSRange greenRange = box->greenRange;
    NSRange blueRange = box->blueRange;
    
    NSInteger redDiff = redRange.length;
    NSInteger greenDiff = greenRange.length;
    NSInteger blueDiff = blueRange.length;
    
    NSInteger maxDiff = MAX(MAX(redDiff, greenDiff), blueDiff);
    
    // only one pixel, no split. JKColorBox should implement <NSCopying> protocol.
    if (box->weight == 1) {
        colorBoxes[0] = JKImageColorUnitCopy(box,map);
        return colorBoxes;
    }
    
    /* Find the partial sum arrays along the selected axis. */
    NSUInteger totalPixelCount = map->pixelCount;
    NSUInteger *partialPixelScattergram = calloc(sizeof(NSUInteger), (1 << _JKImageColorSigbits));
    
    struct __JKImageColorUnit *box1 = (struct __JKImageColorUnit *)JKImageColorUnitCopy(box, map);
    struct __JKImageColorUnit *box2 = (struct __JKImageColorUnit *)JKImageColorUnitCopy(box, map);
    
    if(maxDiff == redDiff){
        for (NSInteger redIndex = redRange.location; redIndex <= redRange.location + redRange.length; redIndex++) {
            NSUInteger pixelCount = 0;
            for (NSInteger greenIndex = greenRange.location; greenIndex <= greenRange.location + greenRange.length; greenIndex++) {
                for (NSInteger blueIndex = blueRange.location; blueIndex <= blueRange.location + blueRange.length; blueIndex++) {
                    NSUInteger colorIndex = JKImageColorMapGetColorIndex(redIndex, greenIndex, blueIndex);
                    pixelCount = pixelCount + map->colorMap[colorIndex];
                }
            }
            partialPixelScattergram[redIndex] = totalPixelCount;
        }
        
        NSUInteger cutPoint = JKImageColorUnitGetMedianCutPoint(box,totalPixelCount,partialPixelScattergram,redRange);
        
        box1->redRange.length = cutPoint - box1->redRange.location;
        
        box2->redRange.length = box2->redRange.length - ((cutPoint + 1) - box2->redRange.location);
        box2->redRange.location = cutPoint + 1;
        
    }else if(maxDiff == greenDiff){
        
        for (NSInteger greenIndex = greenRange.location; greenIndex <= greenRange.location + greenRange.length; greenIndex++) {
            NSUInteger pixelCount = 0;
            for (NSInteger redIndex = redRange.location; redIndex <= redRange.location + redRange.length; redIndex++) {
                for (NSInteger blueIndex = blueRange.location; blueIndex <= blueRange.location + blueRange.length; blueIndex++) {
                    NSUInteger colorIndex = JKImageColorMapGetColorIndex(redIndex, greenIndex, blueIndex);
                    pixelCount = pixelCount + map->colorMap[colorIndex];
                }
            }
            partialPixelScattergram[greenIndex] = totalPixelCount;
        }
        
        NSUInteger cutPoint = JKImageColorUnitGetMedianCutPoint(box,totalPixelCount,partialPixelScattergram,greenRange);
        
        box1->greenRange.length = cutPoint - box1->greenRange.location;
        box2->greenRange.length = box2->greenRange.length - ((cutPoint + 1) - box2->greenRange.location);
        box2->greenRange.location = cutPoint + 1;
        
    }else if(maxDiff == blueDiff){
        for (NSInteger blueIndex = blueRange.location; blueIndex <= blueRange.location + blueRange.length; blueIndex++) {
            NSUInteger pixelCount = 0;
            for (NSInteger redIndex = redRange.location; redIndex <= redRange.location + redRange.length; redIndex++) {
                for (NSInteger greenIndex = greenRange.location; greenIndex <= greenRange.location + greenRange.length; greenIndex++) {
                    
                    NSUInteger colorIndex = JKImageColorMapGetColorIndex(redIndex, greenIndex, blueIndex);
                    pixelCount = pixelCount + map->colorMap[colorIndex];
                }
            }
            partialPixelScattergram[blueIndex] = totalPixelCount;
        }
        
        NSUInteger cutPoint = JKImageColorUnitGetMedianCutPoint(box,totalPixelCount,partialPixelScattergram,blueRange);
        
        box1->blueRange.length = cutPoint - box1->blueRange.location;
        box2->blueRange.length = box2->blueRange.length - ((cutPoint + 1) - box2->blueRange.location);
        box2->blueRange.location = cutPoint + 1;
    }
    
    box1->weight = JKImageColorUnitGetWeight(box1, map);
    box1->volume = JKImageColorUnitGetVolume(box1);
    
    box2->weight = JKImageColorUnitGetWeight(box2, map);
    box2->volume = JKImageColorUnitGetVolume(box2);
    
    colorBoxes[0] = box1;
    colorBoxes[1] = box2;
    
    return colorBoxes;
}

JKImageColorUnitRef *JKImageColorUnitSortArrayByBoxWeight(JKImageColorUnitRef *boxes, NSInteger boxesLength){
    
    for (NSInteger i = 0; i < boxesLength; i++) {
        for (NSInteger j = boxesLength - 1; j > i; j--) {
            
            JKImageColorUnitRef box1 = boxes[j];
            JKImageColorUnitRef box2 = boxes[j-1];
            
            if (box1->weight < box2->weight) {
                boxes[j-1] = box1;
                boxes[j]   = box2;
            }
        }
    }

    return boxes;
}

JKImageColorUnitRef *JKImageColorUnitSortArrayByBoxWeightAndVolume(JKImageColorUnitRef *boxes, NSInteger boxesLength){
    for (NSInteger i = 0; i < boxesLength; i++) {
        for (NSInteger j = boxesLength - 1; j > i; j--) {
            
            JKImageColorUnitRef box1 = boxes[j];
            JKImageColorUnitRef box2 = boxes[j-1];
            
            if((box2->weight * box2->volume) < (box1->weight * box1->volume)) {
                boxes[j-1] = box1;
                boxes[j]   = box2;
            }
        }
    }
    return boxes;
}

CGColorRef JKImageColorUnitGetAverageColor(JKImageColorUnitRef box,JKImageColorMapRef map){
    
    NSUInteger totalPixelsCount = 0;
    NSInteger multplyFactor = 1 << _JKImageColorRightShiftBits;
    
    NSUInteger redSumValue = 0;
    NSUInteger greenSumValue = 0;
    NSUInteger blueSumValue = 0;
    
    CGColorRef averageColorRef;
    
    NSRange redRange = box->redRange;
    NSRange greenRange = box->greenRange;
    NSRange blueRange = box->blueRange;
    
    for (NSInteger redIndex = redRange.location; redIndex <= redRange.location + redRange.length; redIndex++) {
        for (NSInteger greenIndex = greenRange.location; greenIndex <= greenRange.location + greenRange.length; greenIndex++) {
            for (NSInteger blueIndex = blueRange.location; blueIndex <= blueRange.location + blueRange.length; blueIndex++) {
                
                NSUInteger colorIndex = JKImageColorMapGetColorIndex(redIndex,greenIndex,blueIndex);
                
                NSUInteger pixelsCount = map->colorMap[colorIndex];
                totalPixelsCount += pixelsCount;
                
                redSumValue += (pixelsCount * (redIndex + 0.5) * multplyFactor);
                greenSumValue += (pixelsCount * (greenIndex + 0.5) * multplyFactor);
                blueSumValue += (pixelsCount * (blueIndex + 0.5) * multplyFactor);
            }
        }
    }
    
    CGFloat redValue,greenValue,blueValue;
    if (totalPixelsCount) {
        
        redValue = (redSumValue / totalPixelsCount) / 255.f;
        greenValue = (greenSumValue / totalPixelsCount) / 255.f;
        blueValue = (blueSumValue / totalPixelsCount) / 255.f;
        
    } else {
        
        redValue = (multplyFactor * (redRange.location*2 + redRange.length) / 2)/255.f;
        greenValue = (multplyFactor * (greenRange.location*2 + greenRange.length) / 2)/255.f;
        blueValue = (multplyFactor * (blueRange.location*2 + blueRange.length) / 2)/255.f;
        
    }
    
    CGFloat components[4] = { redValue , greenValue , blueValue, 1.0 };
    averageColorRef = CGColorCreate(CGColorSpaceCreateDeviceRGB(), components);
    
    return averageColorRef;
}

CGColorRef *JKImageColorMapGetPaletteColors(JKImageColorMapRef map, NSInteger paletteColorCount){
    
    JKImageColorUnitRef colorBox = JKImageColorUnitCreate(map);
    
    JKImageColorUnitRef *colorBoxes = calloc(sizeof(size_t), paletteColorCount);
    colorBoxes[0] = colorBox;
    NSInteger boxCount = 1;
    
    for (NSInteger index = 0; index < _JKImageColorMaxIterations; index++) {
        colorBoxes = JKImageColorUnitSortArrayByBoxWeight( colorBoxes , boxCount );
        JKImageColorUnitRef lastColorBox = colorBoxes[ boxCount-1 ];
        
        if(lastColorBox -> weight) {
            colorBoxes[ boxCount-1 ] = NULL;
            boxCount = boxCount - 1;
        }else continue;
        
        JKImageColorUnitRef *result = JKImageColorUnitApplyMedianCut(lastColorBox , map);
        JKImageColorUnitRef colorBox1 = result[0];
        JKImageColorUnitRef colorBox2 = result[1];
        
        colorBoxes[boxCount] = colorBox1;
        colorBoxes[boxCount + 1] = colorBox2;
        boxCount = boxCount + 2;
        
        if(boxCount >= paletteColorCount) break;
    }
    
    CGColorRef *paletteColor = calloc(sizeof(size_t), paletteColorCount);
    colorBoxes = JKImageColorUnitSortArrayByBoxWeight(colorBoxes,boxCount);
    
    for (NSInteger index = 0; index < boxCount; index++) {
        JKImageColorUnitRef box = colorBoxes[index];
        paletteColor[index] = JKImageColorUnitGetAverageColor(box, map);
    }
    
    return paletteColor;
}

NSUInteger JKImageColorUnitGetWeight(JKImageColorUnitRef box, JKImageColorMapRef map){
    NSUInteger weight = 0;
    
    NSRange redRange = box -> redRange;
    NSRange greenRange = box -> greenRange;
    NSRange blueRange = box -> blueRange;
    
    for (NSInteger redIndex = redRange.location; redIndex <= redRange.location + redRange.length; redIndex++) {
        for (NSInteger greenIndex = greenRange.location; greenIndex <= greenRange.location + greenRange.length; greenIndex++) {
            for (NSInteger blueIndex = blueRange.location; blueIndex <= blueRange.location + blueRange.length; blueIndex++) {
                
                NSUInteger colorIndex =  JKImageColorMapGetColorIndex(redIndex, greenIndex, blueIndex);
                weight += map->colorMap[colorIndex];
            }
        }
    }
    return weight;
}

NSUInteger JKImageColorUnitGetVolume(JKImageColorUnitRef box){
    
    NSRange redRange = box -> redRange;
    NSRange greenRange = box -> greenRange;
    NSRange blueRange = box -> blueRange;
    
    return redRange.length * greenRange.length * blueRange.length;
}

JKImageColorUnitRef JKImageColorUnitCopy(JKImageColorUnitRef box, JKImageColorMapRef map){
    struct __JKImageColorUnit *copiedBox = malloc(sizeof(struct __JKImageColorUnit));
    copiedBox -> redRange = box -> redRange;
    copiedBox -> greenRange = box -> greenRange;
    copiedBox -> blueRange = box -> blueRange;
    
    copiedBox -> weight = box -> weight;
    copiedBox -> volume = box -> volume;
    
    return copiedBox;
}

JKImageColorUnitRef JKImageColorUnitCreate(JKImageColorMapRef map){
    
    if(!map) return NULL;
    
    NSUInteger rmin = NSUIntegerMax;
    NSUInteger rmax = 0;
    
    NSUInteger gmin = NSUIntegerMax;
    NSUInteger gmax = 0;
    
    NSUInteger bmin = NSUIntegerMax;
    NSUInteger bmax = 0;
    
    for (NSUInteger index = 0; index < map->pixelCount; index++ ) {
        
        JKImagePixel pixel = map -> pixels[index];
        
        NSInteger redIndex   = pixel.red >> _JKImageColorRightShiftBits;
        NSInteger greenIndex = pixel.green >> _JKImageColorRightShiftBits;
        NSInteger blueIndex  = pixel.blue >> _JKImageColorRightShiftBits;
        
        if (redIndex < rmin) rmin = redIndex;
        else if (redIndex > rmax) rmax = redIndex;
        
        if (greenIndex < gmin) gmin = greenIndex;
        else if (greenIndex > gmax) gmax = greenIndex;
        
        if (blueIndex < bmin) bmin = blueIndex;
        else if (blueIndex > bmax)  bmax = blueIndex;
    }
    
    struct __JKImageColorUnit *colorBox = malloc(sizeof(struct __JKImageColorUnit));
    colorBox -> redRange = NSMakeRange(rmin, rmax - rmin);
    colorBox -> greenRange = NSMakeRange(gmin, gmax - gmin);
    colorBox -> blueRange = NSMakeRange(bmin, bmax - bmin);
    
    colorBox -> weight = JKImageColorUnitGetWeight( colorBox , map );
    colorBox -> volume = JKImageColorUnitGetVolume( colorBox );
    
    return colorBox;
}
