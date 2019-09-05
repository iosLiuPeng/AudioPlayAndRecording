//
//  DynamicModel.m
//
//
//  Created by 刘鹏i on 2019/8/19.
//
//

#import "DynamicModel.h"

@implementation DynamicModel
#pragma mark - Life Cycle
/// 从接口数据初始化
- (instancetype)initWithDict:(NSDictionary *)dict
{
    self = [super init];
    if (self) {
        _strID = [NSUUID UUID].UUIDString;    // ID
        
        _downloadUrl = @"http://download.lingyongqian.cn/music/ForElise.mp3";// 音频链接
        _seconds = arc4random() % 400;    // 总时长
    }
    return self;
}

/// 从接口数据批量初始化
+ (NSArray<DynamicModel *> *)arrayWithDict:(NSDictionary *)dict
{
    NSArray *arrDict = dict[@"list"];
    
    NSMutableArray *muarr = [NSMutableArray arrayWithCapacity:arrDict.count];
    for (NSDictionary *dict in arrDict) {
        DynamicModel *model = [[DynamicModel alloc] initWithDict:dict];
        [muarr addObject:model];
    }
    
    return [muarr copy];
}

@end
