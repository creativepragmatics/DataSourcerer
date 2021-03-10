#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Handles messages sent to delegates, multicasting these messages
/// to multiple observers.
/// https://blog.scottlogic.com/2012/11/19/a-multicast-delegate-pattern-for-ios-controls.html
///
/// This is very bothersome (if even possible?) to write in Swift
/// because `NSObject.forwardInvocation` does not exist in Swift.
@interface MulticastDelegate : NSObject
- (instancetype)initWithDelegates:(NSArray<NSObject *> *)delegates NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
