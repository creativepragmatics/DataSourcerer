#import "MulticastDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MulticastDelegate {
    NSArray<NSObject *> *_delegates;
}

- (instancetype)initWithDelegates:(NSArray<NSObject *> *)delegates {
    if (self = [super init]) {
        _delegates = delegates.copy;
    }
    return self;
}

- (instancetype)init {
    self = [self initWithDelegates:@[]];
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([super respondsToSelector:aSelector]) {
        return YES;
    }

    // if any of the delegates respond to this selector, return YES
    for (id delegate in _delegates) {
        if ([delegate respondsToSelector:aSelector]) {
            return YES;
        }
    }
    return NO;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    // can this class create the signature?
    NSMethodSignature* signature = [super methodSignatureForSelector:aSelector];

    // if not, try our delegates
    if (!signature) {
        for (id delegate in _delegates) {
            if ([delegate respondsToSelector:aSelector]) {
                return [delegate methodSignatureForSelector:aSelector];
            }
        }
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    // forward the invocation to every delegate
    for (id delegate in _delegates) {
        if ([delegate respondsToSelector:[anInvocation selector]])
        {
            [anInvocation invokeWithTarget:delegate];
        }
    }
}

@end

NS_ASSUME_NONNULL_END
