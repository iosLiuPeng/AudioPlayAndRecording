//
//  VoiceListTableViewCell.m
//
//
//  Created by 刘鹏i on 2019/9/2.
//  Copyright © 2019 . All rights reserved.
//

#import "VoiceListTableViewCell.h"
#import "AudioPlayerView.h"

@interface VoiceListTableViewCell ()
@property (strong, nonatomic) IBOutlet AudioPlayerView *viewPlay;
@property (nonatomic, strong) DynamicModel *model;
@end

@implementation VoiceListTableViewCell
#pragma mark - Life Cycle
- (void)configCellWithModel:(DynamicModel *)model
{
    _model = model;
    
    [_viewPlay configWithVoiceModel:_model];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
}


@end
