//
//  JKViewController.m
//  JKImageColorArt
//
//  Created by Jackie CHEUNG on 14-1-7.
//  Copyright (c) 2014年 Jackie. All rights reserved.
//

#import "JKViewController.h"
#import "UIImage+JKImageColorSense.h"
#import "JKImageColorSense.h"

@interface JKViewController ()<UICollectionViewDataSource>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *sliderValueLabel;

@property (nonatomic, copy) NSArray *colors;

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) JKImageColorSense *colorSense;

@end

@implementation JKViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.image = [UIImage imageNamed:@"sixrules.jpg"];
    
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"Cell"];
    self.collectionView.dataSource = self;
    
    self.imageView.image = self.image;
    self.colorSense = [[JKImageColorSense alloc] initWithImage:self.image];
    
    [self.slider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    [self sliderDidChange:self.slider];
}

- (void)sliderDidChange:(UISlider *)slider{
    self.sliderValueLabel.text = @(slider.value).stringValue;
    self.colorSense.accuracy = slider.value;
    self.colors = [self.colorSense allPaletteColors];
    [self.collectionView reloadData];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.colors.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    cell.contentView.backgroundColor = self.colors[indexPath.row];
    return cell;
}


@end
