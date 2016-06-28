//
//  ViewController.m
//  iSenseViewer
//
//  Created by Norbert Spot on 16/05/16.
//  Copyright © 2016 CodeFlügel GmbH. All rights reserved.
//

#import "ViewController.h"

#define HAS_LIBCXX

#import "Structure.h"
#import "StructureSLAM.h"

@interface ViewController () <STSensorControllerDelegate>

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, strong) STDepthToRgba *depthToRgba;
@property (nonatomic) uint8_t *coloredDepthBuffer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // STWirelessLog is very helpful for debugging while your Structure Sensor is plugged in.
    // See SDK documentation for how to start a listener on your computer.
    NSError* error = nil;
    NSString *remoteLogHost = @"192.168.10.69";
    [STWirelessLog broadcastLogsToWirelessConsoleAtAddress:remoteLogHost usingPort:4999 error:&error];
    if (error)
        NSLog(@"Oh no! Can't start wireless log: %@", [error localizedDescription]);
    
    [STSensorController sharedController].delegate = self;
    
    _coloredDepthBuffer = NULL;
    
    NSLog(@"viewDidLoad");
    
    // From now on, make sure we get notified when the app becomes active to restore the sensor state if necessary.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)appDidBecomeActive {
    [self tryStreaming];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self tryStreaming];
}

- (void)tryStreaming {
    STSensorControllerInitStatus result = [[STSensorController sharedController] initializeSensorConnection];
    
    BOOL didSucceed = (result == STSensorControllerInitStatusSuccess || result == STSensorControllerInitStatusAlreadyInitialized);
    if (didSucceed && [[STSensorController sharedController] isConnected]) {
        NSError *error = nil;
        [[STSensorController sharedController] startStreamingWithOptions:@{kSTStreamConfigKey: @(STStreamConfigDepth640x480), kSTHoleFilterConfigKey: @YES} error:&error];
        if (error) {
            NSLog(@"ERROR starting stream: %@", error);
        } else {
            error = nil;
        }
        
        self.depthToRgba = [[STDepthToRgba alloc] initWithOptions:@{kSTDepthToRgbaStrategyKey: @(STDepthToRgbaStrategyRedToBlueGradient)} error:&error];
        if (error) {
            NSLog(@"ERROR initing STDepthToRgba: %@", error);
        }
        
    } else {
        self.statusLabel.text = @"Sensor is not connected";
    }
}

#pragma mark - STSensorControllerDelegate

- (void)sensorDidConnect {
    [self tryStreaming];
    self.statusLabel.text = @"Streaming";
    NSLog(@"Streaming");
}

- (void)sensorDidDisconnect {
    self.statusLabel.text = @"Disconnected";
    NSLog(@"Disconnected");
}

- (void)sensorDidStopStreaming:(STSensorControllerDidStopStreamingReason)reason {
    self.statusLabel.text = @"Stopped streaming";
    NSLog(@"Stopped streaming");
}

- (void)sensorDidLeaveLowPowerMode {
    self.statusLabel.text = @"Low power!";
    NSLog(@"Low power!");
}

- (void)sensorBatteryNeedsCharging {
    self.statusLabel.text = @"Battery needs to be charged!";
    NSLog(@"Battery needs to be charged!");
}

- (void)sensorDidOutputDepthFrame:(STDepthFrame *)depthFrame {
    _coloredDepthBuffer = [self.depthToRgba convertDepthFrameToRgba:depthFrame];
    
    self.imageView.image = [self imageFromPixels:_coloredDepthBuffer withCols:self.depthToRgba.width andRows:self.depthToRgba.height];
}

#pragma mark - Rendering

- (UIImage *)imageFromPixels:(uint8_t *)pixels withCols:(int)cols andRows:(int)rows {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGBitmapInfo bitmapInfo;
    bitmapInfo = (CGBitmapInfo)kCGImageAlphaNoneSkipLast;
    bitmapInfo |= kCGBitmapByteOrder32Big;
    
    NSData *data = [NSData dataWithBytes:pixels length:cols * rows * 4];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data); //toll-free ARC bridging
    
    CGImageRef imageRef = CGImageCreate(cols,                        //width
                                        rows,                        //height
                                        8,                           //bits per component
                                        8 * 4,                       //bits per pixel
                                        cols * 4,                    //bytes per row
                                        colorSpace,                  //Quartz color space
                                        bitmapInfo,                  //Bitmap info (alpha channel?, order, etc)
                                        provider,                    //Source of data for bitmap
                                        NULL,                        //decode
                                        false,                       //pixel interpolation
                                        kCGRenderingIntentDefault);  //rendering intent
    
    return [UIImage imageWithCGImage:imageRef];
}

@end
