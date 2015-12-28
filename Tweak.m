/**
 * Since BankID crashes when hooking BankIDAppDelegate,
 * we have to use a different approach.
 */

#include "BioServer.h"
#import "UICKeyChainStore.h"

%ctor {
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) {
        [[BioServer sharedInstance] setUpForMonitoring];
    }
}


char observer[10] = "banktouch";
UITextField *codeTextField = nil;
UIButton *numberButtons[10];
UIButton *submitButton;
char code[] = {-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1};

void touchIDSuccess(CFNotificationCenterRef center,
                    void *observer,
                    CFStringRef name,
                    const void *object,
                    CFDictionaryRef userInfo) {
    if (codeTextField != nil) {
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, CFSTR("net.tottech.backtouch/success"), NULL);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.backtouch/stopMonitoring"), nil, nil, YES);
        
        for (int i = 0; i < sizeof(code)/sizeof(code[0]); i++) {
            int number = (int)code[i];
            if (number == -1) {
                break;
            }
            
            UIButton *button = numberButtons[number];
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
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


%hook UIApplication

- (id)init {
    id original = %orig;
    
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) {
        return original;
    }
    
    [NSThread detachNewThreadSelector:@selector(waitForAuthView) toTarget:self withObject:nil];
    
    return original;
}

- (void)applicationWillSuspend {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.backtouch/stopMonitoring"), nil, nil, YES);
    %orig;
}

%new
- (void)waitForAuthView {
    NSArray *windows = self.windows;
    
    while (windows.count == 0) {
        [NSThread sleepForTimeInterval:0.1];
        windows = self.windows;
    }
    
    UIWindow *mainWindow = [windows objectAtIndex:0];
    UIViewController *viewController = mainWindow.rootViewController;
    UIView *layoutContainerView = viewController.view;
    
    while (layoutContainerView.subviews.count == 0) {
        [NSThread sleepForTimeInterval:0.1];
    }
    UIView *navigationTransitionView = [layoutContainerView.subviews objectAtIndex:0];
    
    while (navigationTransitionView.subviews.count == 0) {
        [NSThread sleepForTimeInterval:0.1];
    }
    UIView *viewControllerWrapperView = [navigationTransitionView.subviews objectAtIndex:0];
    
    while (viewControllerWrapperView.subviews.count == 0) {
        [NSThread sleepForTimeInterval:0.1];
    }
    
    UIView *authSignView = nil;
    
    while (authSignView == nil) {
        UIView *subview = [viewControllerWrapperView.subviews objectAtIndex:0];
        const char *className = class_getName([subview class]);
        NSString *classNameString = [NSString stringWithUTF8String:className];
        if ([@"BIDAuthSignView" isEqualToString:classNameString]) {
            authSignView = subview;
            break;
        }
        
        [NSThread sleepForTimeInterval:0.1];
    }
    
    while (authSignView.subviews.count < 5) {
        [NSThread sleepForTimeInterval:0.25];
    }
    
    UIView *view = nil;
    NSArray *authSignSubviews = nil;
    
    while (view == nil) {
        authSignSubviews = authSignView.subviews;
        
        if (authSignSubviews.count < 5) {
            [NSThread sleepForTimeInterval:0.1];
            continue;
        }
        
        UIView *subview = [authSignView.subviews objectAtIndex:5];
        const char *className = class_getName([subview class]);
        NSString *classNameString = [NSString stringWithUTF8String:className];
        if ([@"UIView" isEqualToString:classNameString]) {
            view = subview;
            break;
        }
        
        [NSThread sleepForTimeInterval:0.1];
    }
    
    view = [authSignView.subviews objectAtIndex:5];
    
    while (view.subviews.count == 0) {
        [NSThread sleepForTimeInterval:0.1];
    }
    codeTextField = [view.subviews objectAtIndex:0];
    
    
    UIView *keyboardWindow = nil;
    
    while (keyboardWindow == nil) {
        windows = self.windows;
        
        for (UIWindow *window in windows) {
            const char *className = class_getName([window class]);
            NSString *classNameString = [NSString stringWithUTF8String:className];
            if ([@"UIRemoteKeyboardWindow" isEqualToString:classNameString]) {
                keyboardWindow = window;
                break;
            }
        }
        [NSThread sleepForTimeInterval:0.2];
    }
    
    while (keyboardWindow.subviews.count == 0) {
        [NSThread sleepForTimeInterval:0.1];
    }
    UIView *inputContainerView = [keyboardWindow.subviews objectAtIndex:0];
    
    while (inputContainerView.subviews.count == 0) {
        [NSThread sleepForTimeInterval:0.1];
    }
    UIView *inputHostView = [inputContainerView.subviews objectAtIndex:0];
    
    while (inputHostView.subviews.count < 1) {
        [NSThread sleepForTimeInterval:0.1];
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
    }
    
    NSString *learnedCode = [UICKeyChainStore stringForKey:@"net.tottech.banktouch.code"];
    
    if (learnedCode == nil) {
        NSArray *buttons = inputViewController.subviews;
        for (UIButton *button in buttons) {
            [button addTarget:self action:@selector(numberButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        }
        
        codeTextField.placeholder = @"Security Code to learn TouchID";
        codeTextField.layer.borderColor = [UIColor greenColor].CGColor;
    } else {
        for (int i = 0; i < sizeof(code) && i < learnedCode.length; i++) {
            NSString *numberString = [learnedCode substringWithRange:NSMakeRange(i, 1)];
            code[i] = [numberString intValue];
        }
        
        [NSThread detachNewThreadSelector:@selector(sendPeriodicActiveNotifications) toTarget:self withObject:nil];
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, &touchIDSuccess, CFSTR("net.tottech.banktouch/success"), NULL, 0);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, &touchIDFail, CFSTR("net.tottech.banktouch/failure"), NULL, 0);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.banktouch/startMonitoring"), nil, nil, YES);
        
        codeTextField.placeholder = @"Security Code or TouchID";
        codeTextField.layer.borderColor = [UIColor greenColor].CGColor;
    }
    
    codeTextField.layer.borderWidth = 1;
    codeTextField.layer.cornerRadius = 5;
}

%new
- (void)numberButtonAction:(id)sender {
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