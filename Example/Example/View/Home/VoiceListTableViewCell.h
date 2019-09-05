//
//  VoiceListTableViewCell.h
//
//
//  Created by 刘鹏i on 2019/9/2.
//  Copyright © 2019 . All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DynamicModel.h"

NS_ASSUME_NONNULL_BEGIN


@interface VoiceListTableViewCell : UITableViewCell
- (void)configCellWithModel:(DynamicModel *)model;

@end

NS_ASSUME_NONNULL_END
