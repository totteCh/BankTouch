// iOS 10
@protocol _SBUIBiometricKitInterfaceDelegate
@required
- (void)biometricKitInterface:(id)interface handleEvent:(unsigned long long)event;
@end

@interface _SBUIBiometricKitInterface : NSObject
@property (assign,nonatomic) id<_SBUIBiometricKitInterfaceDelegate> delegate;
- (void)cancel;
- (void)setDelegate:(id<_SBUIBiometricKitInterfaceDelegate>)arg1;
- (int)detectFingerWithOptions:(id)arg1 ;
- (int)matchWithMode:(unsigned long long)arg1 andCredentialSet:(id)arg2;
- (BOOL)hasEnrolledIdentities;
@end

// iOS 9
@protocol SBUIBiometricEventMonitorDelegate
@required
- (void)biometricEventMonitor:(id)monitor handleBiometricEvent:(unsigned)event;
@end

@interface SBUIBiometricEventMonitor : NSObject
- (void)addObserver:(id)arg1;
- (void)removeObserver:(id)arg1;
- (void)_startMatching;
- (void)_setMatchingEnabled:(BOOL)arg1;
- (BOOL)isMatchingEnabled;
@end


@interface BiometricKit : NSObject
+ (id)manager;
@end


#define TouchIDFingerDown  1
#define TouchIDFingerUp    0
#define TouchIDFingerHeld  2
#define TouchIDMatched     3
#define TouchIDNotMatched  10


@interface BioServer : NSObject <_SBUIBiometricKitInterfaceDelegate, SBUIBiometricEventMonitorDelegate> {
    BOOL isMonitoring;
    BOOL previousMatchingSetting;
    NSHashTable *oldObservers;
    NSArray *activatorListenerNames;
}
@property (readonly) id oldDelegate;

+ (id)sharedInstance;
- (void)startMonitoring_iOS10;
- (void)startMonitoring_iOS9;
- (void)appActiveNotification;
- (void)stopMonitoring_iOS10;
- (void)stopMonitoring_iOS9;
- (void)setUpForMonitoring;
- (BOOL)isMonitoring;

@end
