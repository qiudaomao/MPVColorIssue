//
//  ViewController.m
//  MPVColorIssue
//
//  Created by zfu on 2020/6/20.
//  Copyright © 2020 qiudaomao. All rights reserved.
//

#import "ViewController.h"
#import "MPVViewController.h"
#import "MPVMoltenVKViewController.h"

#define MOLTEN_VK 1

@interface ViewController () {
#if MOLTEN_VK
    MPVMoltenVKViewController *mpvVC;
#else
    MPVViewController *mpvVC;
#endif
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
#if MOLTEN_VK
    mpvVC = [[MPVMoltenVKViewController alloc] initWithNibName:@"MPVMoltenVKViewController" bundle:nil];
#else
    mpvVC = [[MPVViewController alloc] initWithNibName:@"MPVViewController" bundle:nil];
#endif
    [self.view addSubview:mpvVC.view];
    mpvVC.view.frame = self.view.bounds;
    mpvVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleHeight;
}

@end
