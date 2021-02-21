//
//  ViewController.m
//  OTADisabler
//
//  Created by ichitaso on 2021/02/18.
//

#import "ViewController.h"
#import "libdimentio.h"
#include <dlfcn.h>
#import "MobileGestalt.h"

#define VERSION @"v0.0.2~beta"
#define PROFILE1 "/var/mobile/Library/Preferences/com.apple.MobileAsset.plist"
#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

@interface ViewController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *system1;
@property (weak, nonatomic) IBOutlet UILabel *system2;
@property (weak, nonatomic) IBOutlet UILabel *system3;
@property (weak, nonatomic) IBOutlet UILabel *ecid;
@property (weak, nonatomic) IBOutlet UILabel *status;
@property (weak, nonatomic) IBOutlet UIButton *btn;
@property (weak, nonatomic) IBOutlet UILabel *nonce;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (nonatomic, copy) NSString *valueStr;

@end

@interface UIDeviceHardware : NSObject
- (NSString *)platform;
@end

@implementation UIDeviceHardware
- (NSString *)platform {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}
@end

static CFStringRef (*$MGCopyAnswer)(CFStringRef);

UIAlertController *alert(NSString *alertTitle, NSString *alertMessage, NSString *actionTitle) {
    UIAlertController *theAlert = [UIAlertController alertControllerWithTitle:alertTitle message:alertMessage preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
    [theAlert addAction:defaultAction];
    return theAlert;
}

bool vaildGenerator(NSString *generator) {
    if ([generator length] != 18 || [generator characterAtIndex:0] != '0' || [generator characterAtIndex:1] != 'x') {
        return false;
    }
    for (int i = 2; i <= 17; i++) {
        if (!isxdigit([generator characterAtIndex:i])) {
            return false;
        }
    }
    return true;
}

NSString *getGenerator(NSString *generator) {
    uint64_t nonce;
    NSNumber *nonceNumber = nil;

    if (dimentio_init(0, NULL, NULL) == KERN_SUCCESS) {
        uint8_t entangled_nonce[CC_SHA384_DIGEST_LENGTH];
        bool entangled;
        if (dimentio(&nonce, false, entangled_nonce, &entangled) == KERN_SUCCESS) {
            printf("The currently generator is 0x%016" PRIX64 ".\n", nonce);
            nonceNumber = [NSNumber numberWithUnsignedLongLong:nonce];
            generator = [NSString stringWithFormat:@"Nonce: %@",[nonceNumber stringValue]];
        }
    }
    return [nonceNumber stringValue] ? generator : @"Nonce: Not Set Nonce";
}

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    // System info
    NSString *systemStr = [NSString stringWithFormat:@"%@ %@ %@ - %@",[[UIDeviceHardware alloc] platform],[[UIDevice currentDevice] systemName],[[UIDevice currentDevice] systemVersion],VERSION];

    //void *gestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_GLOBAL | RTLD_LAZY);
    //$MGCopyAnswer = dlsym(gestalt, "MGCopyAnswer");
    //CFStringRef ecid = (CFStringRef)$MGCopyAnswer(CFSTR("UniqueChipID"));

    if (self.view.tag == 143) {
        self.textField.delegate = self;

        uint32_t uid = getuid();
        printf("getuid() returns %u\n", uid);
        printf("whoami: %s\n", uid == 0 ? "root" : "mobile");
        NSString *whoami = [NSString stringWithUTF8String:((void)(@"%s"), uid == 0 ? "root" : "mobile")];
        if ([whoami isEqualToString:@"mobile"]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"You can not set Nonce"
                                                                           message:[@"Status:" stringByAppendingString:whoami]
                                                                    preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *action) {}]];

            [self presentViewController:alert animated:YES completion:nil];
        }
        // Nonce Info
        NSString *nonceStr = getGenerator(self.nonce.text);
        self.nonce.text = nonceStr;
        // System Info
        self.system2.text = systemStr;
    } else if (self.view.tag == 999) {
        // ECID Section
        self.ecid.text = [NSString stringWithFormat:@"ECID: %@", [self ecidHexValue]];
        // System Info
        self.system3.text = systemStr;
    } else {
        if (access(PROFILE1, F_OK != 0)) {
            self.status.text = @"OTA: Enabled";
            [self.btn setTitle:@"Disable" forState:UIControlStateNormal];
        } else if (access(PROFILE1, F_OK == 0)) {
            self.status.text = @"OTA: Disabled";
            [self.btn setTitle:@"Enable" forState:UIControlStateNormal];
        }
        // System Info
        self.system1.text = systemStr;
    }
}

- (void)enable {
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:@PROFILE1]) {
        [manager removeItemAtPath:@PROFILE1 error:nil];

        sleep(2);

        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"OTA Enabled"
                                            message:@"Please reboot device"
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {}]];

        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)disable {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:@PROFILE1];
    NSMutableDictionary *mutableDict = dict ? [dict mutableCopy] : [NSMutableDictionary dictionary];

    [mutableDict setObject:@"https://mesu.apple.com/assets/tvOS14DeveloperSeed" forKey:@"MobileAssetServerURL-com.apple.MobileAsset.MobileSoftwareUpdate.UpdateBrain"];
    [mutableDict setObject:@NO forKey:@"MobileAssetSUAllowOSVersionChange"];
    [mutableDict setObject:@NO forKey:@"MobileAssetSUAllowSameVersionFullReplacement"];
    [mutableDict setObject:@"https://mesu.apple.com/assets/tvOS14DeveloperSeed" forKey:@"MobileAssetServerURL-com.apple.MobileAsset.RecoveryOSUpdate"];
    [mutableDict setObject:@"https://mesu.apple.com/assets/tvOS14DeveloperSeed" forKey:@"MobileAssetServerURL-com.apple.MobileAsset.RecoveryOSUpdateBrain"];
    [mutableDict setObject:@"https://mesu.apple.com/assets/tvOS14DeveloperSeed" forKey:@"MobileAssetServerURL-com.apple.MobileAsset.SoftwareUpdate"];
    [mutableDict setObject:@"65254ac3-f331-4c19-8559-cbe22f5bc1a6" forKey:@"MobileAssetAssetAudience"];

    [mutableDict writeToFile:@PROFILE1 atomically:YES];

    sleep(2);

    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:@PROFILE1]) {
        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"OTA Disabled"
                                            message:@"Please reboot device"
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {}]];

        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (IBAction)tappedBtn:(UIButton *)sender {
    if ([sender.currentTitle isEqualToString:@"Enable"]) {
        NSLog(@"starting enable OTA...");

        [self performSelectorOnMainThread:@selector(enable) withObject:nil waitUntilDone:YES];

        if (access(PROFILE1, F_OK != 0)) {
            self.status.text = @"OTA: Enabled";
            [sender setTitle:@"Disable" forState:UIControlStateNormal];
        }
        else {
            [sender setTitle:@"Failed" forState:UIControlStateNormal];
        }
    }
    else if ([sender.currentTitle isEqualToString:@"Disable"]) {
        NSLog(@"starting disable OTA...");

        [self performSelectorOnMainThread:@selector(disable) withObject:nil waitUntilDone:YES];

        if (access(PROFILE1, F_OK == 0)) {
            self.status.text = @"OTA: Disabled";
            [sender setTitle:@"Enable" forState:UIControlStateNormal];
        }
        else {
            [sender setTitle:@"Failed" forState:UIControlStateNormal];
        }
    }
}

- (IBAction)textChanged:(UITextField *)textfield {
    CGFloat maxLength = 18;
    NSString *toBeString = textfield.text;

    UITextRange *selectedRange = [textfield markedTextRange];
    UITextPosition *position = [textfield positionFromPosition:selectedRange.start offset:0];
    if (!position || !selectedRange) {
        if (toBeString.length > maxLength) {
            NSRange rangeIndex = [toBeString rangeOfComposedCharacterSequenceAtIndex:maxLength];
            if (rangeIndex.length == 1) {
                textfield.text = [toBeString substringToIndex:maxLength];
            } else {
                NSRange rangeRange = [toBeString rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, maxLength)];
                textfield.text = [toBeString substringWithRange:rangeRange];
            }
        }
    }
    NSLog(@"textfield data:%@",textfield.text);
    self.valueStr = textfield.text;
}

- (void)setValue {
    NSString *value = nil;
    if (!self.valueStr || [self.valueStr isEqualToString:@""]) {
        value = @"0x1111111111111111";
    } else {
        value = self.valueStr;
    }

    [self.view endEditing:YES];

    if (!vaildGenerator(value)) {
        [self presentViewController:alert(@"setgenerator", [NSString stringWithFormat:@"Wrong generator \"%@\":\nFormat error!", value], @"OK") animated:YES completion:nil];
        return;
    } else {
        UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:@"Set Generator"
                                            message:value
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
            [self setgenerator];
        }]];

        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)setgenerator {
    // Nonce Info
    NSString *nonceStr = getGenerator(self.nonce.text);
    self.nonce.text = nonceStr;

    if (getuid() != 0) {
        setuid(0);
    }

    if (getuid() != 0) {
        printf("Can't set uid as 0.\n");
    }

    if (dimentio_init(0, NULL, NULL) == KERN_SUCCESS) {
        uint8_t entangled_nonce[CC_SHA384_DIGEST_LENGTH];
        bool entangled;
        uint64_t nonce;
        if (dimentio(&nonce, false, entangled_nonce, &entangled) == KERN_SUCCESS) {
            printf("The currently generator is 0x%016" PRIX64 ".\n", nonce);
            if (entangled) {
                printf("entangled_nonce: ");
                for (size_t i = 0; i < MIN(sizeof(entangled_nonce), 32); ++i) {
                    printf("%02" PRIX8, entangled_nonce[i]);
                }
                putchar('\n');
            }
        }
        dimentio_term();
    }

    uint8_t entangled_nonce[CC_SHA384_DIGEST_LENGTH];
    bool entangled;
    uint64_t nonce;
    if (dimentio_init(0, NULL, NULL) == KERN_SUCCESS) {
        char *generator = (char *)[self.valueStr UTF8String];
        sscanf(generator, "0x%016" PRIx64, &nonce);
        free(generator);
        if (dimentio(&nonce, true, entangled_nonce, &entangled) == KERN_SUCCESS) {
            printf("Set nonce to 0x%016" PRIX64 "\n", nonce);
            if (entangled) {
                printf("entangled_nonce: ");
                for (size_t i = 0; i < MIN(sizeof(entangled_nonce), 32); ++i) {
                    printf("%02" PRIX8, entangled_nonce[i]);
                }
                putchar('\n');
            }
        }
        dimentio_term();
    }
    // Nonce Info
    self.nonce.text = nonceStr;
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField {
    [self setValue];
    return YES;
}


- (IBAction)setGenerator:(UIButton *)sender {
    [self setValue];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [self becomeFirstResponder];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (IBAction)copyEcidValue:(id)sender {
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:@"Copy ECID Value"
                                        message:[self ecidHexValue]
                                 preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:[UIAlertAction actionWithTitle:@"ECID"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = [self ecidValue];
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"ECID (Hex)"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = [self ecidHexValue];
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {}]];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (NSString *)ecidValue {
    void *gestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_GLOBAL | RTLD_LAZY);
    $MGCopyAnswer = dlsym(gestalt, "MGCopyAnswer");
    CFStringRef ecid = (CFStringRef)$MGCopyAnswer(CFSTR("UniqueChipID"));
    if ([[[UIDeviceHardware alloc] platform] isEqualToString:@"x86_64"]) {
        return @"ecidvalue";
    } else {
        return [NSString stringWithFormat:@"%@", (__bridge NSString *)ecid];
    }
}
- (NSString *)ecidHexValue {
    return [NSString stringWithFormat:@"%lX", (unsigned long)[[self ecidValue] integerValue]];
}

- (IBAction)openSafari:(UIButton *)sender {
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Useful Site"
                                          message:nil
                                          preferredStyle:UIAlertControllerStyleActionSheet];

    [alertController addAction:[UIAlertAction actionWithTitle:@"SHSH Host" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        double delayInSeconds = 0.8;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:@"https://shsh.host/"];
        });
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"TSS Saver" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        double delayInSeconds = 0.8;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:@"https://tsssaver.1conan.com/v2/"];
        });
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"The iPhone Wiki" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        double delayInSeconds = 0.8;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:@"https://www.theiphonewiki.com/"];
        });
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"My Repo" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        double delayInSeconds = 0.8;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:@"https://cydia.ichitaso.com"];
        });
    }]];

    // Fix Crash for iPad
    if (IS_PAD) {
        CGRect rect = self.view.frame;
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(rect)-60,rect.size.height-50, 120,50);
        alertController.popoverPresentationController.permittedArrowDirections = 0;
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
    }

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)openURLInBrowser:(NSString *)url {
    SFSafariViewControllerConfiguration *config = [[SFSafariViewControllerConfiguration alloc] init];
    config.barCollapsingEnabled = NO;
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:url] configuration:config];
    [self presentViewController:safari animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
