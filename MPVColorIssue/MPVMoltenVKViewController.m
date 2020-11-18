//
//  MPVMoltenVKViewController.m
//  MPVColorIssue
//
//  Created by zfu on 2020/6/29.
//  Copyright © 2020 qiudaomao. All rights reserved.
//

#import "MPVMoltenVKViewController.h"
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import "mpv/client.h"

#import <stdio.h>
#import <stdlib.h>

static inline void check_error(int status)
{
    if (status < 0) {
        printf("mpv API error: %s\n", mpv_error_string(status));
    }
}

static void wakeup(void *context)
{
    MPVMoltenVKViewController *a = (__bridge MPVMoltenVKViewController*) context;
    [a readEvents];
}


@implementation MPVMoltenVKViewController {
    mpv_handle *mpv;
    dispatch_queue_t queue;
    CAMetalLayer *metalLayer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    metalLayer = CAMetalLayer.new;
    metalLayer.framebufferOnly = YES;
    metalLayer.frame = self.view.layer.frame;
    metalLayer.drawableSize = self.view.frame.size;
    [self.view.layer addSublayer:metalLayer];

    mpv = mpv_create();
    if (!mpv) {
        printf("failed creating context\n");
        exit(1);
    }
    
    // request important errors
    NSString *logFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"mpv-log.txt"];
    NSLog(@"log to %@", logFile);
    // Deal with MPV in the background.
    queue = dispatch_queue_create("mpv", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        // Register to be woken up whenever mpv generates new events.
        check_error(mpv_set_option_string(self->mpv, "log-file", logFile.UTF8String));
        check_error(mpv_request_log_messages(self->mpv, "info"));
        check_error(mpv_initialize(self->mpv));
        int64_t wid = (intptr_t)self->metalLayer;
        check_error(mpv_set_option(self->mpv, "wid", MPV_FORMAT_INT64, &wid));
        check_error(mpv_set_option_string(self->mpv, "vo", "gpu"));
        check_error(mpv_set_option_string(self->mpv, "gpu-api", "vulkan"));
        check_error(mpv_set_option_string(self->mpv, "gpu-context", "moltenvk"));
        mpv_set_wakeup_callback(self->mpv, wakeup, (__bridge void *)self);
        // Load the indicated file

        NSURL *url = [NSBundle.mainBundle URLForResource:@"captain.marvel.2019.2160p.uhd.bluray.x265-terminal.sample" withExtension:@"mkv"];
//        NSURL *url = [NSBundle.mainBundle URLForResource:@"i-see-fire" withExtension:@"mp4"];
        NSString *path = url.absoluteString;
        NSLog(@"load file %@", path);
        const char *cmd[] = {"loadfile", path.UTF8String, NULL};
        check_error(mpv_command(self->mpv, cmd));
        check_error(mpv_set_option_string(self->mpv, "loop", "inf"));
    });
}
    
- (void)viewDidLayoutSubviews {
    metalLayer.frame = self.view.layer.frame;
    metalLayer.drawableSize = self.view.frame.size;
    NSLog(@"resize to %.2f %.2f %.2f %.2f",
          metalLayer.frame.origin.x,
          metalLayer.frame.origin.y,
          metalLayer.frame.size.width,
          metalLayer.frame.size.height);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
    
- (void)handleEvent:(mpv_event *)event
{
    switch (event->event_id) {
        case MPV_EVENT_SHUTDOWN: {
            mpv_detach_destroy(mpv);
            mpv = NULL;
            printf("event: shutdown\n");
            break;
        }
        
        case MPV_EVENT_LOG_MESSAGE: {
            struct mpv_event_log_message *msg = (struct mpv_event_log_message *)event->data;
            printf("[%s] %s: %s", msg->prefix, msg->level, msg->text);
        }
        
        default:
        printf("event: %s\n", mpv_event_name(event->event_id));
    }
}

- (void)readEvents
{
    dispatch_async(queue, ^{
        while (self->mpv) {
            mpv_event *event = mpv_wait_event(self->mpv, 0);
            if (event->event_id == MPV_EVENT_NONE)
            {
                break;
            }
            [self handleEvent:event];
        }
    });
}
    
@end
