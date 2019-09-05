//
//  AudioPlayerView.m
//
//
//  Created by 刘鹏i on 2019/9/3.
//  Copyright © 2019 . All rights reserved.
//

#import "AudioPlayerView.h"
#import "AudioManager.h"

@interface AudioPlayerView () <AudioManagerDelegate>
@property (strong, nonatomic) IBOutlet UIView *viewContent;
@property (strong, nonatomic) IBOutlet UIView *viewPipe;    ///< 管道
@property (strong, nonatomic) IBOutlet UIView *viewProgress;///< 播放进度条视图
@property (strong, nonatomic) IBOutlet UIView *viewCache;   ///< 缓存进度条视图
@property (strong, nonatomic) IBOutlet UIImageView *imgVoice;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityView;

@property (strong, nonatomic) IBOutlet UILabel *lblTime1;
@property (strong, nonatomic) IBOutlet UILabel *lblTime2;
@property (strong, nonatomic) IBOutlet UIView *viewThumb;

// 修改约束是为了屏幕旋转、刷新页面后还是正确的，不是为了实时刷新页面以更新位置（不停的要求重绘页面，可能会浪费算力吧，没验证）
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *lytLoadW;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *lytProgressW;

@property (strong, nonatomic) IBOutlet UIPanGestureRecognizer *panGesture;  ///< 拖动手势

@property (nonatomic, assign) CGFloat playProgress;     ///< 播放进度
@property (nonatomic, assign) CGFloat cacheProgress;    ///< 缓存进度
@property (nonatomic, strong) DynamicModel *model;
@property (nonatomic, assign) NSInteger totalSeconds;   ///< 总时长

@property (nonatomic, assign) AudioPlayStatus playStatus;///< 播放状态
@property (nonatomic, assign) BOOL isDragging;///< 拖拽中
@property (nonatomic, assign) BOOL disableDelegate;///< 禁止接收代理信息
@end

@implementation AudioPlayerView
#pragma mark - Life Cycle
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self loadViewFromXib];
        
        [self viewConfig];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self loadViewFromXib];
    }
    return self;
}

- (void)loadViewFromXib
{
    UIView *contentView = [[NSBundle bundleForClass:[self class]] loadNibNamed:NSStringFromClass([self class]) owner:self options:nil].firstObject;
    contentView.frame = self.bounds;
    contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth| UIViewAutoresizingFlexibleHeight;
    [self addSubview:contentView];
    
    [self viewConfig];
}

- (void)viewConfig
{
    self.backgroundColor = [UIColor clearColor];
}

#pragma mark - Public
- (void)configWithVoiceModel:(DynamicModel *)model
{
    _model = model;
    
    self.totalSeconds = _model.seconds;
    
    if ([_model.strID isEqualToString:[AudioManager sharedInstance].voiceID]) {
        // 恢复接收
        self.playStatus = AudioPlayStatus_Unknown;
        
        _disableDelegate = NO;
        [[AudioManager sharedInstance] resumeReceivingStatue:self];
    } else {
        // 禁止接收，因为cell有重用
        _disableDelegate = YES;
        
        self.playStatus = AudioPlayStatus_Unknown;
    }
}

#pragma mark - Action
- (IBAction)clickedButton:(UIButton *)sender {
    _disableDelegate = NO;
    
    switch (_playStatus) {
        case AudioPlayStatus_Unknown:
        {
            NSURL *url = nil;
//            // 本地缓存，如果有的话，优先播放本地
//            NSString *cachePath = [[AudioCacheManager sharedInstance] pathForAudio:_model.strID];
//            if (cachePath.length) {
//                // 缓存
//                url = [NSURL fileURLWithPath:cachePath];
//            } else {
                // 网络
                url = [NSURL URLWithString:_model.downloadUrl];
//            }
            
            [[AudioManager sharedInstance] playAudio:_model.strID url:url delegate:self];
        }
            break;
        case AudioPlayStatus_Failed:
        case AudioPlayStatus_Pause:
        case AudioPlayStatus_End:
            [[AudioManager sharedInstance] play];
            break;
        case AudioPlayStatus_Playing:
            [[AudioManager sharedInstance] pause];
            break;
        default:
            break;
    }
}

- (IBAction)panAction:(UIPanGestureRecognizer *)sender {
    // 单次滑动的总偏移量
    CGPoint translatePoint = [sender translationInView:self];
    
    // 滑动之前的中心点坐标（相对于进度条）（不能直接取center，因为transform会直接影响frame，但不会影响center）
    CGFloat originX = sender.view.frame.origin.x - sender.view.transform.tx + sender.view.frame.size.width / 2.0 - _viewPipe.frame.origin.x;
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            sender.view.transform = CGAffineTransformIdentity;
            self.isDragging = YES;
        case UIGestureRecognizerStateChanged:
        {
            // 滑块
            if (originX + translatePoint.x < 0) {
                translatePoint.x = 0 - originX;
            } else if (originX + translatePoint.x > _viewPipe.frame.size.width) {
                translatePoint.x = _viewPipe.frame.size.width - originX;
            }
            sender.view.transform = CGAffineTransformMakeTranslation(translatePoint.x, 0);
            
            // 精度问题导致越界处理
            CGFloat width = sender.view.frame.origin.x + sender.view.frame.size.width / 2.0 - _viewPipe.frame.origin.x;
            if (width < 0) {
                width = 0;
            } else if (width > _viewPipe.frame.size.width) {
                width = _viewPipe.frame.size.width;
            }
            // 背景条
            CGRect frame = self.viewProgress.frame;
            frame.size.width = width;
            self.viewProgress.frame = frame;
            
            // 实时更新时间进度
            NSInteger seconds = floor(width / _viewPipe.frame.size.width * _totalSeconds);
            _lblTime1.text = [NSString stringWithFormat:@"%.2ld:%.2ld", seconds / 60, seconds % 60];
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            self.isDragging = NO;
            
            // 滑块
            CGRect frame = sender.view.frame;
            sender.view.transform = CGAffineTransformIdentity;
            sender.view.frame = frame;
            
            // 进度
            self.playProgress = (sender.view.frame.origin.x + sender.view.frame.size.width / 2.0 - _viewPipe.frame.origin.x) / _viewPipe.frame.size.width;

            // 请求
            [[AudioManager sharedInstance] jumpedToProgress:_playProgress];
            
        }
            break;
        default:
            break;
    }
}

#pragma mark - Set
- (void)setPlayStatus:(AudioPlayStatus)playStatus
{
    _playStatus = playStatus;
    
    switch (playStatus) {
        case AudioPlayStatus_Unknown:
        case AudioPlayStatus_Failed:
        {
            _imgVoice.hidden = NO;
            [self stopPlayAnimation];
            
            _activityView.hidden = YES;
            
            self.playProgress = 0;
            self.cacheProgress = 0;
            
            _panGesture.enabled = NO;
        }
            break;
        case AudioPlayStatus_Preparation:
        {
            _imgVoice.hidden = YES;
            
            _activityView.hidden = NO;
            [_activityView startAnimating];
            
            self.playProgress = 0;
            self.cacheProgress = 0;
            
            _panGesture.enabled = NO;
        }
            break;
        case AudioPlayStatus_Pause:
        case AudioPlayStatus_End:
        {
            _imgVoice.hidden = NO;
            [self stopPlayAnimation];
            
            _activityView.hidden = YES;
            
            _panGesture.enabled = YES;
        }
            break;
        case AudioPlayStatus_Playing:
        {
            _imgVoice.hidden = NO;
            [self startPlayAnimation];
            
            _activityView.hidden = YES;
            
            _panGesture.enabled = YES;
        }
            break;
        case AudioPlayStatus_Buffering:
        {
            _imgVoice.hidden = YES;
            
            _activityView.hidden = NO;
            [_activityView startAnimating];
            
            _panGesture.enabled = YES;
        }
            break;
        default:
            break;
    }
}

- (void)setTotalSeconds:(NSInteger)totalSeconds
{
    _totalSeconds = totalSeconds;
    _lblTime2.text = [NSString stringWithFormat:@"%.2ld:%.2ld", totalSeconds / 60, totalSeconds % 60];
}

- (void)setPlayProgress:(CGFloat)playProgress
{
    /// 拖拽中不接收进度更新
    if (_isDragging) {
        return;
    }
    
    // 精度问题导致越界处理
    if (playProgress < 0) {
        playProgress = 0;
    } else if (playProgress > 1) {
        playProgress = 1;
    }
    
    _playProgress = playProgress;
    
    CGFloat progressWidth = playProgress * _viewPipe.frame.size.width;
    
    // 滑块
    CGRect thumbFrame = self.viewThumb.frame;
    thumbFrame.origin.x = progressWidth + _viewPipe.frame.origin.x - _viewThumb.frame.size.width / 2.0;
    self.viewThumb.frame = thumbFrame;
    
    // 进度
    CGRect progressFrame = self.viewProgress.frame;
    progressFrame.size.width = progressWidth;
    self.viewProgress.frame = progressFrame;
    
    // 进度约束
    _lytProgressW.constant = progressWidth;
    
    // 时间进度
    NSInteger seconds = floor(playProgress * _totalSeconds);
    _lblTime1.text = [NSString stringWithFormat:@"%.2ld:%.2ld", seconds / 60, seconds % 60];
}

- (void)setCacheProgress:(CGFloat)cacheProgress
{
    // 精度问题导致越界处理
    if (cacheProgress < 0) {
        cacheProgress = 0;
    } else if (cacheProgress > 1) {
        cacheProgress = 1;
    }
    
    _cacheProgress = cacheProgress;
    
    CGFloat progressWidth = cacheProgress * _viewPipe.frame.size.width;
    
    // 进度
    CGRect progressFrame = _viewCache.frame;
    progressFrame.size.width = progressWidth;
    self.viewCache.frame = progressFrame;
    
    // 进度约束
    _lytLoadW.constant = progressWidth;
}

#pragma mark - AudioManagerDelegate
/// 播放状态改变
- (void)playStatusChanged:(AudioPlayStatus)status
{
    if (_disableDelegate) {
        return;
    }
    
    self.playStatus = status;
}

/// 更新播放进度
- (void)playProgressUpdated:(double)progress
{
    if (_disableDelegate) {
        return;
    }
    
    if (progress >= 0 && progress <= 1) {
        self.playProgress = progress;
    }
}

/// 更新缓存进度
- (void)cacheProgressUpdated:(double)progress
{
    if (_disableDelegate) {
        return;
    }
    
    if (progress >= 0 && progress <= 1) {
        self.cacheProgress = progress;
    }
}

/// 更新总时长
- (void)totalDurationUpdated:(double)seconds
{
    if (_disableDelegate) {
        return;
    }
    
    self.totalSeconds = floor(seconds);
}

#pragma mark - Animation
/// 开始播放动画
- (void)startPlayAnimation
{
    NSMutableArray *muarr = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i <= 3; i++) {
        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"home_voice_%ld", i]];
        [muarr addObject:image];
    }
    _imgVoice.animationImages = muarr;
    _imgVoice.animationRepeatCount = CGFLOAT_MAX;
    _imgVoice.animationDuration = 1.2;
    
    [_imgVoice startAnimating];
}

/// 停止播放动画
- (void)stopPlayAnimation
{
    [_imgVoice stopAnimating];
    _imgVoice.image = [UIImage imageNamed:@"home_voice_0"];
}
@end
