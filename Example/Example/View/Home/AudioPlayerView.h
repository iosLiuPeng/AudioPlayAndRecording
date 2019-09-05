//
//  AudioPlayerView.h
//
//
//  Created by 刘鹏i on 2019/9/3.
//  Copyright © 2019 . All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DynamicModel.h"

NS_ASSUME_NONNULL_BEGIN

IB_DESIGNABLE
@interface AudioPlayerView : UIView

- (void)configWithVoiceModel:(DynamicModel *)model;
@end

NS_ASSUME_NONNULL_END
