/**
 * Since BankID crashes when hooking BankIDAppDelegate,
 * we have to use a different approach.
 */

#include "BioServer.h"

%ctor {
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) {
        [[BioServer sharedInstance] setUpForMonitoring];
    }
}


char observer[10] = "banktouch";
UITextField *codeTextField = nil;
UIButton *numberButtons[10];
UIButton *submitButton;

void touchIDSuccess(CFNotificationCenterRef center,
                    void *observer,
                    CFStringRef name,
                    const void *object,
                    CFDictionaryRef userInfo) {
    if (codeTextField != nil) {
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, CFSTR("net.tottech.backtouch/success"), NULL);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.backtouch/stopMonitoring"), nil, nil, YES);
        
        
        int keys[] = {1,2,3,6,5,4};
        for (int i = 0; i < sizeof(keys)/sizeof(keys[0]); i++) {
            int key = (int)keys[i];
            UIButton *button = numberButtons[key];
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
        [animation setFromValue:[NSValue valueWithCGPoint:CGPointMake(codeTextField.center.x, codeTextField.center.y - 10.0f)]];
        [animation setToValue:[NSValue valueWithCGPoint:CGPointMake(codeTextField.center.x, codeTextField.center.y + 10.0f)]];
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
    %log;
    
    id original = %orig;
    UIApplication *app = (UIApplication *)original;
    
    if ([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) {
        return original;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSArray *windows = app.windows;
        HBLogInfo(@"Windows in application:");
        for (UIWindow *window in windows) {
            HBLogDebug(@" · %@", window);
        }
        HBLogInfo(@"");
        
        if (windows.count == 0) return;
        
        UIWindow *mainWindow = [windows objectAtIndex:0];
        
        UIViewController *viewController = mainWindow.rootViewController;
        
        UIView *layoutContainerView = viewController.view;
        
        if (layoutContainerView.subviews.count == 0) return;
        UIView *navigationTransitionView = [layoutContainerView.subviews objectAtIndex:0];
        
        if (navigationTransitionView.subviews.count == 0) return;
        UIView *viewControllerWrapperView = [navigationTransitionView.subviews objectAtIndex:0];
        
        if (viewControllerWrapperView.subviews.count == 0) return;
        UIView *authSignView = [viewControllerWrapperView.subviews objectAtIndex:0];
        
        if (authSignView.subviews.count == 0) return;
        UIView *view = [authSignView.subviews objectAtIndex:5];
        
        if (view.subviews.count == 0) return;
        codeTextField = [view.subviews objectAtIndex:0];
        codeTextField.layer.borderColor = [UIColor greenColor].CGColor;
        codeTextField.layer.borderWidth = 1;
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, &touchIDSuccess, CFSTR("net.tottech.banktouch/success"), NULL, 0);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (void*)observer, &touchIDFail, CFSTR("net.tottech.banktouch/failure"), NULL, 0);
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.banktouch/startMonitoring"), nil, nil, YES);
        
        
        UIView *keyboardWindow = [windows objectAtIndex:windows.count-1];
        
        if (keyboardWindow.subviews.count == 0) return;
        UIView *inputContainerView = [keyboardWindow.subviews objectAtIndex:0];
        
        if (inputContainerView.subviews.count == 0) return;
        UIView *inputHostView = [inputContainerView.subviews objectAtIndex:0];
        
        if (inputHostView.subviews.count < 1) return;
        UIView *inputViewController = [inputHostView.subviews objectAtIndex:1];
        
        if (inputViewController.subviews.count < 4*3) return;
        NSArray *buttons = inputViewController.subviews;
        for (UIButton *button in buttons) {
            if (button.tag >= 0) {
                numberButtons[button.tag] = button;
            } else if (button.tag == -2) {
                submitButton = button;
            }
        }
    });
    
    return original;
}

%end