//
//  ConfuseTool.m
//  Code
//
//  Created by Dincoln on 2018/2/27.
//  Copyright © 2018年 Dincoln. All rights reserved.
//

#import "ConfuseTool.h"
#import <objc/runtime.h>
@implementation ConfuseTool
- (instancetype)init
{
    self = [super init];
    if (self) {
    }
    return self;
}
+ (instancetype)shareInstance{
    static ConfuseTool *instacne;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instacne = [[ConfuseTool alloc] init];
    });
    return instacne;
}

- (NSString *)encodeWithClassNameArr:(NSArray<NSString *> *)classNameArr{
    NSMutableString *str = [NSMutableString string];
    for (NSString *name in classNameArr) {
        if (name && name.length>0) {
            NSString *s = [self encodeWithClassName:name];
            if (s && s.length>0) {
                [str appendString:s];
            }
        }
    }
    return str;
}

- (NSString *)encodeWithClassName:(NSString *)className{
    Class class = NSClassFromString(className);
    if (!class) {
        return nil;
    }
    NSMutableArray<NSString *> *propertyArr = [self getAllPropetyWithClass:class];
    
    NSMutableArray<NSString *> *selArr = [self getAllMethod:class];
    
    NSMutableArray<NSString *> *protocolSelArr = [self getAllProtocolSelWithClass:class];
    ///移除所有代理方法，代理方法不混淆
    for (NSString *sel in protocolSelArr) {
        if ([selArr containsObject:sel]) {
            [selArr removeObject:sel];
        }
    }
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"\n#pragma mark - %@\n\n",className];
    for (NSString *selName in selArr) {
        NSArray<NSString *> *arr = [self encodeSel:selName properytArr:propertyArr];
        for (NSString *encode in arr) {
            [str appendFormat:@"%@\n",encode];
        }
    }
    if (!str) {
        str = [NSMutableString string];
    }
    return str;
}

/**
 获取类代理的所有方法

 @param class class
 @return 代理方法
 */
- (NSMutableArray<NSString *> *)getAllProtocolSelWithClass:(Class)class{
    NSMutableArray<NSString *> *arr= [NSMutableArray array];
    unsigned int protocolCount;
    Protocol * __unsafe_unretained _Nonnull *protocols = class_copyProtocolList(class, &protocolCount);
    for (int i = 0; i < protocolCount; i ++) {
        unsigned desCount1;
        struct objc_method_description *des1 = protocol_copyMethodDescriptionList(protocols[i], YES, YES, &desCount1);
        for (int index = 0 ; index < desCount1; index ++ ) {
            struct objc_method_description d = des1[index];
            [arr addObject:NSStringFromSelector(d.name)];
        }
        
        unsigned desCount2;
        struct objc_method_description *des2 = protocol_copyMethodDescriptionList(protocols[i], YES, NO, &desCount2);
        for (int index = 0 ; index < desCount2; index ++ ) {
            struct objc_method_description d = des2[index];
            [arr addObject:NSStringFromSelector(d.name)];
        }
        
        unsigned desCount3;
        struct objc_method_description *des3 = protocol_copyMethodDescriptionList(protocols[i], NO, YES, &desCount3);
        for (int index = 0 ; index < desCount3; index ++ ) {
            struct objc_method_description d = des3[index];
            [arr addObject:NSStringFromSelector(d.name)];
        }
        
        unsigned desCount4;
        struct objc_method_description *des4 = protocol_copyMethodDescriptionList(protocols[i], NO, NO, &desCount4);
        for (int index = 0 ; index < desCount4; index ++ ) {
            struct objc_method_description d = des4[index];
            [arr addObject:NSStringFromSelector(d.name)];
        }
    }
    return arr;
}



- (NSMutableArray<NSString *> *)getAllMethod:(Class)class{
    NSMutableArray<NSString *> *selArr = [NSMutableArray arrayWithObject:NSStringFromClass(class)];
    Class superClass = [class superclass];
    unsigned int count1;
    Method *methods1 = class_copyMethodList(class, &count1);
    for (int i = 0; i<count1; i++) {
        Method method = methods1[i];
        SEL sel = method_getName(method);
        if (!class_respondsToSelector(superClass, sel)) {
            NSString *selName = NSStringFromSelector(sel);
            [selArr addObject:selName];
        }
    }
    
    Class metaClass = objc_getMetaClass(NSStringFromClass(class).UTF8String);
    unsigned int count2;
    Method *methods2 = class_copyMethodList(metaClass, &count2);
    for (int i = 0; i<count2; i++) {
        Method method = methods2[i];
        SEL sel = method_getName(method);
        if (!class_respondsToSelector([metaClass superclass], sel)) {
            NSString *selName = NSStringFromSelector(sel);
            [selArr addObject:selName];
        }
    }
    return selArr;
}

- (NSMutableArray<NSString *> *)getAllPropetyWithClass:(Class)class{
    unsigned int count;
    objc_property_t  *properties = class_copyPropertyList(class, &count);
    NSMutableArray<NSString *> *arr = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        if (name && name.length > 0) {
            [arr addObject:name];
        }
    }
    return arr;
}




- (NSArray<NSString *> *)encodeSel:(NSString *)selName properytArr:(NSMutableArray<NSString *> *)propertyArr{
    NSArray<NSString *> *arr = [selName componentsSeparatedByString:@":"];
    NSMutableArray<NSString *> *trans = [NSMutableArray array];
    static NSMutableDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dic = [NSMutableDictionary dictionary];
    });
    for (NSString *str in arr) {
        if ([str hasPrefix:@"set"]) {///setter方法
            NSString *property = [str substringFromIndex:3];
            property = [property stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithFormat:@"%c",[property characterAtIndex:0]].lowercaseString];
            if ([propertyArr containsObject:property]) {///get方法
                [self propertyTransform:property dic:dic inArr:trans];
            }
        }else if ([propertyArr containsObject:str]){///getter方法
            [self propertyTransform:str dic:dic inArr:trans];
        }else{
            [self transformStr:str dic:dic inArr:trans];
        }
        
    }
    return trans;
}

/**
 转换属性的setter或者getter方法

 */
- (void)propertyTransform:(NSString *)str dic:(NSMutableDictionary *)dic inArr:(NSMutableArray *)arr{
    if ([self.blackList containsObject:str]) {
        return;
    }
    NSString *tranStr = [self transformStr:str dic:dic inArr:arr];
    NSString *var = [NSString stringWithFormat:@"_%@",str];
    NSString *varEncode = [NSString stringWithFormat:@"_%@",tranStr];
    if (![dic valueForKey:var]) {
        [arr addObject:[NSString stringWithFormat:@"#define %@ %@",var,varEncode]];
        [dic setValue:varEncode forKey:var];
    }
    NSString *setVar = [NSString stringWithFormat:@"set%@",[str stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithFormat:@"%c",[str characterAtIndex:0]].uppercaseString]];
    NSString *setVarEncode = [NSString stringWithFormat:@"set%@",[tranStr stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[NSString stringWithFormat:@"%c",[tranStr characterAtIndex:0]].uppercaseString]];
    if (![dic valueForKey:setVar]) {
        [arr addObject:[NSString stringWithFormat:@"#define %@ %@",setVar,setVarEncode]];
        [dic setValue:setVarEncode forKey:setVar];
    }
}


- (NSString *)transformStr:(NSString *)str dic:(NSMutableDictionary *)dic inArr:(NSMutableArray *)arr{
    NSString *tranStr;
    if ([dic valueForKey:str]) {
        tranStr = [dic valueForKey:str];
    }
    
    if (str && str.length>0 && ![dic valueForKey:str] && ![_blackList containsObject:str]) {///原方法已经转换过了
        tranStr = [self transform:str];
        NSString *encode = [NSString stringWithFormat:@"#define %@ %@",str,tranStr];
        if ([[dic allValues] containsObject:encode]) {//转换的结果已经存在了
            return [self transformStr:str dic:dic inArr:arr];
        }
        [dic setValue:tranStr forKey:str];
        [arr addObject:encode];
    }
    return tranStr;
}



- (NSString *)transform:(NSString *)str{
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < str.length; i++) {
        [s appendString:[self getRandomChar]];
    }
    return s;
}

- (NSString *)getRandomChar{
    int num = arc4random()%53;
    NSString *charStr;
    if (num<26) {
        charStr = [NSString stringWithFormat:@"%c",num+65];
    }else if(num<52){
        charStr = [NSString stringWithFormat:@"%c",num+71];
    }else{
        charStr = @"_";
    }
    return charStr;
}

@end

