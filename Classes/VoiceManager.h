//
//  VoiceManager.h
//
//
//  Created by 刘鹏i on 2019/8/27.
//  
//  本地音频播放

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VoiceManager : NSObject
/// 实例化
+ (instancetype)sharedInstance;

/// 播放
- (void)playWithPath:(NSString *)path completion:(void(^)(void))completion;

/// 停止
- (void)stop;

/// 音频时长
- (double)durationForAudio:(NSString *)path;
@end

NS_ASSUME_NONNULL_END
