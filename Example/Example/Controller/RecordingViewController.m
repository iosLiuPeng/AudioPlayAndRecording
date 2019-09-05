//
//  RecordingViewController.m
//
//
//  Created by 刘鹏i on 2019/8/26.
//
//

#import "RecordingViewController.h"
#import "RecordingManager.h"
#import "VoiceManager.h"

typedef NS_ENUM(NSUInteger, OperationStatua) {
    OperationStatua_Hide,       ///< 隐藏录音
    OperationStatua_Wait,       ///< 准备录音
    OperationStatua_Recording,  ///< 正在录音
    OperationStatua_End,        ///< 停止录音
    OperationStatua_Choice,     ///< 已选录音
};

@interface RecordingViewController ()
@property (strong, nonatomic) IBOutlet UIButton *btnMicrophone; ///< 麦克风按钮
@property (strong, nonatomic) IBOutlet UIView *viewVoice;       ///< 声音播放视图
@property (strong, nonatomic) IBOutlet UIImageView *imgVoice;   ///< 声音图片
@property (strong, nonatomic) IBOutlet UILabel *lblTimes;       ///< 声音时间

@property (strong, nonatomic) IBOutlet UIView *viewRecording;   ///< 录音视图
@property (strong, nonatomic) IBOutlet UIButton *btnPlay;       ///< 录音按钮
@property (strong, nonatomic) IBOutlet UIView *viewRippleGray;  ///< 录音背景图-灰
@property (strong, nonatomic) IBOutlet UIView *viewRippleGreen1;///< 录音背景图-1
@property (strong, nonatomic) IBOutlet UIView *viewRippleGreen2;///< 录音背景图-2

@property (strong, nonatomic) IBOutlet UIButton *btnDelete;     ///< 删除录音按钮
@property (strong, nonatomic) IBOutlet UIButton *btnChoice;     ///< 选择录音按钮
@property (strong, nonatomic) IBOutlet UILabel *lblRecordingTime;   ///< 录音时间

@property (nonatomic, assign) OperationStatua operationStatua;  ///< 当前操作状态
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) CGFloat seconds;    ///< 录音时间-秒
@property (nonatomic, copy) NSString *voicePath;    ///< 录音MP3文件地址
@end

static NSInteger maxTimes = 60 * 10;///< 最多录制10分钟

@implementation RecordingViewController
#pragma mark - Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self viewConfig];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self recordingEnd];
}

#pragma mark - Subjoin
- (void)viewConfig
{
    self.operationStatua = OperationStatua_Wait;
}

#pragma mark - Private
- (NSTimer *)timer
{
    if (_timer == nil) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(timerAction) userInfo:nil repeats:YES];
    }
    return _timer;
}

- (void)timerAction
{
    NSInteger multiple = 2; // 时间缩小倍数
    
    BOOL isInteger = (NSInteger)(_seconds * multiple) % multiple == 0;
    if (isInteger) {
        // 是整数
        _lblRecordingTime.text = [NSString stringWithFormat:@"%.2ld:%.2ld", (NSInteger)_seconds / 60, (NSInteger)_seconds % 60];
    }
    
    _viewRippleGreen1.hidden = (NSInteger)(_seconds * multiple) % 3 == 2;
    _viewRippleGreen2.hidden = (NSInteger)(_seconds * multiple) % 3 != 1;
    
    if (_seconds >= maxTimes) {
        [self recordingEnd];
    }
    
    _seconds += 0.5;
}

- (void)stopTimer
{
    [_timer invalidate];
    _timer = nil;
}

/// 刷新视图
- (void)setOperationStatua:(OperationStatua)operationStatua
{
    _operationStatua = operationStatua;
    
    switch (_operationStatua) {
        case OperationStatua_Hide: {
            _btnMicrophone.enabled = YES;
            _viewVoice.hidden = YES;
            _viewRecording.hidden = YES;
        }
            break;
        case OperationStatua_Wait: {
            _btnMicrophone.enabled = YES;
            _viewVoice.hidden = YES;
            _viewRecording.hidden = NO;
            
            _btnDelete.hidden = YES;
            _btnChoice.hidden = YES;
            [_btnPlay setImage:[UIImage imageNamed:@"recording_start"] forState:UIControlStateNormal];
            _viewRippleGray.hidden = NO;
            _viewRippleGreen1.hidden = YES;
            _viewRippleGreen2.hidden = YES;
            _lblRecordingTime.text = @"00:00";
        }
            break;
        case OperationStatua_Recording: {
            _btnMicrophone.enabled = NO;
            _viewVoice.hidden = YES;
            _viewRecording.hidden = NO;
            
            _btnDelete.hidden = YES;
            _btnChoice.hidden = YES;
            [_btnPlay setImage:[UIImage imageNamed:@"recording_recording"] forState:UIControlStateNormal];
            _viewRippleGray.hidden = YES;
            _viewRippleGreen1.hidden = YES;
            _viewRippleGreen2.hidden = YES;
        }
            break;
        case OperationStatua_End: {
            _btnMicrophone.enabled = NO;
            _viewVoice.hidden = YES;
            _viewRecording.hidden = NO;
            
            _btnDelete.hidden = NO;
            _btnChoice.hidden = NO;
            [_btnPlay setImage:[UIImage imageNamed:@"recording_stop"] forState:UIControlStateNormal];
            _viewRippleGray.hidden = YES;
            _viewRippleGreen1.hidden = NO;
            _viewRippleGreen2.hidden = NO;
        }
            break;
        case OperationStatua_Choice: {
            _btnMicrophone.enabled = NO;
            _viewVoice.hidden = NO;
            _viewRecording.hidden = YES;
        }
            break;
        default:
            break;
    }
}

/// 开始录制
- (void)recordingBegin
{
    self.operationStatua = OperationStatua_Recording;
    
    _seconds = 0.0;
    [self.timer fire];
    
    __weak typeof(self) weakSelf = self;
    [[RecordingManager sharedInstance] startRecording:^(BOOL success) {
        if (success) {
            weakSelf.voicePath = [[RecordingManager sharedInstance] exportVoice];
            
            NSInteger seconds = [[VoiceManager sharedInstance] durationForAudio:weakSelf.voicePath];
            weakSelf.lblTimes.text = [NSString stringWithFormat:@"%.2ld:%.2ld", seconds / 60, seconds % 60];
        }
    }];
}

/// 结束录制
- (void)recordingEnd
{
    [self stopTimer];
    
    switch (_operationStatua) {
        case OperationStatua_Recording:
            self.operationStatua = OperationStatua_End;
            break;
        default:
            break;
    }
    
    [[RecordingManager sharedInstance] stopRecording];
}

- (void)removeVoice
{
    [[VoiceManager sharedInstance] stop];
    
    // 发布成功后删除
    if ([[NSFileManager defaultManager] fileExistsAtPath:_voicePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:_voicePath error:nil];
        _voicePath = nil;
    }
}

#pragma mark - Action
/// 点击麦克风
- (IBAction)clickedMicrophone:(id)sender {
    [self.view endEditing:YES];
    
    switch (_operationStatua) {
        case OperationStatua_Hide:
            self.operationStatua = OperationStatua_Wait;
            break;
        default:
            self.operationStatua = OperationStatua_Hide;
            break;
    }
}

/// 点击播放按钮
- (IBAction)clickedPlay:(UIButton *)sender {
    if (_voicePath.length == 0) {
        return;
    }
    
    sender.selected = !sender.selected;
    
    if (sender.selected) {
        // 播放
        __weak typeof(self) weakSelf = self;
        [[VoiceManager sharedInstance] playWithPath:_voicePath completion:^{
            sender.selected = NO;
            [weakSelf stopPlayAnimation];
        }];

        [self startPlayAnimation];
    } else {
        // 停止
        [[VoiceManager sharedInstance] stop];
        
        [self stopPlayAnimation];
    }
}

/// 点击录音按钮
- (IBAction)clickedRecording:(UIButton *)sender {
    [self.view endEditing:YES];
    
    switch (_operationStatua) {
        case OperationStatua_Wait:
            [self recordingBegin];
            break;
        case OperationStatua_Recording:
            [self recordingEnd];
            break;
        default:
            break;
    }
}

/// 点击删除按钮
- (IBAction)clickedDelete:(id)sender {
    
    [self removeVoice];
    
    self.operationStatua = OperationStatua_Wait;
}

/// 点击选择按钮
- (IBAction)clickedChoice:(id)sender {
    
    self.operationStatua = OperationStatua_Choice;
}

/// 点击关闭语音
- (IBAction)clickedCloseVoice:(id)sender {
    
    [self removeVoice];
    self.operationStatua = OperationStatua_Wait;
}


#pragma mark - Animation
/// 开始播放动画
- (void)startPlayAnimation
{
    NSMutableArray *muarr = [[NSMutableArray alloc] init];
    for (NSInteger i = 1; i <= 7; i++) {
        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"release_voice%ld", i]];
        [muarr addObject:image];
    }
    _imgVoice.animationImages = muarr;
    _imgVoice.animationRepeatCount = CGFLOAT_MAX;
    _imgVoice.animationDuration = 1.1;
    
    [_imgVoice startAnimating];
}

/// 停止播放动画
- (void)stopPlayAnimation
{
    [_imgVoice stopAnimating];
    _imgVoice.image = [UIImage imageNamed:@"release_voice"];
}

@end
