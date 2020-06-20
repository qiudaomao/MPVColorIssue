//
//  ViewController.m
//  MPVColorIssue
//
//  Created by zfu on 2020/6/20.
//  Copyright © 2020 qiudaomao. All rights reserved.
//

#import "ViewController.h"
#import "MPVViewController.h"

@interface ViewController () {
    MPVViewController *mpvVC;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    mpvVC = [[MPVViewController alloc] initWithNibName:@"MPVViewController" bundle:nil];
    [self.view addSubview:mpvVC.view];
    mpvVC.view.frame = self.view.bounds;
    mpvVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleHeight;
}

@end
