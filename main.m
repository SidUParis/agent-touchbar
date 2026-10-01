#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>

#define SOCKET_PATH "/tmp/agent_touchbar.sock"

// TouchBar Identifiers
static NSString * const kItemEsc       = @"com.agent.touchbar.esc";
static NSString * const kItemLabel     = @"com.agent.touchbar.label";
static NSString * const kItemAllow     = @"com.agent.touchbar.allow";
static NSString * const kItemAllow1    = @"com.agent.touchbar.allow1";
static NSString * const kItemAllow2    = @"com.agent.touchbar.allow2";
static NSString * const kItemReject    = @"com.agent.touchbar.reject";

@interface KeySender : NSObject
+ (void)postKeyCode:(CGKeyCode)keyCode;
+ (BOOL)isAccessibilityTrusted;
@end

@implementation KeySender
+ (BOOL)isAccessibilityTrusted {
    NSDictionary *opts = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts);
}

+ (void)postKeyCode:(CGKeyCode)keyCode {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventRef down = CGEventCreateKeyboardEvent(source, keyCode, true);
    CGEventRef up   = CGEventCreateKeyboardEvent(source, keyCode, false);
    
    CGEventPost(kCGHIDEventTap, down);
    CGEventPost(kCGHIDEventTap, up);
    
    if (down) CFRelease(down);
    if (up) CFRelease(up);
    if (source) CFRelease(source);
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTouchBarDelegate>
@property (strong, nonatomic) NSTouchBar *touchBar;
@property (copy, nonatomic) NSString *promptMessage;
@property (assign, nonatomic) BOOL isModalActive;
@property (strong, nonatomic) dispatch_source_t socketSource;
@property (assign, nonatomic) int serverFD;
@property (strong, nonatomic) NSTimer *autoDismissTimer;
@property (assign, nonatomic) EventHotKeyRef globalHotKeyRef;

- (void)toggleApprovalTouchBar;
- (void)presentApprovalTouchBar:(NSString *)message timeout:(NSTimeInterval)timeout;
- (void)dismissApprovalTouchBar;
@end

static AppDelegate *gAppDelegate = nil;

static OSStatus HotKeyHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
    if (gAppDelegate) {
        [gAppDelegate toggleApprovalTouchBar];
    }
    return noErr;
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    gAppDelegate = self;
    
    // Pure headless background daemon: no Dock icon, no Menu Bar status item
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    
    [KeySender isAccessibilityTrusted];
    
    [self setupGlobalHotKey];
    [self setupSocketServer];
    
    NSLog(@"[TouchBar] Headless daemon started. Hotkey: Shift+Cmd+A, Socket: %s", SOCKET_PATH);
}

- (void)setupGlobalHotKey {
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind = kEventHotKeyPressed;
    InstallApplicationEventHandler(&HotKeyHandler, 1, &eventType, NULL, NULL);

    EventHotKeyID hotKeyID;
    hotKeyID.signature = 'ATBR';
    hotKeyID.id = 1;

    UInt32 modifiers = cmdKey | shiftKey;
    RegisterEventHotKey(kVK_ANSI_A, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &_globalHotKeyRef);
}

- (void)toggleApprovalTouchBar {
    if (self.isModalActive) {
        [self dismissApprovalTouchBar];
    } else {
        [self presentApprovalTouchBar:@"Agent Permission Request" timeout:30.0];
    }
}

- (void)quitApp {
    [self dismissApprovalTouchBar];
    if (_globalHotKeyRef) {
        UnregisterEventHotKey(_globalHotKeyRef);
    }
    [NSApp terminate:nil];
}

#pragma mark - Touch Bar Presentation

- (void)presentApprovalTouchBar:(NSString *)message timeout:(NSTimeInterval)timeout {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.promptMessage = message ?: @"Agent Permission Request";
        
        self.touchBar = [[NSTouchBar alloc] init];
        self.touchBar.delegate = self;
        self.touchBar.defaultItemIdentifiers = @[
            kItemEsc,
            kItemLabel,
            NSTouchBarItemIdentifierFlexibleSpace,
            kItemAllow,
            kItemAllow1,
            kItemAllow2,
            kItemReject
        ];
        
        SEL presentSEL = NSSelectorFromString(@"presentSystemModalTouchBar:systemTrayItemIdentifier:");
        if ([[NSTouchBar class] respondsToSelector:presentSEL]) {
            typedef void (*PresentFunc)(id, SEL, id, id);
            PresentFunc func = (PresentFunc)[[NSTouchBar class] methodForSelector:presentSEL];
            func([NSTouchBar class], presentSEL, self.touchBar, nil);
            self.isModalActive = YES;
        }
        
        [self.autoDismissTimer invalidate];
        if (timeout > 0) {
            self.autoDismissTimer = [NSTimer scheduledTimerWithTimeInterval:timeout
                                                                     target:self
                                                                   selector:@selector(dismissApprovalTouchBar)
                                                                   userInfo:nil
                                                                    repeats:NO];
        }
    });
}

- (void)dismissApprovalTouchBar {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isModalActive && self.touchBar) {
            SEL dismissSEL = NSSelectorFromString(@"dismissSystemModalTouchBar:");
            if ([[NSTouchBar class] respondsToSelector:dismissSEL]) {
                typedef void (*DismissFunc)(id, SEL, id);
                DismissFunc func = (DismissFunc)[[NSTouchBar class] methodForSelector:dismissSEL];
                func([NSTouchBar class], dismissSEL, self.touchBar);
            }
            self.isModalActive = NO;
        }
        [self.autoDismissTimer invalidate];
        self.autoDismissTimer = nil;
    });
}

#pragma mark - NSTouchBarDelegate

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier {
    if ([identifier isEqualToString:kItemEsc]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.visibilityPriority = NSTouchBarItemPriorityHigh;
        NSButton *btn = [NSButton buttonWithTitle:@"esc" target:self action:@selector(onEscTapped)];
        btn.bezelColor = [NSColor colorWithWhite:0.2 alpha:1.0];
        item.view = btn;
        return item;
    }
    
    if ([identifier isEqualToString:kItemLabel]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.visibilityPriority = NSTouchBarItemPriorityLow;
        
        NSStackView *stack = [[NSStackView alloc] init];
        stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        stack.spacing = 8.0;
        stack.alignment = NSLayoutAttributeCenterY;
        
        NSImage *iconImg = [NSImage imageWithSystemSymbolName:@"sparkles" accessibilityDescription:nil];
        if (iconImg) {
            NSImageView *iconView = [NSImageView imageViewWithImage:iconImg];
            iconView.contentTintColor = [NSColor systemCyanColor];
            [stack addArrangedSubview:iconView];
        }
        
        NSTextField *label = [NSTextField labelWithString:self.promptMessage ?: @"Agent Request"];
        label.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
        label.textColor = [NSColor labelColor];
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [label setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [stack addArrangedSubview:label];
        
        item.view = stack;
        return item;
    }
    
    // Modern Apple HIG Button 1: Allow (Enter)
    if ([identifier isEqualToString:kItemAllow]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.visibilityPriority = NSTouchBarItemPriorityHigh + 10;
        
        NSImage *img = [NSImage imageWithSystemSymbolName:@"checkmark" accessibilityDescription:nil];
        NSButton *btn = [NSButton buttonWithTitle:@"Allow ⏎" image:img target:self action:@selector(onAllowTapped)];
        btn.imagePosition = NSImageLeading;
        btn.imageHugsTitle = YES;
        // Refined Apple system green
        btn.bezelColor = [NSColor colorWithSRGBRed:0.18 green:0.62 blue:0.32 alpha:1.0];
        item.view = btn;
        return item;
    }
    
    // Modern Apple HIG Button 2: Once (1)
    if ([identifier isEqualToString:kItemAllow1]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.visibilityPriority = NSTouchBarItemPriorityHigh;
        
        NSImage *img = [NSImage imageWithSystemSymbolName:@"1.circle" accessibilityDescription:nil];
        NSButton *btn = [NSButton buttonWithTitle:@"Once" image:img target:self action:@selector(onAllow1Tapped)];
        btn.imagePosition = NSImageLeading;
        btn.imageHugsTitle = YES;
        btn.bezelColor = [NSColor colorWithWhite:0.26 alpha:1.0];
        item.view = btn;
        return item;
    }

    // Modern Apple HIG Button 3: Always (2)
    if ([identifier isEqualToString:kItemAllow2]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.visibilityPriority = NSTouchBarItemPriorityHigh;
        
        NSImage *img = [NSImage imageWithSystemSymbolName:@"2.circle" accessibilityDescription:nil];
        NSButton *btn = [NSButton buttonWithTitle:@"Always" image:img target:self action:@selector(onAllow2Tapped)];
        btn.imagePosition = NSImageLeading;
        btn.imageHugsTitle = YES;
        btn.bezelColor = [NSColor colorWithWhite:0.26 alpha:1.0];
        item.view = btn;
        return item;
    }
    
    // Modern Apple HIG Button 4: Reject (Esc)
    if ([identifier isEqualToString:kItemReject]) {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.visibilityPriority = NSTouchBarItemPriorityHigh + 5;
        
        NSImage *img = [NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:nil];
        NSButton *btn = [NSButton buttonWithTitle:@"Reject ⎋" image:img target:self action:@selector(onRejectTapped)];
        btn.imagePosition = NSImageLeading;
        btn.imageHugsTitle = YES;
        // Refined Apple muted red
        btn.bezelColor = [NSColor colorWithSRGBRed:0.72 green:0.22 blue:0.22 alpha:1.0];
        item.view = btn;
        return item;
    }
    
    return nil;
}

#pragma mark - Button Actions

- (void)onEscTapped {
    [KeySender postKeyCode:kVK_Escape];
    [self dismissApprovalTouchBar];
}

- (void)onAllowTapped {
    [KeySender postKeyCode:kVK_Return];
    [self dismissApprovalTouchBar];
}

- (void)onAllow1Tapped {
    [KeySender postKeyCode:kVK_ANSI_1];
    [self dismissApprovalTouchBar];
}

- (void)onAllow2Tapped {
    [KeySender postKeyCode:kVK_ANSI_2];
    [self dismissApprovalTouchBar];
}

- (void)onRejectTapped {
    [KeySender postKeyCode:kVK_Escape];
    [self dismissApprovalTouchBar];
}

#pragma mark - Unix Domain Socket Server

- (void)setupSocketServer {
    unlink(SOCKET_PATH);
    
    self.serverFD = socket(AF_UNIX, SOCK_STREAM, 0);
    if (self.serverFD < 0) return;
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);
    
    if (bind(self.serverFD, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(self.serverFD);
        return;
    }
    
    if (listen(self.serverFD, 10) != 0) {
        close(self.serverFD);
        return;
    }
    
    dispatch_queue_t queue = dispatch_queue_create("com.agent.touchbar.socket", DISPATCH_QUEUE_SERIAL);
    self.socketSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, self.serverFD, 0, queue);
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.socketSource, ^{
        int clientFD = accept(weakSelf.serverFD, NULL, NULL);
        if (clientFD < 0) return;
        
        char buffer[2048];
        ssize_t bytesRead = read(clientFD, buffer, sizeof(buffer) - 1);
        if (bytesRead > 0) {
            buffer[bytesRead] = '\0';
            NSString *raw = [NSString stringWithUTF8String:buffer];
            raw = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            NSString *msg = raw;
            if ([raw hasPrefix:@"{"] && [raw hasSuffix:@"}"]) {
                NSData *data = [raw dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (json[@"title"]) {
                    msg = json[@"title"];
                } else if (json[@"message"]) {
                    msg = json[@"message"];
                }
            }
            
            if (msg.length == 0) msg = @"Agent Permission Request";
            
            if ([msg isEqualToString:@"DISMISS"]) {
                [weakSelf dismissApprovalTouchBar];
            } else {
                [weakSelf presentApprovalTouchBar:msg timeout:30.0];
            }
            write(clientFD, "OK\n", 3);
        }
        close(clientFD);
    });
    
    dispatch_resume(self.socketSource);
}

- (void)dealloc {
    if (self.socketSource) {
        dispatch_source_cancel(self.socketSource);
    }
    if (self.serverFD >= 0) {
        close(self.serverFD);
    }
    unlink(SOCKET_PATH);
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
