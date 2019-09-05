//
//  AudioManager.h
//
//
//  Created by 刘鹏i on 2019/9/3.
//
//  本地音频+网络音频播放

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AudioPlayStatus) {
    AudioPlayStatus_Unknown,        ///< 未开始、停止播放
    AudioPlayStatus_Preparation,    ///< 准备中
    AudioPlayStatus_Failed,         ///< 加载失败
    
    AudioPlayStatus_Pause,          ///< 手动暂停
    AudioPlayStatus_Playing,        ///< 播放中
    AudioPlayStatus_Buffering,      ///< 缓冲中
    AudioPlayStatus_End,            ///< 播放结束
};

@protocol AudioManagerDelegate <NSObject>
/// 播放状态改变
- (void)playStatusChanged:(AudioPlayStatus)status;
/// 更新播放进度
- (void)playProgressUpdated:(double)progress;
/// 更新缓存进度
- (void)cacheProgressUpdated:(double)progress;
/// 更新总时长
- (void)totalDurationUpdated:(double)seconds;
@end

@interface AudioManager : NSObject
@property (nonatomic, assign, readonly) AudioPlayStatus status; ///< 当前播放状态

@property (nonatomic, copy, readonly) NSString *voiceID;        ///< 音频ID (因为同一音频，可能有网络、本地来源，所以用一个ID区分是否为同一音频)
@property (nonatomic, strong, readonly) NSURL *url;             ///< 当前播放的音频源（网络、本地）
@property (nonatomic, weak, readonly) id<AudioManagerDelegate> delegate; ///< 代理对象

+ (instancetype)sharedInstance;

/// 配置并自动播放 (会自动判断，如果是第一次则重新播放，之后会调用play方法)
- (void)playAudio:(NSString *)voiceID url:(NSURL *)url delegate:(id<AudioManagerDelegate>)delegate;

/// 恢复接收状态 （当音频源相同，但是更换了接收代理对象时调用）
- (void)resumeReceivingStatue:(id<AudioManagerDelegate>)delegate;

/// 手动播放
- (void)play;

/// 手动暂停
- (void)pause;

/// 跳转到指定进度播放
- (void)jumpedToProgress:(double)progress;

@end

NS_ASSUME_NONNULL_END
