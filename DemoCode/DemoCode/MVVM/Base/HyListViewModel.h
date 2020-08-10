//
//  HyListViewModel.h
//  DemoCode
//
//  Created by Hy on 2017/11/21.
//  Copyright © 2017 Hy. All rights reserved.
//

#import "HyViewModel.h"
#import "HyListViewModelProtocol.h"
#import "HyListViewProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface HyListViewModel : HyViewModel <HyListViewModelProtocol, HyListViewInvokerProtocol>

@end

NS_ASSUME_NONNULL_END
