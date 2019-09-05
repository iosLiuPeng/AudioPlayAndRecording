//
//  DynamicModel.h
//
//
//  Created by 刘鹏i on 2019/8/19.
//  
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DynamicModel : NSObject
@property (nonatomic, copy) NSString *strID;    ///< ID

@property (nonatomic, copy) NSString *downloadUrl;///< 音频链接
@property (nonatomic, assign) NSInteger seconds;///< 总时长


/// 从接口数据初始化
- (instancetype)initWithDict:(NSDictionary *)dict;

/// 从接口数据批量初始化
+ (NSArray<DynamicModel *> *)arrayWithDict:(NSDictionary *)dict;


@end

NS_ASSUME_NONNULL_END
