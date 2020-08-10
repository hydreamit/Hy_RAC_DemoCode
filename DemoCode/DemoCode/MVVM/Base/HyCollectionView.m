//
//  HyCollectionView.m
//  DemoCode
//
//  Created by Hy on 2017/11/21.
//  Copyright © 2017 Hy. All rights reserved.
//

#import "HyCollectionView.h"
#import "HyListViewModel.h"
#import <HyCategoriess/HyCategories.h>


@interface HyCollectionView ()
@property (nonatomic,strong) id<HyListViewModelProtocol, HyListViewInvokerProtocol> listViewModel;
@property (nonatomic,strong) id<HyRefreshViewFactoryProtocol> refreshViewFactory;
@property (nonatomic,strong) NSMutableArray<id<HyBlockProtocol>> *blocks;
@property (nonatomic,strong) NSMutableArray<RACDisposable *> *disposables;
@end


@implementation HyCollectionView
@synthesize key = _key;
- (void)setKey:(NSString *)key {
    BOOL can = key != _key;
    _key = key;
    if (can &&
        [self.listViewModel conformsToProtocol:@protocol(HyListViewModelProtocol)] &&
        [self.listViewModel conformsToProtocol:@protocol(HyListViewInvokerProtocol)]) {
        [self subscribeWithViewModel:self.listViewModel];
    }
}

- (void)hy_tableViewLoad {
    if (self.listViewModel) {
        __weak typeof(self) _self = self;
        self.hy_delegateConfigure.configSectionAndCellDataKey(^NSArray *{
            __strong typeof(_self) self = _self;
            id<HyListEntityProtocol> listEntity = [self.listViewModel listViewDataProviderForKey:self.key];
            return @[listEntity.entityArray, @"entityArray"];
        });
    }
}

- (void)configRefreshFramework:(nullable NSString *)framework
                   refreshType:(HyListViewRefreshType)refreshType
           refreshRequestInput:(id (^_Nullable)(HyListActionType type))inputBlock
           refreshCustomAction:(HyListViewRefreshAction(^ _Nullable)(BOOL isHeaderRefresh))actionBlock {
    
    if (refreshType == HyListViewRefreshTypeNone) {return;}

       __weak typeof(self) _self = self;
       void (^headerRefresh)(void) = (actionBlock ? actionBlock(YES) : nil) ?:
       ((refreshType == HyListViewRefreshTypePullDown ||
       refreshType == HyListViewRefreshTypePullDownAndUp) ?
        ^{  __strong typeof(_self) self = _self;
            id input = inputBlock ? inputBlock(HyListActionTypeNew) : nil;
           [self.listViewModel.listCommand(self.key) execute:RACTuplePack(input, @(HyListActionTypeNew))];
//           self.listViewModel.listAction(self.key)(input, HyListActionTypeNew);
       } : nil);

       void (^footerRefresh)(void) = (actionBlock ? actionBlock(NO) : nil) ?:
       ((refreshType == HyListViewRefreshTypePullUp ||
       refreshType == HyListViewRefreshTypePullDownAndUp) ?
        ^{  __strong typeof(_self) self = _self;
            id input = inputBlock ? inputBlock(HyListActionTypeMore) : nil;
           [self.listViewModel.listCommand(self.key) execute:RACTuplePack(input, @(HyListActionTypeMore))];
//           self.listViewModel.listAction(self.key)(input, HyListActionTypeMore);
       } : nil);

    self.refreshViewFactory =
    [HyRefreshViewManager refreshViewFactoryWithFramework:framework ?: KEY_MJRefresh
                                               scrollView:self
                                      headerRefreshAction:headerRefresh
                                      footerRefreshAction:footerRefresh];
}

- (void)headerBeginRefreshing {
    [self.refreshViewFactory.getHeaderRefreshView beginRefreshing];
}

- (void)footerBeginRefreshing {
    [self.refreshViewFactory.getFooterRefreshView beginRefreshing];
}

- (id<HyRefreshViewFactoryProtocol>)getRefreshViewFactory {
    return self.refreshViewFactory;
}

- (void)setHy_collectionViewData:(id)hy_collectionViewData {
    [super setHy_collectionViewData:hy_collectionViewData];
    
    if ([hy_collectionViewData conformsToProtocol:@protocol(HyListViewModelProtocol)] &&
        [hy_collectionViewData conformsToProtocol:@protocol(HyListViewInvokerProtocol)]) {
        self.listViewModel = hy_collectionViewData;
    }
}

- (void)setListViewModel:(id<HyListViewModelProtocol,HyListViewInvokerProtocol>)listViewModel {
    
    if (listViewModel != _listViewModel && listViewModel) {
        [self subscribeWithViewModel:listViewModel];
    }
    _listViewModel = listViewModel;
}

- (void)subscribeWithViewModel:(id<HyListViewModelProtocol,HyListViewInvokerProtocol>)listViewModel {
    
    __weak typeof(self) _self = self;
    
    void (^successHandler)(id  _Nullable, id  _Nullable, HyListActionType, BOOL) =
    ^(id  _Nullable input, id  _Nullable data, HyListActionType type, BOOL noMore) {
        __strong typeof(_self) self = _self;
        [self reloadData];
        if (type == HyListActionTypeNew) {
            [self.refreshViewFactory.getHeaderRefreshView endRefreshing];
        } else {
            [self.refreshViewFactory.getFooterRefreshView  endRefreshing];
        }
        [self.refreshViewFactory.getFooterRefreshView setHidden:noMore];
    };
    
    void (^failureHandler)(id  _Nullable, NSError * _Nonnull, HyListActionType) =
    ^(id  _Nullable input, NSError * _Nonnull error, HyListActionType type) {
        __strong typeof(_self) self = _self;
        if (type == HyListActionTypeNew) {
            [self.refreshViewFactory.getHeaderRefreshView endRefreshing];
        } else {
            [self.refreshViewFactory.getFooterRefreshView  endRefreshing];
        }
        id<HyListEntityProtocol> listEntity = [self.listViewModel listViewDataProviderForKey:self.key];
        if (listEntity.entityArray.count <= 0) {
            [self reloadData];
            [self.refreshViewFactory.getFooterRefreshView setHidden:YES];
        }
    };
    
    void (^refreshHandler)(id _Nullable) =
    ^(id  _Nullable parameter) {
        __strong typeof(_self) self = _self;
        [self reloadData];
    };
    
    [self hy_tableViewLoad];
    
    [self.disposables makeObjectsPerformSelector:@selector(dispose)];
    [self.self.disposables  removeAllObjects];
    [self.disposables addObjectsFromArray:
     listViewModel.listCommand(self.key).subscribeAll(^(id  _Nonnull value) {
        if ([value isKindOfClass:RACTuple.class]) {
            RACTupleUnpack(id input, id data, NSNumber *type, NSNumber *noMore) = (RACTuple *)value;
            successHandler(input, data, type.integerValue, noMore.integerValue);
        } else {
            __strong typeof(_self) self = _self;
            [self.refreshViewFactory.getHeaderRefreshView endRefreshing];
            [self.refreshViewFactory.getFooterRefreshView endRefreshing];
        }
    }, ^(NSError * _Nonnull error) {
        if ([error isKindOfClass:RACTuple.class]) {
            RACTupleUnpack(id input, NSError *err, NSNumber *type) = (RACTuple *)error;
            failureHandler(input, err, type.integerValue);
        } else {
            __strong typeof(_self) self = _self;
            [self.refreshViewFactory.getHeaderRefreshView endRefreshing];
            [self.refreshViewFactory.getFooterRefreshView endRefreshing];
        }
    }, ^(id  _Nonnull value) {
        
    })];
    [self.disposables addObject:
     listViewModel.refreshListViewSignal(self.key).deliverOnMainThread.subscribeNext(refreshHandler)];
    

//        [self.blocks makeObjectsPerformSelector:@selector(releaseBlock)];
//        [self.blocks removeAllObjects];
//        [self.blocks addObjectsFromArray:
//         [listViewModel addListActionSuccessHandler:successHandler
//                                     failureHandler:failureHandler
//                                             forKey:self.key]];
//        [self.blocks addObject:[listViewModel addRefreshListView:refreshHandler forKey:self.key]];
}

- (NSMutableArray<id<HyBlockProtocol>> *)blocks {
    if (!_blocks) {
        _blocks = @[].mutableCopy;
    }
    return _blocks;
}

- (NSMutableArray<RACDisposable *> *)disposables {
    if (!_disposables) {
        _disposables = @[].mutableCopy;
    }
    return _disposables;
}

- (void)dealloc {
  NSLog(@"%s", __func__);
}
@end
