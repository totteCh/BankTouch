/**
 * Since BankID crashes when hooking BankIDAppDelegate,
 * we have to use a different approach.
 */


%hook UIApplication

- (id)init {
    %log;
    
    id original = %orig;
    UIApplication *app = (UIApplication *)original;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        HBLogInfo(@"dispatch_after");
        
        NSArray *windows = app.windows;
        HBLogInfo(@"Windows in application:");
        for (UIWindow *window in windows) {
            HBLogDebug(@" · %@", window);
        }
        HBLogInfo(@"");
        
        if (windows.count == 0) return;
        
        UIView *keyboardWindow = [windows objectAtIndex:windows.count-1];
        HBLogDebug(@"%@", keyboardWindow);
        
        if (keyboardWindow.subviews.count == 0) return;
        
        UIView *inputContainerView = [keyboardWindow.subviews objectAtIndex:0];
        HBLogDebug(@"%@", inputContainerView);
        
        if (inputContainerView.subviews.count == 0) return;
        
        UIView *inputHostView = [inputContainerView.subviews objectAtIndex:0];
        HBLogDebug(@"%@", inputHostView);
        
        if (inputHostView.subviews.count < 1) return;
        
        UIView *inputViewController = [inputHostView.subviews objectAtIndex:1];
        HBLogDebug(@"%@", inputViewController);
        HBLogInfo(@"");
        
        if (inputViewController.subviews.count < 4*3) return;
        
        NSArray *buttons = inputViewController.subviews;
        UIButton *numberButtons[10];
        UIButton *submitButton;
        
        
        HBLogInfo(@"Buttons:");
        for (UIButton *button in buttons) {
            HBLogDebug(@"%@", button);
            if (button.tag >= 0) {
                numberButtons[button.tag] = button;
            } else if (button.tag == -2) {
                submitButton = button;
            }
            
        }
        HBLogInfo(@"");
        
        int keys[] = {1,2,3,6,5,4};
        for (int i = 0; i < sizeof(keys)/sizeof(keys[0]); i++) {
            int key = (int)keys[i];
            UIButton *button = numberButtons[key];
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [submitButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        });
    });
    
    return original;
}

%end