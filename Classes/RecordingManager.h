//
//  RecordingManager.h
//
//
//  Created by 刘鹏i on 2019/8/27.
//  
//  录音

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, RecordingStatus) {
    RecordingStatus_None,       ///< 未开始
    RecordingStatus_Recording,  ///< 录制中
    RecordingStatus_End,        ///< 结束
};

@interface RecordingManager : NSObject
/// 实例化
+ (instancetype)sharedInstance;

/// 开始录音
- (void)startRecording:(void(^)(BOOL success))completion;

/// 停止录音
- (void)stopRecording;

/// 移除当前录音
- (void)removeCurrentRecording;

/// 导出录音 返回路径
- (NSString *)exportVoice;

@end

NS_ASSUME_NONNULL_END
