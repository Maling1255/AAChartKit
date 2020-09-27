//
//  AAChartView.m
//  AAChartKit
//
//  Created by An An on 17/1/16.
//  Copyright © 2017年 An An. All rights reserved.
//*************** ...... SOURCE CODE ...... ***************
//***...................................................***
//*** https://github.com/AAChartModel/AAChartKit        ***
//*** https://github.com/AAChartModel/AAChartKit-Swift  ***
//***...................................................***
//*************** ...... SOURCE CODE ...... ***************

/*
 
 * -------------------------------------------------------------------------------
 *
 * 🌕 🌖 🌗 🌘  ❀❀❀   WARM TIPS!!!   ❀❀❀ 🌑 🌒 🌓 🌔
 *
 * Please contact me on GitHub,if there are any problems encountered in use.
 * GitHub Issues : https://github.com/AAChartModel/AAChartKit/issues
 * ------------------------------------------------------------------------------
 * And if you want to contribute for this project, please contact me as well
 * GitHub        : https://github.com/AAChartModel
 * StackOverflow : https://stackoverflow.com/users/7842508/codeforu
 * JianShu       : https://www.jianshu.com/u/f1e6753d4254
 * SegmentFault  : https://segmentfault.com/u/huanghunbieguan
 *
 * -------------------------------------------------------------------------------
 
 */

#import "AAChartView.h"
#import "NSString+toPureJSString.h"

@interface AAWeakProxy : NSProxy

@property (nonatomic, weak, readonly, nullable) id target;

+ (nonnull instancetype)proxyWithTarget:(nonnull id)target;

@end

@implementation AAWeakProxy

- (instancetype)initWithTarget:(id)target {
    _target = target;
    return self;
}

+ (instancetype)proxyWithTarget:(id)target {
    return [[AAWeakProxy alloc] initWithTarget:target];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    return _target;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    void *null = NULL;
    [invocation setReturnValue:&null];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [_target respondsToSelector:aSelector];
}

@end

@implementation AAMoveOverEventMessageModel

@end

/**
 *  The console output log
 */
#ifdef DEBUG // Debug status, open the LOG function
#define AADetailLog(fmt, ...) NSLog((@"-------> %@ [Line %d] \n"fmt "\n\n"), \
[[NSString stringWithFormat:@"%s",__FILE__] lastPathComponent], __LINE__, ##__VA_ARGS__);
#else // Release status, turn off the LOG function
#define AADetailLog(...)
#endif

static NSString * const kUserContentMessageNameMouseOver = @"mouseover";
static NSString * const kUserContentMessageNameCustomEvent = @"customevent";

@interface AAChartView() <
WKUIDelegate,
WKNavigationDelegate,
WKScriptMessageHandler
> {
    NSString  *_optionJson;
    BOOL _mouseOverEventEnabled;
    BOOL _customEventEnabled;
}

@property (nonatomic, strong) AAWeakProxy *weakProxy;
@property (nonatomic, strong, readwrite) AAChartModel *chartModel;

@end

@implementation AAChartView

- (instancetype)initWithFrame:(CGRect)frame {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = [[WKUserContentController alloc] init];
    self = [super initWithFrame:frame configuration:config];
    
    if (self) {
        self.UIDelegate = self;
        self.navigationDelegate = self;
        self.backgroundColor = [UIColor whiteColor];
    }
    return self;
}


#pragma mark - 绘制 & 刷新

/**
 * 图表视图对象调用图表模型对象,绘制最终图形
 */
- (void)aa_drawChartWithChartModel:(AAChartModel *)chartModel {
    
    AAOptions *options = [AAOptionsConstructor configureChartOptionsWithAAChartModel:chartModel];
    [self aa_drawChartWithOptions:options];
}

/**
 * 更新 AAChartModel 内容之后,刷新图表
 */
- (void)aa_refreshChartWithChartModel:(AAChartModel *)chartModel {
    AAOptions *options = [AAOptionsConstructor configureChartOptionsWithAAChartModel:chartModel];
    [self aa_refreshChartWithOptions:options];
}

/**
 * 仅仅更新 AAChartModel 对象的 series 属性时,动态刷新图表
 * (进行数据的动态更新操作时,建议使用此方法)
 * 刷新图形除数据属性 series 以外的其他属性(首次绘制图形完成之后,后续刷新图表的属性均建议调用此方法 注意:仅仅刷新图形数据,则建议使用上面的👆aa_onlyRefreshTheChartDataWithChartModelSeries方法)
 */
- (void)aa_onlyRefreshTheChartDataWithChartModelSeries:(NSArray<AASeriesElement *> *)series {
    [self aa_onlyRefreshTheChartDataWithOptionsSeries:series];
}

- (void)aa_onlyRefreshTheChartDataWithChartModelSeries:(NSArray<AASeriesElement *> *)series
                                             animation:(BOOL)animation {
    [self aa_onlyRefreshTheChartDataWithOptionsSeries:series animation:animation];
}


#pragma mark - options 配置更新
#pragma CONFIGURE THE CHART VIEW CONTENT WITH AAOPTIONS

- (void)aa_drawChartWithOptions:(AAOptions *)options {
    if (!_optionJson) {
        [self configureTheOptionsJsonStringWithAAOptions:options];
        NSURLRequest *URLRequest = [self getJavaScriptFileURLRequest];
        [self loadRequest:URLRequest];
    } else {
        [self aa_refreshChartWithOptions:options];
    }
}

- (void)aa_refreshChartWithOptions:(AAOptions *)options {
    [self configureTheOptionsJsonStringWithAAOptions:options];
    [self drawChart];
}

- (void)aa_onlyRefreshTheChartDataWithOptionsSeries:(NSArray<AASeriesElement *> *)series {
    [self aa_onlyRefreshTheChartDataWithOptionsSeries:series animation:true];
}

- (void)aa_onlyRefreshTheChartDataWithOptionsSeries:(NSArray<AASeriesElement *> *)series
                                          animation:(BOOL)animation {
    NSMutableArray *seriesDicArr = [NSMutableArray arrayWithCapacity:series.count];
    for (AASeriesElement *aaSeriesElement in series) {
        [seriesDicArr addObject:[AAJsonConverter dictionaryWithObjectInstance:aaSeriesElement]];
    }
    
    NSString *seriesJsonStr = [AAJsonConverter pureJsonStringWithJsonObject:seriesDicArr];
    NSString *jsStr = [NSString stringWithFormat:@"onlyRefreshTheChartDataWithSeries('%@','%d')",
                       seriesJsonStr,
                       animation];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)aa_updateChartWithOptions:(id)options {
    [self aa_updateChartWithOptions:options redraw:false];
}

- (void)aa_updateChartWithOptions:(id)options redraw:(BOOL)redraw {
    BOOL isOptionsClass = [options isKindOfClass:[AAOptions class]];
    NSDictionary *optionsDic = [AAJsonConverter dictionaryWithObjectInstance:options];
    NSDictionary *finalOptionsDic;
    if (isOptionsClass) {
        finalOptionsDic = optionsDic;
    } else {
        // 转成
        NSString *classNameStr = NSStringFromClass([options class]);
        classNameStr = [classNameStr stringByReplacingOccurrencesOfString:@"AA"
                                                               withString:@""];
        
        //convert fisrt character to be lowercase string
        NSString *firstChar = [classNameStr substringToIndex:1];
        NSString *lowerFirstChar = [firstChar lowercaseString];
        classNameStr = [classNameStr substringFromIndex:1];
        NSString *finalClassNameStr = [NSString stringWithFormat:@"%@%@",
                                       lowerFirstChar,
                                       classNameStr];
        finalOptionsDic = @{finalClassNameStr:optionsDic};
    }
    
    NSString *optionsStr = [AAJsonConverter pureOptionsJsonStringWithOptionsInstance:finalOptionsDic];
    NSString *jsStr = [NSString stringWithFormat:@"updateChart('%@','%d')",
                       optionsStr,
                       redraw];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)aa_addPointToChartSeriesElementWithElementIndex:(NSUInteger)elementIndex
                                                options:(id)options {
    [self aa_addPointToChartSeriesElementWithElementIndex:elementIndex
                                                  options:options
                                                    shift:true];
}

- (void)aa_addPointToChartSeriesElementWithElementIndex:(NSUInteger)elementIndex
                                                options:(id)options
                                                  shift:(BOOL)shift {
    [self aa_addPointToChartSeriesElementWithElementIndex:elementIndex
                                                  options:options
                                                   redraw:true
                                                    shift:shift
                                                animation:true];
}

- (void)aa_addPointToChartSeriesElementWithElementIndex:(NSUInteger)elementIndex
                                                options:(id)options
                                                 redraw:(BOOL)redraw
                                                  shift:(BOOL)shift
                                              animation:(BOOL)animation {
    NSString *optionsStr;
    if ([options isKindOfClass:[NSNumber class]]) {
        optionsStr = [NSString stringWithFormat:@"%@",options];
    } else if ([options isKindOfClass:[NSArray class]]) {
        optionsStr = [AAJsonConverter pureJsonStringWithJsonObject:options];
    } else {
        NSDictionary *dic = [AAJsonConverter dictionaryWithObjectInstance:options];
        optionsStr = [AAJsonConverter pureJsonStringWithJsonObject:dic];
    }
    
    NSString *jsStr = [NSString stringWithFormat:@"addPointToChartSeries('%tu','%@','%d','%d','%d')",
                       elementIndex,
                       optionsStr,
                       redraw,
                       shift,
                       animation];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)aa_addPointsToChartSeriesArrayWithOptionsArray:(NSArray *)optionsArr {
    [self aa_addPointsToChartSeriesArrayWithOptionsArray:optionsArr shift:true animation:true];
}

- (void)aa_addPointsToChartSeriesArrayWithOptionsArray:(NSArray *)optionsArr
                                                 shift:(BOOL)shift
                                             animation:(BOOL)animation {
    [optionsArr enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self aa_addPointToChartSeriesElementWithElementIndex:idx
                                                      options:obj
                                                       redraw:false
                                                        shift:shift
                                                    animation:false];
    }];
    [self aa_redrawWithAnimation:animation];
}

- (void)aa_addElementToChartSeriesWithElement:(AASeriesElement *)element {
    NSDictionary * elementDic = [AAJsonConverter dictionaryWithObjectInstance:element];
    NSString *elementStr = [AAJsonConverter pureJsonStringWithJsonObject:elementDic];
    NSString *jsStr = [NSString stringWithFormat:@"addElementToChartSeriesWithElement('%@')",
                       elementStr];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)aa_removeElementFromChartSeriesWithElementIndex:(NSUInteger)elementIndex {
    NSString *jsStr = [NSString stringWithFormat:@"removeElementFromChartSeriesWithElementIndex('%tu')",
                       elementIndex];
    [self safeEvaluateJavaScriptString:jsStr];
}


- (void)aa_showTheSeriesElementContentWithSeriesElementIndex:(NSUInteger)elementIndex {
    NSString *jsStr = [NSString stringWithFormat:@"showTheSeriesElementContentWithIndex('%tu')",
                       elementIndex];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)aa_hideTheSeriesElementContentWithSeriesElementIndex:(NSUInteger)elementIndex {
    NSString *jsStr = [NSString stringWithFormat:@"hideTheSeriesElementContentWithIndex('%tu')",
                       elementIndex];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)aa_evaluateJavaScriptStringFunction:(NSString *)JavaScriptString {
    NSString *pureJSFuncStr = [JavaScriptString aa_toPureJSString];
    
    //remove the useless punctuation: the first "((" and the end "))"
    NSRange range = NSMakeRange(2, pureJSFuncStr.length - 4);
    pureJSFuncStr = [pureJSFuncStr substringWithRange:range];
    
    NSString *jsFunctionNameStr = [NSString stringWithFormat:@"evaluateTheJavaScriptStringFunction('%@')",
                                   pureJSFuncStr];
    [self safeEvaluateJavaScriptString:jsFunctionNameStr];
}

- (void)aa_updateXAxisCategories:(NSArray *)categories {
    [self aa_updateXAxisCategories:categories redraw:true];
}

- (void)aa_updateXAxisCategories:(NSArray *)categories redraw:(BOOL)redraw {
    NSString *originalJsArrStr = @"";
    for (NSString *category in categories) {
        originalJsArrStr = [originalJsArrStr stringByAppendingFormat:@"'%@',",category];
    }
    NSString *finalJSArrStr = [NSString stringWithFormat:@"[%@]",originalJsArrStr];
    
    NSString *jsFunctionStr = [NSString stringWithFormat:@"aaGlobalChart.xAxis[0].setCategories(%@,%d)",
                              finalJSArrStr,
                              redraw];
    [self safeEvaluateJavaScriptString:jsFunctionStr];
}

- (void)aa_updateXAxisExtremesWithMin:(NSUInteger)min max:(NSUInteger)max {
    NSString *jsFuntionStr = [NSString stringWithFormat:@"aaGlobalChart.xAxis[0].setExtremes(%lu,%lu)",
                              min, max];
    [self safeEvaluateJavaScriptString:jsFuntionStr];
}

- (void)aa_redrawWithAnimation:(BOOL)animation {
    NSString *jsStr = [NSString stringWithFormat:@"redrawWithAnimation('%d')",animation];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)aa_adaptiveScreenRotation {
    [self aa_adaptiveScreenRotationWithAnimation:nil];
}

- (void)aa_adaptiveScreenRotationWithAnimation:(AAAnimation *)animation {
    __weak __typeof__(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [weakSelf handleDeviceOrientationChangeEventWithAnimation:animation];
    }];
}

- (void)handleDeviceOrientationChangeEventWithAnimation:(AAAnimation *)animation {
    [self aa_changeChartSizeWithWidth:self.frame.size.width
                               height:self.frame.size.height
                            animation:animation];
}

- (void)aa_changeChartSizeWithWidth:(CGFloat)width
                             height:(CGFloat)height
                          animation:(AAAnimation *)animation {
    NSString *animationJsonStr = [AAJsonConverter pureOptionsJsonStringWithOptionsInstance:animation];
    NSString *jsFuntionStr = [NSString stringWithFormat:@"changeChartSize('%f','%f','%@')",
                              width,
                              height,
                              animationJsonStr];
    [self safeEvaluateJavaScriptString:jsFuntionStr];
}


- (NSURLRequest *)getJavaScriptFileURLRequest {
    NSString *resourcePath = [[NSBundle bundleForClass:[self class]] resourcePath];
    NSString *bundlePath = [resourcePath stringByAppendingPathComponent:@"/AAChartKitLib.bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    if (!bundle) { //installed manually
        bundle = [NSBundle mainBundle];
    }
    NSString *webPath = [bundle pathForResource:@"AAChartView"
                                         ofType:@"html"
                                    inDirectory:@"AAJSFiles.bundle"];
    NSURL *webURL = [NSURL fileURLWithPath:webPath];
    if ([[UIDevice currentDevice].systemVersion floatValue] < 9.0) {
        webURL = [self localFileURLForBuggyiOS8WKWebViewWithFileURL:webURL];
    }
    
    NSURLRequest *URLRequest = [[NSURLRequest alloc] initWithURL:webURL];
    return URLRequest;
}

- (NSURL *)localFileURLForBuggyiOS8WKWebViewWithFileURL:(NSURL *)fileURL {
    // Create "/tmp/www" directory
    NSError *creatDirError = nil;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    NSURL *tmpWwwDirURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"www"];
    NSString *htmlFileName = @"AAChartView.html";
    NSString *tmpJsFilesDir = [tmpWwwDirURL.absoluteString stringByAppendingString:@"/"];
    NSURL *destURL = [NSURL URLWithString:[tmpJsFilesDir stringByAppendingString:htmlFileName]];

    BOOL isDir = NO;
    BOOL isTmpWwwDirExist = [fileManager fileExistsAtPath:tmpWwwDirURL.path isDirectory:&isDir];
    if (isTmpWwwDirExist) {
        return destURL;
    }
    
    [fileManager createDirectoryAtURL:tmpWwwDirURL
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&creatDirError];
    if (creatDirError) {
        AADetailLog("creat directory error%@",creatDirError);
    }
    
    NSString *bundleFilesDir = [fileURL.absoluteString stringByReplacingOccurrencesOfString:htmlFileName
                                                                                 withString:@""];
    
    NSArray *array = @[htmlFileName,
                       @"AAEasing.js",
                       @"AAFunnel.js",
                       @"AAHighchartsLib.js",
                       @"AAHighchartsMore.js",
                       @"AARoundedCorners.js",
                       ];
    
    [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *bundleFilePath = [bundleFilesDir stringByAppendingString:obj];
        NSString *tmpFilePath = [tmpJsFilesDir stringByAppendingString:obj];
        // Now copy bundle files to the temp directory
        NSError *copyItemError = nil;
        [fileManager copyItemAtURL:[NSURL URLWithString:bundleFilePath]
                             toURL:[NSURL URLWithString:tmpFilePath]
                             error:&copyItemError];
        if (copyItemError) {
            AADetailLog("copy file Error%@",copyItemError);
        }
    }];
    return destURL;
}

- (void)configureTheOptionsJsonStringWithAAOptions:(AAOptions *)aaOptions {
    if (self.isClearBackgroundColor) {
        aaOptions.chart.backgroundColor = @"rgba(0,0,0,0)";
    }
    if (_mouseOverEventEnabled == true) {
        aaOptions.touchEventEnabled = true;
    }
    
    _optionJson = [AAJsonConverter pureOptionsJsonStringWithOptionsInstance:aaOptions];
}

#pragma mark - WKUIDelegate
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"JS WARNING"
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:([UIAlertAction actionWithTitle:@"Okay"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }])];
    
    UIViewController *alertHelperController = [[UIViewController alloc]init];
    [self addSubview:alertHelperController.view];
    
    [alertHelperController presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - AAChartView Event Handler
- (void)didFinishLoadHandler:(AADidFinishLoadBlock)handler {
    self.didFinishLoadBlock = handler;
}

- (void)moveOverEventHandler:(AAMoveOverEventBlock)handler {
    self.moveOverEventBlock = handler;
}

- (void)didReceiveScriptMessageHandler:(AADidReceiveScriptMessageBlock)handler {
    self.didReceiveScriptMessageBlock = handler;
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self drawChart];
    if (self.didFinishLoadBlock) {
        self.didFinishLoadBlock(self);
        return;
    }
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(aaChartViewDidFinishLoad:)]) {
            [self.delegate aaChartViewDidFinishLoad:self];
        }
    }
}

- (void)drawChart {
    NSString *jsStr = [NSString stringWithFormat:@"loadTheHighChartView('%@','%f','%f')",
                       _optionJson,
                       self.contentWidth,
                       self.contentHeight ];
    [self safeEvaluateJavaScriptString:jsStr];
}

#pragma mark - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:kUserContentMessageNameMouseOver]) {
        AAMoveOverEventMessageModel *eventMessageModel = [self eventMessageModelWithMessageBody:message.body];
        if (self.moveOverEventBlock) {
            self.moveOverEventBlock(self, eventMessageModel);
            return;
        }
        
        [self.delegate aaChartView:self moveOverEventWithMessage:eventMessageModel];
    } else if ([message.name isEqualToString:kUserContentMessageNameCustomEvent]) {
        if (self.didReceiveScriptMessageBlock) {
            self.didReceiveScriptMessageBlock(self, message);
            return;
        }
        
        [self.delegate aaChartView:self didReceiveScriptMessage:message];
    }
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    
    NSLog(@"sssssss");
}

- (AAMoveOverEventMessageModel *)eventMessageModelWithMessageBody:(id)messageBody {
    AAMoveOverEventMessageModel *eventMessageModel = AAMoveOverEventMessageModel.new;
    eventMessageModel.name = messageBody[@"name"];
    eventMessageModel.x = messageBody[@"x"];
    eventMessageModel.y = messageBody[@"y"];
    eventMessageModel.category = messageBody[@"category"];
    eventMessageModel.offset = messageBody[@"offset"];
    eventMessageModel.index = [messageBody[@"index"] unsignedIntegerValue];
    return eventMessageModel;
}


#pragma mark - 真正执行
- (void)safeEvaluateJavaScriptString:(NSString *)functionNameStr {
    if (!_optionJson) {
        AADetailLog("💀💀💀AAChartView did not finish loading!!!")
        return;
    }
    
    [self evaluateJavaScript:functionNameStr completionHandler:^(id item, NSError * _Nullable error) {
#if DEBUG
        if (!error) return;
        NSMutableDictionary *errorDic = [NSMutableDictionary dictionary];
        [errorDic setValue:error.domain forKey:@"domain"];
        [errorDic setValue:@(error.code) forKey:@"code"];
        [errorDic setValue:error.userInfo forKey:@"userInfo"];
        [errorDic setValue:error.localizedFailureReason forKey:@"localizedFailureReason"];
        [errorDic setValue:error.localizedDescription forKey:@"localizedDescription"];
        
        NSString *basicErrorInfo = @"\n                                                     \n\
☠️☠️💀☠️☠️WARNING!!!!!!!!!!!!!!!!!! JS ERROR WARNING !!!!!!!!!!!!!!!!!!WARNING☠️☠️💀☠️☠️ \
⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩⇩  \
------------------------------------------------------------------------------------------\n\
%@                                                                                          \
------------------------------------------------------------------------------------------  \
⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧⇧\n\
☠️☠️💀☠️☠️WARNING!!!!!!!!!!!!!!!!!! JS ERROR WARNING !!!!!!!!!!!!!!!!!!WARNING☠️☠️💀☠️☠️\n\n";
        
        NSString *errorInfoStr = [NSString stringWithFormat:basicErrorInfo,errorDic];
        NSLog(@"%@",errorInfoStr);
#endif
    }];
}

#pragma mark -- setter method

- (void)setContentInsetAdjustmentBehavior:(UIScrollViewContentInsetAdjustmentBehavior)contentInsetAdjustmentBehavior {
    _contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior;
    self.scrollView.contentInsetAdjustmentBehavior = _contentInsetAdjustmentBehavior;
}

- (void)setScrollEnabled:(BOOL)scrollEnabled {
    _scrollEnabled = scrollEnabled;
    self.scrollView.scrollEnabled = _scrollEnabled;
}

- (void)setContentWidth:(CGFloat)contentWidth {
    _contentWidth = contentWidth;
    NSString *jsStr = [NSString stringWithFormat:@"setTheChartViewContentWidth('%f')",
                       _contentWidth];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)setContentHeight:(CGFloat)contentHeight {
    _contentHeight = contentHeight;
    NSString *jsStr = [NSString stringWithFormat:@"setTheChartViewContentHeight('%f')",
                       _contentHeight];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)setChartSeriesHidden:(BOOL)chartSeriesHidden {
    _chartSeriesHidden = chartSeriesHidden;
    NSString *jsStr = [NSString stringWithFormat:@"setChartSeriesHidden('%d')",
                       _chartSeriesHidden];
    [self safeEvaluateJavaScriptString:jsStr];
}

- (void)setIsClearBackgroundColor:(BOOL)isClearBackgroundColor {
    _isClearBackgroundColor = isClearBackgroundColor;
    if (_isClearBackgroundColor) {
        [self setBackgroundColor:[UIColor clearColor]];
        [self setOpaque:NO];
    } else {
        self.backgroundColor = [UIColor whiteColor];
        [self setOpaque:YES];
    }
}

- (void)setDelegate:(id<AAChartViewEventDelegate>)delegate {
    NSAssert(_optionJson == nil, @"You should set delegate before drawing chart");
    _delegate = delegate;
    
    if (self.delegate && ([self.delegate respondsToSelector:@selector(aaChartView:moveOverEventWithMessage:)])) {
        _mouseOverEventEnabled = true;
        [self addMouseOverEventMessageHandler];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector((aaChartView:didReceiveScriptMessage:))]) {
        _customEventEnabled = true;
        [self addCustomEventMessageHandler];
    }
}

-(void)setMoveOverEventBlock:(AAMoveOverEventBlock)moveOverEventBlock {
    NSAssert(_optionJson == nil, @"You should set moveOverEventBlock before drawing chart");
    _moveOverEventBlock = moveOverEventBlock;
    if (self.moveOverEventBlock) {
        _mouseOverEventEnabled = true;
        [self addMouseOverEventMessageHandler];
    }
}

- (void)setDidReceiveScriptMessageBlock:(AADidReceiveScriptMessageBlock)didReceiveScriptMessageBlock {
    NSAssert(_optionJson == nil, @"You should set didReceiveScriptMessageBlock before drawing chart");
    _didReceiveScriptMessageBlock = didReceiveScriptMessageBlock;
    if (self.didReceiveScriptMessageBlock) {
        _customEventEnabled = true;
        [self addCustomEventMessageHandler];
    }
}

- (void)addMouseOverEventMessageHandler {
    [self.configuration.userContentController addScriptMessageHandler:(id<WKScriptMessageHandler>)self.weakProxy
                                                                 name:kUserContentMessageNameMouseOver];
}

- (void)addCustomEventMessageHandler {
    [self.configuration.userContentController addScriptMessageHandler:(id<WKScriptMessageHandler>)self.weakProxy
                                                                 name:kUserContentMessageNameCustomEvent];
}

#pragma mark -- getter method
- (AAWeakProxy *)weakProxy {
    if (!_weakProxy) {
        _weakProxy = [AAWeakProxy proxyWithTarget:self];
    }
    return _weakProxy;
}

- (void)dealloc {
    [self.configuration.userContentController removeAllUserScripts];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    AADetailLog("👻👻👻 AAChartView was destroyed!!!");
}

@end



#import <objc/runtime.h>

@implementation AAJsonConverter


+ (NSDictionary*)dictionaryWithObjectInstance:(id)objc {
    unsigned int propsCount;
    objc_property_t *props = class_copyPropertyList([objc class], &propsCount);
    NSMutableDictionary *propsDic = [NSMutableDictionary dictionaryWithCapacity:propsCount];

    for (NSUInteger i = 0; i < propsCount; i++) {
        objc_property_t prop = props[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(prop)];
        id value = [objc valueForKey:propName];
        if (value == nil) {
            value = [NSNull null];
            continue;
        } else {
            value = [self getObjectInternal:value];
        }
        propsDic[propName] = value;
    }
    free(props);
    
    return propsDic;
}

+ (id)getObjectInternal:(id)objc {
    if (   [objc isKindOfClass:[NSString class]]
        || [objc isKindOfClass:[NSNumber class]]
        || [objc isKindOfClass:[NSNull   class]] ) {
        return objc;
    }
    
    if ([objc isKindOfClass:[NSArray class]]) {
        NSArray *objcArr = objc;
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:objcArr.count];
        for (id element in objcArr) {
            [arr addObject:[self getObjectInternal:element]];
        }
        return arr;
    }
    
    if ([objc isKindOfClass:[NSDictionary class]]) {
        NSDictionary *objcDic = objc;
        NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:[objcDic count]];
        NSArray *allKeys = objcDic.allKeys;
        for (NSString *key in allKeys) {
            dic[key] = [self getObjectInternal:objcDic[key]];
        }
        return dic;
    }
    
    return [self dictionaryWithObjectInstance:objc];
}


/// 模型转成json
/// @param optionsObject optionsObject 模型对象 | 字典
+ (NSString *)pureOptionsJsonStringWithOptionsInstance:(id)optionsObject {
    NSDictionary *dic;
    if ([optionsObject isKindOfClass:[NSDictionary class]] ) {
        dic = optionsObject;
    } else {
        dic = [self dictionaryWithObjectInstance:optionsObject];
    }
#if DEBUG
    [AAJsonConverter printPrettyPrintedJsonStringWithJsonObject:dic];
#endif
    return [self pureJsonStringWithJsonObject:dic];
}

+ (NSString*)pureJsonStringWithJsonObject:(id)jsonObject {
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject
                                                       options:kNilOptions
                                                         error:&error];
    NSString *pureJsonStr =[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (error) {
        AADetailLog(@"❌❌❌ pure JSONString with JSONObject serialization failed：%@", error);
        return nil;
    }
    return pureJsonStr;
}

#if DEBUG
+ (NSString*)printPrettyPrintedJsonStringWithJsonObject:(id)jsonObject {
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    NSString *jsonStr =[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//    NSLog(@"\naaa、aa----------- console log AAOptions JSON information of AAChartView -----------:\n%@",jsonStr);
    
    if (error) {
        NSLog(@"❌❌❌ pretty printed JSONString with JSONObject serialization failed：%@", error);
        return nil;
    }
    return jsonStr;
}
#endif


@end




