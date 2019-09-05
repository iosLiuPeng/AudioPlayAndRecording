//
//  VoiceManager.m
//
//
//  Created by 刘鹏i on 2019/8/27.
//
//

#import "VoiceManager.h"
#import <AVFoundation/AVFoundation.h>

@interface VoiceManager () <AVAudioPlayerDelegate>
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSMutableDictionary *dictCompletion;///< 结束回调
@end

static VoiceManager *s_voiceManager = nil;

@implementation VoiceManager
#pragma mark - Lift Circle
+ (instancetype)sharedInstance
{
    static dispatch_once_t once_patch;
    dispatch_once(&once_patch, ^() {
        s_voiceManager = [[self alloc] init];
    });
    return s_voiceManager;
}

+(instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_voiceManager = [super allocWithZone:zone];
    });
    
    return s_voiceManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _dictCompletion = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - public
/// 播放
- (void)playWithPath:(NSString *)path completion:(void(^)(void))completion
{
    if (_player) {
        [self stop];
        _player = nil;
    } else {
        NSError *error = nil;
        AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&error];
        if (error == nil) {
            player.volume = 1;
            player.numberOfLoops = 0;
            player.delegate = self;
            
            [_dictCompletion setObject:completion forKey:path];
            
            _player = player;
            [_player prepareToPlay];
            [_player play];
        }
    }
}

- (void)stop
{
    [self stopWithPlayer:_player];
}

- (void)stopWithPlayer:(AVAudioPlayer *)player
{
    NSString *path = player.url.path;
    void(^completion)(void) = _dictCompletion[path];
    if (completion) {
        completion();
    }
    if (path.length) {
        [_dictCompletion removeObjectForKey:path];
    }
    
    if (player.isPlaying) {
        [player stop];
    }
    
    if (_player == player) {
        _player = nil;
    }
}

/// 音频时长
- (double)durationForAudio:(NSString *)path
{
    AVURLAsset *avUrl = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:path]];
    CMTime time = [avUrl duration];
    double second = CMTimeGetSeconds(time);
    return second;
}

#pragma mark - AVAudioPlayerDelegate
/// 播放停止
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self stopWithPlayer:player];
}

/// 解码失败
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError * __nullable)error
{
    [self stopWithPlayer:player];
}

@end
