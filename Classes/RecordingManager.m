//
//  RecordingManager.m
//
//
//  Created by 刘鹏i on 2019/8/27.
//
//

#import "RecordingManager.h"
#import "lame.h"
#import <AVFoundation/AVFoundation.h>

@interface RecordingManager ()
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, assign) RecordingStatus status;
@property (nonatomic, copy) NSString *savePath;
@property (nonatomic, copy) void(^completion)(BOOL success);
@end

static RecordingManager *s_recordingManager = nil;

#define kRecordingDictionary @"Recording" ///< 录音存储目录

@implementation RecordingManager
#pragma mark - Lift Circle
+ (instancetype)sharedInstance
{
    static dispatch_once_t once_patch;
    dispatch_once(&once_patch, ^() {
        s_recordingManager = [[self alloc] init];
    });
    return s_recordingManager;
}

+(instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_recordingManager = [super allocWithZone:zone];
    });
    
    return s_recordingManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {

    }
    return self;
}

#pragma mark - Public
/// 开始录音
- (void)startRecording:(void(^)(BOOL success))completion;
{
    if ([self checkAuthorization] == NO) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    
    // 移除缓存数据
    [self removeCurrentRecording];

    _completion = completion;
    
    // 开始录制
    [self setAudioSession];
    [self.recorder prepareToRecord];
    [self.recorder record];
    
    _status = RecordingStatus_Recording;
    
    // 边录边转
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self conventToMp3];
    });
}

/// 停止录音
- (void)stopRecording
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    [self.recorder stop];
    
    _status = RecordingStatus_End;
}

/// 导出录音 返回路径
- (NSString *)exportVoice
{
    return _savePath;
}

/// 移除当前录音
- (void)removeCurrentRecording
{
    NSFileManager *manager = [NSFileManager defaultManager];
    
    if ([manager fileExistsAtPath:[self cafPath]]) {
        [manager removeItemAtPath:[self cafPath] error:nil];
    }
    
    if ([manager fileExistsAtPath:[self mp3Path]]) {
        [manager removeItemAtPath:[self mp3Path] error:nil];
    }
}

#pragma mark - Private
- (AVAudioRecorder *)recorder {
    if (!_recorder) {
        NSError *recorderSetupError = nil;
        _recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:[self cafPath]]
                                                settings:[self audioRecorderSettings]
                                                   error:&recorderSetupError];
        if (recorderSetupError) {
            return nil;
        }
    }
    return _recorder;
}

/// 设置音频会话
- (void)setAudioSession {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession setActive:YES error:nil];
}

/// 录音设置
- (NSDictionary *)audioRecorderSettings {
    return @{AVFormatIDKey  :  @(kAudioFormatLinearPCM), //录音格式
             AVSampleRateKey : @(11025.0),              //采样率
             AVNumberOfChannelsKey : @2,                //通道数
             AVEncoderBitDepthHintKey : @16,            //比特率
             AVEncoderAudioQualityKey : @(AVAudioQualityHigh)}; //声音质量
}

/// 检查授权
- (BOOL)checkAuthorization
{
    // 判断授权状态
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (authStatus) {
        case AVAuthorizationStatusNotDetermined:
            // 用户还没有做出选择
        {
//            // 弹框请求用户授权, 会让程序失活, 会触发广告 -> 强制屏蔽一次广告
//            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
//                if (granted) {
//
//                }
//            }];
            
            AVAudioSession *session = [AVAudioSession sharedInstance];
            [session requestRecordPermission:^(BOOL granted) {
                
            }];
        }
            break;
        case AVAuthorizationStatusRestricted:
        case AVAuthorizationStatusDenied:
            // 限制、不允许
        {
            [MJAlertManager showAlertWithTitle:nil message:locString(@"recording_message") cancel:locString(@"recording_cancel") confirm:locString(@"recording_ok") completion:^(NSInteger selectIndex) {
                if (selectIndex == 1) {
                    if (@available(iOS 10.0, *)) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                    } else {
                        NSURL *url= [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                        if( [[UIApplication sharedApplication] canOpenURL:url] ) {
                            if (@available(iOS 10.0, *)) {
                                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
                            } else {
                                [[UIApplication sharedApplication] openURL:url];
                            }
                        }
                    }
                }
            }];
        }
            break;
        case AVAuthorizationStatusAuthorized:
            // 允许
        {
            return YES;
        }
            break;
        default:
            break;
    }
    
    return NO;
}

#pragma mark - Path
- (NSString *)cafPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"tmpRecording.caf"];
}

- (NSString *)mp3Path {
    return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) firstObject] stringByAppendingPathComponent:@"tmpRecording.mp3"];
}

- (NSString *)randomPath {
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES) firstObject] stringByAppendingPathComponent:kRecordingDictionary];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *fileName = [NSString stringWithFormat:@"%.0f.mp3", [NSDate date].timeIntervalSince1970];
    NSString *savePath = [path stringByAppendingPathComponent:fileName];
    return savePath;
}

#pragma mark - Convert to mp3
- (void)conventToMp3 {
    NSString *cafFilePath = [self cafPath];
    NSString *mp3FilePath = [self mp3Path];
    
    @try{
        int read, write;
        FILE *pcm = fopen([cafFilePath cStringUsingEncoding:NSASCIIStringEncoding], "rb");
        FILE *mp3 = fopen([mp3FilePath cStringUsingEncoding:NSASCIIStringEncoding], "wb");
        
        const int PCM_SIZE = 8192;
        const int MP3_SIZE = 8192;
        short int pcm_buffer[PCM_SIZE * 2];
        unsigned char mp3_buffer[MP3_SIZE];
        
        lame_t lame = lame_init();
        lame_set_num_channels(lame,2);//通道
        lame_set_in_samplerate(lame, 11025.0);//采样率
        lame_set_brate(lame, 16);//比特率
        lame_set_quality(lame, 2);//音质
        lame_set_mode(lame, 3);
        lame_init_params(lame);
        
        long curpos;
        BOOL isSkipPCMHeader =NO;
        long startPos = 0;
        long endPos = 0;
        do {
            curpos = ftell(pcm);
            startPos = ftell(pcm);
            fseek(pcm, 0, SEEK_END);
            endPos = ftell(pcm);
            long length = endPos - startPos;
            fseek(pcm, curpos, SEEK_SET);
            if(length > PCM_SIZE * 2 *sizeof(short int)) {
                if(!isSkipPCMHeader) {
                    fseek(pcm, 4 * 1024, SEEK_SET);
                    isSkipPCMHeader =YES;
                }
                
                read = (int)fread(pcm_buffer, 2 *sizeof(short int), PCM_SIZE, pcm);
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
                fwrite(mp3_buffer, write, 1, mp3);
                startPos = 0;
                endPos = 0;
            }
            else{
                [NSThread sleepForTimeInterval:0.05];
            }
        } while (_status != RecordingStatus_End);
        
        //解决有可能最后短暂时间的录音没有转码
        if (endPos - startPos > 0) {
            read = (int)fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
            if (read != 0) {
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
                fwrite(mp3_buffer, write, 1, mp3);
            }
        }
        
        read = (int)fread(pcm_buffer, 2 *sizeof(short int), PCM_SIZE, pcm);
        write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
    }
    
    @catch(NSException *exception) {
        mp3FilePath = nil;
    }
    
    @finally {
        // 导出
        NSString *mp3FilePath = [self mp3Path];
        if ([[NSFileManager defaultManager] fileExistsAtPath:mp3FilePath]) {
            _savePath = [self randomPath];
            NSError *error = nil;
            [[NSFileManager defaultManager] moveItemAtPath:mp3FilePath toPath:_savePath error:&error];
            if (error) {
                _savePath = nil;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completion) {
                self.completion(YES);
            }
        });
    }
}

@end
