//
//  AudioManager.m
//
//
//  Created by 刘鹏i on 2019/9/3.
//  
//

#import "AudioManager.h"
#import <AVFoundation/AVFoundation.h>

@interface AudioManager ()
@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, assign) AudioPlayStatus status; ///< 当前播放状态
@property (nonatomic, copy) NSString *voiceID;        ///< 音频ID (因为同一音频，可能有网络、本地来源，所以用一个ID区分是否为同一音频)
@property (nonatomic, strong) NSURL *url;             ///< 当前播放的音频源（网络、本地）
@property (nonatomic, weak) id<AudioManagerDelegate> delegate; ///< 代理对象
@end

static AudioManager *s_audioManager = nil;

@implementation AudioManager
#pragma mark - Lift Circle
+ (instancetype)sharedInstance
{
    static dispatch_once_t once_patch;
    dispatch_once(&once_patch, ^() {
        s_audioManager = [[self alloc] init];
    });
    return s_audioManager;
}

+(instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_audioManager = [super allocWithZone:zone];
    });
    
    return s_audioManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _player = [[AVPlayer alloc] initWithPlayerItem:nil];
        
        //TODO: 因为player在单例中，所以就没做移除监听操作
        __weak typeof(self) weakSelf = self;
        // 设监听播放进度，设置频率是1秒30次
        [_player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 30.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
            [weakSelf observerPlayProgress:time];
        }];
        
        // 监听播放速率
        [_player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
        
        // 自动等待，以便缓冲足够播放一段时间
        if (@available(iOS 10.0, *)) {
            _player.automaticallyWaitsToMinimizeStalling = NO;
        }
    }
    return self;
}

#pragma mark - Public
/// 恢复接收状态 （当音频源相同，但是更换了接收代理对象时调用）
- (void)resumeReceivingStatue:(id<AudioManagerDelegate>)delegate
{
    _delegate = delegate;
    
    // 当前状态
    self.status = _status;
    
    // 当前播放进度
    [self observerPlayProgress:_player.currentTime];
    
    // 当前缓存进度
    [self observerCacheProgress:_player.currentItem];
    
    // 播放总时长
    if ([_delegate respondsToSelector:@selector(totalDurationUpdated:)]) {
        NSTimeInterval total = CMTimeGetSeconds(_player.currentItem.duration);
        [_delegate totalDurationUpdated:total];
    }
}

/// 播放
- (void)playAudio:(NSString *)voiceID url:(NSURL *)url delegate:(id<AudioManagerDelegate>)delegate
{
    if ([_voiceID isEqualToString:voiceID] == NO) {
        // 播放源不同，切换重播
        self.delegate = delegate;
        
        _voiceID = voiceID;
        _url = url;
        
        // 初始状态
        self.status = AudioPlayStatus_Unknown;
        [self resetProgress];

        AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:url];
        [self addItemObserver:item];
        
        [_player replaceCurrentItemWithPlayerItem:item];
        
        // 准备播放
        self.status = AudioPlayStatus_Preparation;
    } else {
        // 播放源相同
        if (_delegate != delegate) {
            // 只有代理不同，恢复播放
            [self resumeReceivingStatue:delegate];
        } else {
            // 全部相同，相当于手动点击一次继续播放
            [self play];
        }
    }
}

/// 手动播放
- (void)play
{
    switch (_status) {
        case AudioPlayStatus_Pause:
        case AudioPlayStatus_End:
            [self continuePlaying];
            break;
        case AudioPlayStatus_Failed:        // 失败后重试
        {
            [self stop];
            
            AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:_url];
            [self addItemObserver:item];
            
            [_player replaceCurrentItemWithPlayerItem:item];
            
            // 准备播放
            self.status = AudioPlayStatus_Preparation;
        }
            break;
        default:
            break;
    }
}

/// 手动暂停
- (void)pause
{
    switch (_status) {
        case AudioPlayStatus_Playing:
            self.status = AudioPlayStatus_Pause;
            [_player pause];
            break;
        default:
            break;
    }
}

/// 跳转到指定进度播放
- (void)jumpedToProgress:(double)progress
{
    if (progress < 0 || progress > 1) {
        return;
    }
    
    switch (_status) {
        case AudioPlayStatus_Pause:
        case AudioPlayStatus_Playing:
        case AudioPlayStatus_Buffering:
        case AudioPlayStatus_End:
        {
            self.status = AudioPlayStatus_Buffering;
            [_player pause];
            
            NSTimeInterval total = CMTimeGetSeconds(_player.currentItem.duration);
            NSTimeInterval seconds = progress * total;
            __weak typeof(self) weakSelf = self;
            [self.player seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
                if (finished) {
                    [weakSelf continuePlaying];
                }
            }];
        }
            break;
        default:
            break;
    }
}

#pragma mark - Private
/// 播放
- (void)continuePlaying
{
    switch (_status) {
        case AudioPlayStatus_Preparation:   // 正常从头开始
        case AudioPlayStatus_Pause:         // 继续播放
        case AudioPlayStatus_Buffering:     // 缓冲好了自动播放
            self.status = AudioPlayStatus_Playing;
            [_player play];
            break;
        case AudioPlayStatus_End:
            [self jumpedToProgress:0.0];
            break;
        default:
            break;
    }
}

/// 停止播放
- (void)stop
{
    [self removeItemObserver:_player.currentItem];
    
    [_player pause];
    [_player seekToTime:CMTimeMake(0, 1)];
    
    self.status = AudioPlayStatus_Unknown;
    [self resetProgress];
}

/// 重置所有进度为0
- (void)resetProgress
{
    if ([_delegate respondsToSelector:@selector(playProgressUpdated:)]) {
        [ _delegate playProgressUpdated:0.0];
    }
    if ([_delegate respondsToSelector:@selector(cacheProgressUpdated:)]) {
        [ _delegate cacheProgressUpdated:0.0];
    }
}


#pragma mark - Item Observer
/// 监听
- (void)addItemObserver:(AVPlayerItem *)item
{
    if (item) {
        // 播放状态
        [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        // 数据缓存状态
        [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        // 监听播放完成
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    }
}

/// 移除监听
- (void)removeItemObserver:(AVPlayerItem *)item
{
    if (item) {
        [item removeObserver:self forKeyPath:@"status" context:nil];
        [item removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    }
}

#pragma mark - Set
- (void)setDelegate:(id<AudioManagerDelegate>)delegate
{
    if (_delegate == delegate) {
        return;
    }
    
    [self stop];

    _delegate = delegate;
}

- (void)setStatus:(AudioPlayStatus)status
{
    _status = status;
    
    if ([_delegate respondsToSelector:@selector(playStatusChanged:)]) {
        [ _delegate playStatusChanged:status];
    }
//    NSLog(@"== AudioPlayStatus: %ld", status);
}

#pragma mark - Notification
- (void)playbackFinished:(NSNotification *)notice
{
    if (notice.object == _player.currentItem) {
        self.status = AudioPlayStatus_End;
        
        [self observerPlayProgress:_player.currentItem.duration];
    }
//    NSLog(@"===>> playbackFinished");
}


#pragma mark - Observer
/// 监听播放进度
- (void)observerPlayProgress:(CMTime)time
{
    NSTimeInterval current = CMTimeGetSeconds(time);
    NSTimeInterval total = CMTimeGetSeconds(_player.currentItem.duration);
    
    CGFloat progress = current / total;
    if ([_delegate respondsToSelector:@selector(playProgressUpdated:)]) {
        [ _delegate playProgressUpdated:progress];
    }
//    NSLog(@"== current:%lf total:%lf 进度:%f", current, total, progress);
}

/// 监听缓冲进度
- (void)observerCacheProgress:(AVPlayerItem *)item
{
    NSArray *array = item.loadedTimeRanges;
    CMTimeRange timeRange = [array.firstObject CMTimeRangeValue]; //本次缓冲的时间范围
    NSTimeInterval totalBuffer = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration); //缓冲总长度(是0开始的)
    
    NSTimeInterval total = CMTimeGetSeconds(_player.currentItem.duration);
    
    CGFloat progress = totalBuffer / total;
    
    if ([_delegate respondsToSelector:@selector(cacheProgressUpdated:)]) {
        [ _delegate cacheProgressUpdated:progress];
    }
//    NSLog(@"== start:%lf  durrantion:%lf  共缓冲%.2f 进度:%f", CMTimeGetSeconds(timeRange.start), CMTimeGetSeconds(timeRange.duration), totalBuffer, progress);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([object isKindOfClass:AVPlayerItem.class]) {
        AVPlayerItem *item = object;
        
        if ([keyPath isEqualToString:@"status"]) {
            // 监听播放状态
            switch (item.status) {
                case AVPlayerItemStatusUnknown: // 未知状态，此时不能播放
                    self.status = AudioPlayStatus_Unknown;
                    [self resetProgress];
                    NSLog(@"==KVO：未知状态，此时不能播放");
                    break;
                case AVPlayerItemStatusReadyToPlay: // 准备完毕，可以播放
                    // 退出程序一段时间，重新进来会此激活，为此状态
                    switch (_status) {
                        case AudioPlayStatus_Preparation:
                        case AudioPlayStatus_Playing:
                        {
                            [self continuePlaying];
                            
                            if ([_delegate respondsToSelector:@selector(totalDurationUpdated:)]) {
                                NSTimeInterval total = CMTimeGetSeconds(_player.currentItem.duration);
                                [_delegate totalDurationUpdated:total];
                            }
                        }
                            break;
                        default:
                            break;
                    }
                    NSLog(@"==KVO：准备完毕，可以播放");
                    break;
                case AVPlayerItemStatusFailed:  // 加载失败，网络或者服务器出现问题
                    self.status = AudioPlayStatus_Failed;
                    [self resetProgress];
                    NSLog(@"==KVO：加载失败，网络或者服务器出现问题");
                    break;
                default:
                    break;
            }
        } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            // 监听缓冲进度
            [self observerCacheProgress:item];
            
            // 缓冲后自动开始
            if (_status == AudioPlayStatus_Buffering) {
                NSTimeInterval current = CMTimeGetSeconds(_player.currentTime);
                
                NSArray *array = item.loadedTimeRanges;
                CMTimeRange timeRange = [array.firstObject CMTimeRangeValue]; //本次缓冲的时间范围
                NSTimeInterval start = CMTimeGetSeconds(timeRange.start);
                NSTimeInterval duration = CMTimeGetSeconds(timeRange.duration);
                NSTimeInterval totalBuffer = start + duration; //缓冲总长度(是0开始的)
                
                // 缓冲的数据可以听5秒
                if (duration > 0 && totalBuffer - current >= 5.0) {
                    [self continuePlaying];
                }
            }
        }
    }
    
    if ([object isKindOfClass:AVPlayer.class]) {
        AVPlayer *player = object;
        
        if ([keyPath isEqualToString:@"rate"]) {
            // 监听播放速率
            if (_status == AudioPlayStatus_Playing && player.rate == 0) {
                self.status = AudioPlayStatus_Buffering;
            }
//            NSLog(@"==KVO: 播放速率:%lf", player.rate);
        }
    }
    
    //        // ios10以后可以监听的播放状态
    //         if (@available(iOS 10.0, *)) {
    //             // _player.automaticallyWaitsToMinimizeStalling = YES 才有用
    //             [_player addObserver:self forKeyPath:@"timeControlStatus" options:NSKeyValueObservingOptionNew context:nil];
    //             self.player.timeControlStatus;     // 播放状态
    //             AVPlayerTimeControlStatusPaused;   // 暂停
    //             AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate; // 等待缓冲
    //             AVPlayerTimeControlStatusPlaying; // 播放中
    //         }
    //
    //        // ios10以后可以监听的等待状态时的原因
    //        if (@available(iOS 10.0, *)) {
    //            // _player.automaticallyWaitsToMinimizeStalling = YES 才有用
    //            [_player addObserver:self forKeyPath:@"reasonForWaitingToPlay" options:NSKeyValueObservingOptionNew context:nil];
    //            self.player.reasonForWaitingToPlay; // 等待原因(播放状态为等待缓冲时才有值，其余时候为nil)
    //            AVPlayerWaitingToMinimizeStallsReason;  // 正在等待缓冲
    //            AVPlayerWaitingWhileEvaluatingBufferingRateReason;  // 开始播放之前正在等待合适的缓冲区
    //            AVPlayerWaitingWithNoItemToPlayReason;  // 播放源item为nil
    //        }
}

#pragma mark - AVAssetResourceLoaderDelegate
///// 加载资源
//- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
//{
//    return YES;
//}
//
///// 取消加载资源
//- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
//{
//
//}

#pragma mark - Remote Control
/// 外部控制
//[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

//- (BOOL)canBecomeFirstResponder {
//    return YES;
//}

//- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
//    switch (event.subtype) {
//        case UIEventSubtypeRemoteControlPlay:
//            NSLog(@"remote_播放");
//            break;
//        case UIEventSubtypeRemoteControlPause:
//            [self.player pausePlay];
//            NSLog(@"remote_暂停");
//            break;
//        case UIEventSubtypeRemoteControlNextTrack:
//            [self.player playNextSong];
//            NSLog(@"remote_下一首");
//            break;
//        case UIEventSubtypeRemoteControlTogglePlayPause:
//            self.player.isPlaying ? [self.player pausePlay] : [self.player startPlay];
//            NSLog(@"remote_耳机的播放/暂停");
//            break;
//        default:
//            break;
//    }
//}

#pragma mark - Now Playing Center
/// 锁屏显示
//- (void)configNowPlayingCenter {
//    BASE_INFO_FUN(@"配置NowPlayingCenter");
//    NSMutableDictionary * info = [NSMutableDictionary dictionary];
//    //音乐的标题
//    [info setObject:_model.name forKey:MPMediaItemPropertyTitle];
//    //音乐的艺术家
//    [info setObject:_model.name forKey:MPMediaItemPropertyArtist];
//    //音乐的播放时间
//    [info setObject:@(self.player.playTime.intValue) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
//    //音乐的播放速度
//    [info setObject:@(1) forKey:MPNowPlayingInfoPropertyPlaybackRate];
//    //音乐的总时间
//    [info setObject:@(self.player.playDuration.intValue) forKey:MPMediaItemPropertyPlaybackDuration];
//    //音乐的封面
//    MPMediaItemArtwork * artwork = [[MPMediaItemArtwork alloc] initWithImage:_player.coverImg];
//    [info setObject:artwork forKey:MPMediaItemPropertyArtwork];
//    //完成设置
//    [[MPNowPlayingInfoCenter defaultCenter]setNowPlayingInfo:info];
//}

@end
