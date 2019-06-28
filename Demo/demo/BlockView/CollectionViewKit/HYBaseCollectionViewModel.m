//
//  HYBaseCollectionViewModel.m
//  Demo
//
//  Created by huangyi on 2018/6/1.
//  Copyright © 2018年 HY. All rights reserved.
//

#import "HYBaseCollectionViewModel.h"

@interface HYBaseCollectionViewModel ()
@property (nonatomic,strong) RACCommand *collectionViewCommand;
@end

@implementation HYBaseCollectionViewModel

- (void)handleViewModel {
    
    self.startPageNumber = 1;
    self.pageNumber = self.startPageNumber;
    self.pageSize = 20;
}

- (collectionViewCommandBlock)collectionViewExecuteCommand {
    return ^RACCommand *(HYCollectionViewLoadDataType type) {
        
        self.currentLoadDataType = type;
        return self.collectionViewCommand;
    };
}

- (RACCommand *)collectionViewCommand {
    return Hy_Lazy(_collectionViewCommand, ({
        
        RACCommand *commnad = nil;
        if (self.isGetRequest) {
            commnad =
            [RACCommand commandGetCacheWithUrl:[self configtUrl]
                                        params:[self configParams]
                                 handleCommand:[self configrequestCommand]];
        } else {
            commnad =
            [RACCommand commandPostCacheWithUrl:[self configtUrl]
                                         params:[self configParams]
                                  handleCommand:[self configrequestCommand]];
        }
        commnad;
    }));
}

- (requestCommandBlock)configrequestCommand {
    @weakify(self);
    return
    ^(id input, id response, id<RACSubscriber> subscriber) {
        @strongify(self);
        
        if (!subscriber) {return;}
        if (!self ||
            !response ||
            ![response isKindOfClass:[NSDictionary class]]) {
            [subscriber sendError:nil];
            return ;
        }
        
        NSString *status = [NSString stringWithFormat:@"%@",response[@"code"]];
        ([status integerValue] != 0) ?
        ([subscriber sendError:nil])   :
        ({
            NSDictionary *dict = [self configDataParams](response);
            if (!dict) {
                [subscriber sendError:nil];
                return;
            }
            NSArray *keys = dict.allKeys;
            if (!keys.count) {
                [subscriber sendError:nil];
                return;
            }
            
            Class sectionModelClass = [self objectForDict:dict Key:SectionModelClassKey];
            Class cellModelClass = [self objectForDict:dict Key:CellModelClassKey];
            id cellModelData = [self objectForDict:dict Key:CellModelDataKey];
            id sectionModelData = [self objectForDict:dict Key:SectionModelDataKey];
            
            if (sectionModelClass && sectionModelData &&
                [sectionModelData isKindOfClass:[NSArray class]]) {
                
                NSMutableArray *sectionArray = @[].mutableCopy;
                for (NSDictionary *dict in sectionModelData) {
                    
                    HYBaseCollectionSectionModel *sectionModel =
                    [sectionModelClass mj_objectWithKeyValues:dict];
                    
                    if (cellModelClass && cellModelData &&
                        [cellModelData isKindOfClass:[NSString class]]) {
                        
                        id cellData = [self objectForDict:dict Key:cellModelData];
                        
                        if ([cellData isKindOfClass:[NSArray class]]) {
                            for (NSDictionary *cellDict in cellData) {
                                [sectionModel.cellModels addObject:[cellModelClass mj_objectWithKeyValues:cellDict]];
                            }
                        }
                        if ([cellData isKindOfClass:[NSDictionary class]]) {
                            [sectionModel.cellModels addObject:[cellModelClass mj_objectWithKeyValues:cellData]];
                        }
                    }
                    [sectionArray addObject:sectionModel];
                }
                
                if (self.currentLoadDataType == 0 ||
                    self.currentLoadDataType == 1) {
                    self.pageNumber = self.startPageNumber + 1;
                    self.sectionModels = sectionArray;
                } else {
                    [self.sectionModels addObjectsFromArray:sectionArray];
                    self.pageNumber++;
                }
                [subscriber sendNext:@((sectionArray.count < self.pageSize))]; // 隐藏显示footer
                [subscriber sendCompleted];
                
            } else if ((!sectionModelClass || !sectionModelData) &&
                       cellModelClass && cellModelData) {
                
                NSMutableArray *cellA = @[].mutableCopy;
                id cellData = cellModelData;
                
                if ([cellData isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *cellDict in cellData) {
                        [cellA addObject:[cellModelClass mj_objectWithKeyValues:cellDict]];
                    }
                }
                if ([cellData isKindOfClass:[NSDictionary class]]) {
                    [cellA addObject:[cellModelClass mj_objectWithKeyValues:cellData]];
                }
                
                if (cellA.count) {
                    if (!self.sectionModels.count) {
                        HYBaseCollectionSectionModel *sectionModel = [HYBaseCollectionSectionModel new];
                        [self.sectionModels addObject:sectionModel];
                    }
                    if (self.currentLoadDataType == 0 ||
                        self.currentLoadDataType == 1) {
                        self.sectionModels.firstObject.cellModels = cellA;
                    } else {
                        [self.sectionModels.firstObject.cellModels addObjectsFromArray:cellA];
                    }
                } else {
                    if (self.currentLoadDataType == 0 ||
                        self.currentLoadDataType == 1) {
                        if (self.sectionModels.count) {
                            [self.sectionModels removeAllObjects];
                        }
                    }
                }
                if (self.currentLoadDataType == 0 ||
                    self.currentLoadDataType == 1) {
                    self.pageNumber = self.startPageNumber + 1;
                } else {
                    self.pageNumber++;
                }
                [subscriber sendNext:@((cellA.count < self.pageSize))]; // 隐藏显示footer
                [subscriber sendCompleted];
            } else {
                [subscriber sendError:nil];
            }
        });
    };
}

- (NSInteger)getLoadDataPageNumber {
    return self.currentLoadDataType == 2 ? self.pageNumber : self.startPageNumber;
}

- (id)objectForDict:(NSDictionary *)dict
                Key:(NSString *)key {
    __block BOOL haveKey = NO;
    NSString *currentKey = key;
    [dict enumerateKeysAndObjectsUsingBlock:^(id  key,
                                              id  obj,
                                              BOOL * _Nonnull stop) {
        if ([currentKey isEqualToString:key]) {
            haveKey = YES;
            *stop = YES;
        }
    }];
    return haveKey ? [dict objectForKey:currentKey] : nil;
}

- (requestUrlBlock)configtUrl {
    return nil;
}

- (requestParamsBlock)configParams {
    return nil;
}

//    return ^ NSDictionary * (id response){
//        return @{
//                 SectionModelDataKey : response[@"data"],
//                 SectionModelNameKey : @"HYBaseCollectionSectionModel",
//                 cellModelName    : @"HYBaseCollectionCellModel",
//                 CellModelDataKey : @"cell"
//                };
//    };

//    return ^ NSDictionary * (id response){
//        return @{
//                 cellModelName : @"HYBaseCollectionCellModel",
//                 CellModelDataKey : response[@"data"]
//                };
//    };
- (tableViewDataAnalyzeBlock)configDataParams {
    return nil;
}

- (NSMutableArray<HYBaseCollectionSectionModel *> *)sectionModels {
    return Hy_Lazy(_sectionModels, ({
        @[].mutableCopy;
    }));
}

- (HYBaseCollectionSectionModel *)getSectionModelAtSection:(NSInteger)section {
    if (!self.sectionModels) { return nil;}
    if (section >= self.sectionModels.count) {  return nil;}
    HYBaseCollectionSectionModel *sectionModel = self.sectionModels[section];
    return sectionModel;
}

- (HYBaseCollectionCellModel *)getCellModelAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.sectionModels) {return nil;}
    HYBaseCollectionSectionModel *sectionModel = [self getSectionModelAtSection:indexPath.section];
    if (!sectionModel) { return nil;}
    if (indexPath.row >= sectionModel.cellModels.count) {
        return nil;
    }
    HYBaseCollectionCellModel *cellModel = sectionModel.cellModels[indexPath.row];
    return cellModel;
}

@end
