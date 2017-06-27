#include "BioServer.h"
#import "Common.h"
#import <CydiaSubstrate.h>
#import <libactivator/libactivator.h>


void startMonitoring_iOS9_(notificationArguments) {
    [[BioServer sharedInstance] startMonitoring_iOS9];
}

void stopMonitoring_iOS9_(notificationArguments) {
    [[BioServer sharedInstance] stopMonitoring_iOS9];
}

void startMonitoring_iOS10_(notificationArguments) {
    [[BioServer sharedInstance] startMonitoring_iOS10];
}

void stopMonitoring_iOS10_(notificationArguments) {
    [[BioServer sharedInstance] stopMonitoring_iOS10];
}

void appActiveNotification_(notificationArguments) {
    [[BioServer sharedInstance] appActiveNotification];
}


@implementation BioServer {
    NSTimeInterval appLastActive;
}

+ (id)sharedInstance {
    static BioServer *sharedInstance = nil;
    static dispatch_once_t token = 0;
    dispatch_once(&token, ^{
        sharedInstance = [[BioServer alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    self = [super init];

    if (self) {
        if ([[[UIDevice currentDevice] systemVersion] doubleValue] < 10) {
            oldObservers = [NSHashTable new];
        }
        appLastActive = -1;
    }

    return self;
}

// iOS 10 event handler
- (void)biometricKitInterface:(id)interface handleEvent:(unsigned long long)event {
    switch (event) {
        case TouchIDMatched:
            [self notifyAppOfSuccess];
            [self stopMonitoring_iOS10];
            break;

        case TouchIDNotMatched:
            [self notifyAppOfFailure];
            break;

        default:
            break;
    }
}

// iOS 9 event handler
- (void)biometricEventMonitor:(id)monitor handleBiometricEvent:(unsigned)event {
    switch (event) {
        case TouchIDMatched:
            [self notifyAppOfSuccess];
            [self stopMonitoring_iOS9];
            break;

        case TouchIDNotMatched:
            [self notifyAppOfFailure];
            break;

        default:
            break;
    }
}

- (void)startMonitoring_iOS10 {
    if (isMonitoring) {
        return;
    }

    isMonitoring = YES;

    // Do Activator stuff here...

    _SBUIBiometricKitInterface *interface = [[objc_getClass("BiometricKit") manager] delegate];
    _oldDelegate = interface.delegate;

    // Begin listening
    [interface setDelegate:self];
    [interface matchWithMode:0 andCredentialSet:nil];

    isMonitoring = YES;

    appLastActive = [NSDate timeIntervalSinceReferenceDate];
    [NSThread detachNewThreadSelector:@selector(checkForAppAbnormalExit) toTarget:self withObject:nil];
}

- (void)startMonitoring_iOS9 {
    if (isMonitoring) {
        return;
    }

    isMonitoring = YES;

    activatorListenerNames = nil;
    id activator = [objc_getClass("LAActivator") sharedInstance];
    if (activator != nil) {
        id event = [objc_getClass("LAEvent") eventWithName:@"libactivator.fingerprint-sensor.press.single" mode:@"application"]; // LAEventNameFingerprintSensorPressSingle
        if (event != nil) {
            activatorListenerNames = [activator assignedListenerNamesForEvent:event];
            if (activatorListenerNames != nil) {
                for (NSString *listenerName in activatorListenerNames) {
                    [activator removeListenerAssignment:listenerName fromEvent:event];
                }
            }
        }
    }

    SBUIBiometricEventMonitor *monitor = [[objc_getClass("BiometricKit") manager] delegate];
    previousMatchingSetting = [monitor isMatchingEnabled];
    oldObservers = [MSHookIvar<NSHashTable *>(monitor, "_observers") copy];

    for (id observer in oldObservers) {
        [monitor removeObserver:observer];
    }

    [monitor addObserver:self];
    [monitor _setMatchingEnabled:YES];
    [monitor _startMatching];

    appLastActive = [NSDate timeIntervalSinceReferenceDate];
    [NSThread detachNewThreadSelector:@selector(checkForAppAbnormalExit) toTarget:self withObject:nil];
}

- (void)checkForAppAbnormalExit {
    while (YES) {
        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
        NSTimeInterval timeSinceLastActiveNotification = currentTime - appLastActive;

        if (timeSinceLastActiveNotification > 2) {
            break;
        }

        [NSThread sleepForTimeInterval:0.5];
    }

    [[[UIDevice currentDevice] systemVersion] doubleValue] < 10 ? [self stopMonitoring_iOS9] :
                                                                  [self stopMonitoring_iOS10];
}

- (void)appActiveNotification {
    appLastActive = [NSDate timeIntervalSinceReferenceDate];
}

- (void)stopMonitoring_iOS10 {
    if (!isMonitoring) {
        return;
    }

    isMonitoring = NO;

    _SBUIBiometricKitInterface *interface = [[objc_getClass("BiometricKit") manager] delegate];
    [interface cancel];
    [interface setDelegate:_oldDelegate];
    [interface detectFingerWithOptions:nil];

    _oldDelegate = nil;

    // Do Activator stuff here...
}

- (void)stopMonitoring_iOS9 {
    if (!isMonitoring) {
        return;
    }

    isMonitoring = NO;

    SBUIBiometricEventMonitor *monitor = [[objc_getClass("BiometricKit") manager] delegate];
    NSHashTable *observers = MSHookIvar<NSHashTable *>(monitor, "_observers");


    if (observers != nil && [observers containsObject:self]) {
        [monitor removeObserver:self];
    }
    if (oldObservers != nil && observers != nil) {
        for (id observer in oldObservers) {
            [monitor addObserver:observer];
        }
    }

    oldObservers = nil;

    [monitor _setMatchingEnabled:previousMatchingSetting];

    id activator = [objc_getClass("LAActivator") sharedInstance];
    if (activator != nil && activatorListenerNames != nil) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void) {
            id event = [objc_getClass("LAEvent") eventWithName:@"libactivator.fingerprint-sensor.press.single" mode:@"application"]; // LAEventNameFingerprintSensorPressSingle
            if (event != nil) {
                for (NSString *listenerName in activatorListenerNames) {
                    [activator addListenerAssignment:listenerName toEvent:event];
                }
            }
        });
    }
}

- (void)setUpForMonitoring {
    if ([[[UIDevice currentDevice] systemVersion] doubleValue] < 10) {
        // iOS 9
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &startMonitoring_iOS9_, CFSTR("net.tottech.banktouch/startMonitoring"), NULL, 0);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &stopMonitoring_iOS9_, CFSTR("net.tottech.banktouch/stopMonitoring"), NULL, 0);
    } else {
        // iOS 10
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &startMonitoring_iOS10_, CFSTR("net.tottech.banktouch/startMonitoring"), NULL, 0);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &stopMonitoring_iOS10_, CFSTR("net.tottech.banktouch/stopMonitoring"), NULL, 0);
    }
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &appActiveNotification_, CFSTR("net.tottech.banktouch/appActive"), NULL, 0);
}

- (void)notifyAppOfSuccess {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.banktouch/success"), nil, nil, YES);
}

- (void)notifyAppOfFailure {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("net.tottech.banktouch/failure"), nil, nil, YES);
}

- (BOOL)isMonitoring {
    return isMonitoring;
}

@end
