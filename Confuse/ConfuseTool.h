//
//  ConfuseTool.h
//  Code
//
//  Created by Dincoln on 2018/2/27.
//  Copyright © 2018年 Dincoln. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ConfuseTool : NSObject

/**
 黑名单，指定的字符不混淆
 */
@property (nonatomic, strong) NSMutableArray *blackList;

+ (instancetype)shareInstance;

- (NSString *)encodeWithClassName:(NSString *)className;

- (NSString *)encodeWithClassNameArr:(NSArray<NSString *> *)classNameArr;


@end
