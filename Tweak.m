#include "BioServer.h"
#import "UICKeyChainStore.h"

#define kBundlePath @"/Library/Application Support/net.tottech.banktouch.bundle"

%ctor {
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) {
        [[BioServer sharedInstance] setUpForMonitoring];
    }
}


char observer[10] = "banktouch";
UITextField *codeTextField;
BOOL touchIDSucceeded = NO;
BOOL hasFoundKeyboard = NO;
BOOL observingTouchID = NO;
UIButton *numberButtons[10];
UIButton *submitButton;
char code[] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};

void touchIDSuccess(CFNotificationCenterRef center,
                    void *observer,
                    CFStringRef name,
                    const void *object,
                    CFDictionaryRef userInfo) {
    if (codeTextField != nil && observingTouchID) {
        observingTouchID = NO;
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, CFSTR("net.tottech.backtouch/success"), NULL);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.backtouch/stopMonitoring"), nil, nil, YES);
        
        touchIDSucceeded = YES;
        
        NSString *learnedCode = [UICKeyChainStore stringForKey:@"net.tottech.banktouch.code"];
        for (int i = 0; i < learnedCode.length; i++) {
            NSString *numberString = [learnedCode substringWithRange:NSMakeRange(i, 1)];
            int number = [numberString intValue];
            
            UIButton *button = numberButtons[number];
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
            touchIDSucceeded = NO;
        });
    }
}

void touchIDFail(CFNotificationCenterRef center,
                 void *observer,
                 CFStringRef name,
                 const void *object,
                 CFDictionaryRef userInfo) {
    if (codeTextField != nil) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
        [animation setDuration:0.05];
        [animation setRepeatCount:4];
        [animation setAutoreverses:YES];
        [animation setFromValue:[NSValue valueWithCGPoint:CGPointMake(codeTextField.center.x - 5, codeTextField.center.y)]];
        [animation setToValue:[NSValue valueWithCGPoint:CGPointMake(codeTextField.center.x + 5, codeTextField.center.y)]];
        [codeTextField.layer addAnimation:animation forKey:@"position"];
        codeTextField.layer.borderColor = [UIColor redColor].CGColor;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((animation.duration * (animation.repeatCount * 2)) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
            codeTextField.layer.borderColor = [UIColor greenColor].CGColor;
        });
        
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, CFSTR("net.tottech.backtouch/failure"), NULL);
    }
}


%hook UITextField

- (void)setPlaceholder:(NSString *)placeholder {
    %orig;
    
    if ([placeholder isEqualToString:@"Security Code"] || [placeholder isEqualToString:@"Säkerhetskod"]) {
        codeTextField = self;
    }
}

%end


/**
 * Since BankID crashes when hooking BankIDAppDelegate,
 * we have to use a different approach.
 */

@interface UIApplication (BankTouch)
- (void)addTouchIDIndicatorOfSize:(CGSize)size toView:(UIView *)view;
- (void)textFieldDidBeginEditingNotification:(NSNotification *)notification;
@end


%hook UIApplication

- (id)init {
    id original = %orig;
    
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) {
        return original;
    }
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(textFieldDidBeginEditingNotification:)
     name:UITextFieldTextDidBeginEditingNotification object:nil];
    
    return original;
}

- (void)applicationWillSuspend {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.backtouch/stopMonitoring"), nil, nil, YES);
    %orig;
}

%new
- (void)addTouchIDIndicatorOfSize:(CGSize)size toView:(UIView *)view {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        NSBundle *bundle = [[NSBundle alloc] initWithPath:kBundlePath];
        NSString *imagePath = [bundle pathForResource:@"touchid-blue" ofType:@"png"];
        
        UIImageView *touchIDView = [[UIImageView alloc] init];
        touchIDView.image = [UIImage imageWithContentsOfFile:imagePath];
        
        CGFloat containerWidth = view.frame.size.width;
        CGFloat containerHeight = view.frame.size.height;
        CGFloat x = containerWidth/2 - size.width/2;
        CGFloat y = containerHeight/2 - size.height/2;
        CGRect frame = CGRectMake(x, y, size.width, size.height);
        touchIDView.frame = frame;
        
        [view addSubview:touchIDView];
    });
}

%new
- (void)textFieldDidBeginEditingNotification:(NSNotification *)notification {
    // reset code field if user wants to enter and learn another code
    for (int i = 0; i < sizeof(code); i++) {
        code[i] = -1;
    }
    
    [NSThread detachNewThreadSelector:@selector(prepareTouchID) toTarget:self withObject:nil];
}

%new
- (void)prepareTouchID {
    if (!hasFoundKeyboard) {
        NSArray *windows;
        UIView *keyboardWindow = nil;
        
        while (keyboardWindow == nil) {
            windows = self.windows;
            
            for (UIWindow *window in windows) {
                const char *className = class_getName([window class]);
                NSString *classNameString = [NSString stringWithUTF8String:className];
                if ([@"UIRemoteKeyboardWindow" isEqualToString:classNameString]) {
                    hasFoundKeyboard = YES;
                    keyboardWindow = window;
                    break;
                }
            }
            [NSThread sleepForTimeInterval:0.1];
        }
        
        while (keyboardWindow.subviews.count == 0) {
            [NSThread sleepForTimeInterval:0.05];
        }
        UIView *inputContainerView = [keyboardWindow.subviews objectAtIndex:0];
        
        while (inputContainerView.subviews.count == 0) {
            [NSThread sleepForTimeInterval:0.05];
        }
        UIView *inputHostView = [inputContainerView.subviews objectAtIndex:0];
        
        while (inputHostView.subviews.count < 1) {
            [NSThread sleepForTimeInterval:0.05];
        }
        UIView *inputViewController = [inputHostView.subviews objectAtIndex:1];
        
        while (inputViewController.subviews.count < 4*3) {
            [NSThread sleepForTimeInterval:0.1];
        }
        NSArray *buttons = inputViewController.subviews;
        for (UIButton *button in buttons) {
            if (button.tag >= 0) {
                numberButtons[button.tag] = button;
            } else if (button.tag == -2) {
                submitButton = button;
            }
            [button addTarget:self action:@selector(numberButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        }
    }
    
    NSString *learnedCode = [UICKeyChainStore stringForKey:@"net.tottech.banktouch.code"];
    NSString *oldPlaceholder = codeTextField.placeholder;
    
    NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
    NSDictionary *languageComponents = [NSLocale componentsFromLocaleIdentifier:language];
    NSString *languageCode = [languageComponents objectForKey:@"kCFLocaleLanguageCodeKey"];
    
    BOOL isEnglish = NO;
    if ([languageCode isEqualToString:@"en"]) {
        isEnglish = YES;
    }
    
    while (codeTextField == nil) {
        [NSThread sleepForTimeInterval:0.01];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        NSString *appendedPlaceholder;
        NSString *newPlaceholder;
        
        if (learnedCode == nil) {
            appendedPlaceholder = (isEnglish ? @"to learn TouchID" : @"för att lära TouchID");
            codeTextField.layer.borderColor = [UIColor orangeColor].CGColor;
            codeTextField.layer.borderWidth = 2;
        } else {
            if (!observingTouchID) {
                observingTouchID = YES;
                [NSThread detachNewThreadSelector:@selector(sendPeriodicActiveNotifications) toTarget:self withObject:nil];
                
                CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, &touchIDSuccess, CFSTR("net.tottech.banktouch/success"), NULL, 0);
                CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, &touchIDFail, CFSTR("net.tottech.banktouch/failure"), NULL, 0);
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.banktouch/startMonitoring"), nil, nil, YES);
            }
            
            appendedPlaceholder = (isEnglish ? @"or TouchID" : @"eller TouchID");
            codeTextField.layer.borderColor = [UIColor greenColor].CGColor;
            codeTextField.layer.borderWidth = 1;
        }
        
        newPlaceholder = [oldPlaceholder stringByAppendingFormat:@" %@", appendedPlaceholder];
        codeTextField.placeholder = newPlaceholder;
        codeTextField.layer.cornerRadius = 5;
        
        
        int textFieldWidth = codeTextField.frame.size.width;
        int textFieldHeight = codeTextField.frame.size.height;
        int smallIndicatorSize = textFieldHeight - 8;
        int containerX = textFieldWidth - smallIndicatorSize - 4;
        
        UIView *smallIndicatorContainerView = [[UIView alloc] init];
        CGRect containerFrame = CGRectMake(containerX, 4, smallIndicatorSize, smallIndicatorSize);
        smallIndicatorContainerView.frame = containerFrame;
        
        [codeTextField addSubview:smallIndicatorContainerView];
        [self addTouchIDIndicatorOfSize:CGSizeMake(smallIndicatorSize, smallIndicatorSize) toView:smallIndicatorContainerView];
    });
}

%new
- (void)numberButtonAction:(id)sender {
    if (touchIDSucceeded) {
        // ignore
        return;
    }
    
    UIButton *button = (UIButton *)sender;
    long number = button.tag;
    
    int codeNumberIndex = -1;
    for (int i = 0; i < sizeof(code); i++) {
        int number = code[i];
        if (number == -1) {
            codeNumberIndex = i;
            break;
        }
    }
    
    if (button.tag == -1) {
        // delete button
        code[codeNumberIndex-1] = -1;
    } else if (button.tag == -2) {
        // submit button
        NSMutableString *learnedCode = [NSMutableString new];
        for (int i = 0; i < sizeof(code); i++) {
            int number = code[i];
            if (number == -1) {
                break;
            }
            [learnedCode appendFormat:@"%d", number];
        }
        
        if (learnedCode.length == 0) {
            return;
        }
        
        [UICKeyChainStore setString:learnedCode forKey:@"net.tottech.banktouch.code"];
    } else {
        code[codeNumberIndex] = number;
    }
}

%new
- (void)sendPeriodicActiveNotifications {
    while (YES) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.banktouch/appActive"), nil, nil, YES);
        [NSThread sleepForTimeInterval:0.5];
    }
}

%end