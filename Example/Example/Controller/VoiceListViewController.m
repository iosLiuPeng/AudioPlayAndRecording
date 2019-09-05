//
//  VoiceListViewController.m
//
//
//  Created by 刘鹏i on 2019/9/2.
//  Copyright © 2019 . All rights reserved.
//

#import "VoiceListViewController.h"
#import "VoiceListTableViewCell.h"
#import "DynamicModel.h"

@interface VoiceListViewController () <UITableViewDataSource>
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *arrSource;
@end

@implementation VoiceListViewController
#pragma mark - Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self viewConfig];
    
    [self dataConfig];
}

#pragma mark - Subjoin
- (void)viewConfig
{

    [_tableView registerNib:[UINib nibWithNibName:NSStringFromClass(VoiceListTableViewCell.class) bundle:nil] forCellReuseIdentifier:NSStringFromClass(VoiceListTableViewCell.class)];
    _tableView.estimatedRowHeight = 130;
}

- (void)dataConfig
{
    _arrSource = [[NSMutableArray alloc] init];
    
    [self requestVoiceList:NO];
}

#pragma mark - Fetch Data
- (void)requestVoiceList:(BOOL)more
{
    NSArray *arr = [DynamicModel arrayWithDict:@{@"list": @[@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @"", @""]}];
    
    if (more == NO) {
        [self.arrSource removeAllObjects];
    }
    
    [self.arrSource addObjectsFromArray:arr];
    
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _arrSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    VoiceListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass(VoiceListTableViewCell.class) forIndexPath:indexPath];
    DynamicModel *model = _arrSource[indexPath.row];
    [cell configCellWithModel:model];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end
