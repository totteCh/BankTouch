#include "BioServer.h"
#import <CydiaSubstrate.h>
#import <libactivator/libactivator.h>


void startMonitoring_(CFNotificationCenterRef center,
                      void *observer,
                      CFStringRef name,
                      const void *object,
                      CFDictionaryRef userInfo) {
    [[BioServer sharedInstance] startMonitoring];
}

void stopMonitoring_(CFNotificationCenterRef center,
                     void *observer,
                     CFStringRef name,
                     const void *object,
                     CFDictionaryRef userInfo) {
    [[BioServer sharedInstance] stopMonitoring];
}


@implementation BioServer

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
        oldObservers = [NSHashTable new];
    }
    
    return self;
}


- (void)biometricEventMonitor:(id)monitor handleBiometricEvent:(unsigned)event {
    switch (event) {
        case TouchIDMatched:
            [self notifyAppOfSuccess];
            [self stopMonitoring];
            break;
            
        case TouchIDNotMatched:
            [self notifyAppOfFailure];
            break;
            
        default:
            break;
    }
}


- (void)startMonitoring {
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
}

- (void)stopMonitoring {
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
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &startMonitoring_, CFSTR("net.tottech.banktouch/startMonitoring"), NULL, 0);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &stopMonitoring_, CFSTR("net.tottech.banktouch/stopMonitoring"), NULL, 0);
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