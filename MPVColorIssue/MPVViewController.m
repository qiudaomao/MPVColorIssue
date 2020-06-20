//
//  MPVViewController.m
//  MPVColorIssue
//
//  Created by zfu on 2020/6/20.
//  Copyright © 2020 qiudaomao. All rights reserved.
//

#import "MPVViewController.h"

@interface MPVViewController ()

@end

@import GLKit;
@import OpenGLES;

#import "ViewController.h"

#import "mpv/client.h"
#import "mpv/opengl_cb.h"

#import <stdio.h>
#import <stdlib.h>


static inline void check_error(int status)
{
    if (status < 0) {
        printf("mpv API error: %s\n", mpv_error_string(status));
    }
}

static void *get_proc_address(void *ctx, const char *name)
{
    CFStringRef symbolName = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingASCII);
    void *addr = CFBundleGetFunctionPointerForName(CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengles")), symbolName);
    CFRelease(symbolName);
    NSLog(@"get_proc_address %s => %p", name, addr);
    return addr;
}

static void glupdate(void *ctx);

@interface MpvClientOGLView : GLKView
    @property mpv_opengl_cb_context *mpvGL;
@end

@implementation MpvClientOGLView {
    GLint defaultFBO;
}
    
- (void)awakeFromNib
{
    [super awakeFromNib];

    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (!self.context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
    }
    [EAGLContext setCurrentContext:self.context];
    // Configure renderbuffers created by the view
    self.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    self.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    self.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
    
    defaultFBO = -1;
}
    
- (void)fillBlack
{
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
}
    
- (void)drawRect
{
    if (defaultFBO == -1)
    {
        GLint i = 0;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &i);
        defaultFBO = (i != 0) ? i : 1;
    }

    if (self.mpvGL)
    {
        mpv_opengl_cb_draw(self.mpvGL,
                           defaultFBO,
                           self.bounds.size.width * self.contentScaleFactor,
                           -self.bounds.size.height * self.contentScaleFactor);
    }
}

- (void)drawRect:(CGRect)rect
{
    [self drawRect];
}

@end



static void wakeup(void *);


static void glupdate(void *ctx)
{
    MpvClientOGLView *glView = (__bridge MpvClientOGLView *)ctx;
    // I'm still not sure what the best way to handle this is, but this
    // works.
    dispatch_async(dispatch_get_main_queue(), ^{
        [glView display];
    });
}


@interface MPVViewController ()
    
@property (nonatomic) IBOutlet MpvClientOGLView *glView;
- (void) readEvents;

@end

static void wakeup(void *context)
{
    MPVViewController *a = (__bridge MPVViewController *) context;
    [a readEvents];
}



@implementation MPVViewController {
    mpv_handle *mpv;
    dispatch_queue_t queue;
}
    
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
//    self.glView = [[MpvClientOGLView alloc] initWithFrame:self.view.bounds];
//    self.glView.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleHeight;

    mpv = mpv_create();
    if (!mpv) {
        printf("failed creating context\n");
        exit(1);
    }
    
    // request important errors
    NSString *logFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"mpv-log.txt"];
    NSLog(@"log to %@", logFile);
    check_error(mpv_set_option_string(mpv, "log-file", logFile.UTF8String));
    check_error(mpv_request_log_messages(mpv, "info"));
    check_error(mpv_initialize(mpv));
    
    check_error(mpv_set_option_string(mpv, "vo", "opengl-cb"));
    check_error(mpv_set_option_string(mpv, "hwdec", "videotoolbox"));
    check_error(mpv_set_option_string(mpv, "dither-depth", "auto"));
    check_error(mpv_set_option_string(mpv, "hwdec-image-format", "nv12"));
//    check_error(mpv_set_option_string(mpv, "hwdec-image-format", "yuv420p10"));
    check_error(mpv_set_option_string(mpv, "hwdec-codecs", "all"));
    check_error(mpv_set_option_string(mpv, "gpu-hwdec-interop", "auto"));

    mpv_opengl_cb_context *mpvGL = mpv_get_sub_api(mpv, MPV_SUB_API_OPENGL_CB);
    if (!mpvGL) {
        puts("libmpv does not have the opengl-cb sub-API.");
        exit(1);
    }
        
    [self.glView display];

    // pass the mpvGL context to our view
    self.glView.mpvGL = mpvGL;
    int r = mpv_opengl_cb_init_gl(mpvGL, NULL, get_proc_address, NULL);
    if (r < 0) {
        puts("gl init has failed.");
        exit(1);
    }
    mpv_opengl_cb_set_update_callback(mpvGL, glupdate, (__bridge void *)self.glView);
    
    // Deal with MPV in the background.
    queue = dispatch_queue_create("mpv", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        // Register to be woken up whenever mpv generates new events.
        mpv_set_wakeup_callback(self->mpv, wakeup, (__bridge void *)self);
        // Load the indicated file
        
        
        NSURL *url = [NSBundle.mainBundle URLForResource:@"captain.marvel.2019.2160p.uhd.bluray.x265-terminal.sample" withExtension:@"mkv"];
        NSString *path = url.absoluteString;
        NSLog(@"load file %@", path);
        const char *cmd[] = {"loadfile", path.UTF8String, NULL};
        check_error(mpv_command(self->mpv, cmd));
        check_error(mpv_set_option_string(self->mpv, "loop", "inf"));
    });
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
            mpv_opengl_cb_uninit_gl(self.glView.mpvGL);
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
