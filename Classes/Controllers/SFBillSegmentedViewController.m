//
//  SFBillSegmentedViewController.m
//  Congress
//
//  Created by Daniel Cloud on 12/4/12.
//  Copyright (c) 2012 Sunlight Foundation. All rights reserved.
//

#import "SFBillSegmentedViewController.h"
#import "SFBillDetailView.h"
#import "SFBillService.h"
#import "SFSegmentedViewController.h"
#import "SFBillDetailViewController.h"
#import "SFActionTableViewController.h"
#import "SFBill.h"
#import "SFLegislatorService.h"
#import "SFLegislator.h"
#import "SFRollCallVoteService.h"
#import <GAI.h>

@interface SFBillSegmentedViewController () <UIViewControllerRestoration>

@end

@implementation SFBillSegmentedViewController
{
    NSArray *_sectionTitles;
    NSInteger *_currentSegmentIndex;
    NSString *_restorationBillId;
    SFActionTableViewController *_actionListVC;
    SFBillDetailViewController *_billDetailVC;
    SFSegmentedViewController *_segmentedVC;
    SSLoadingView *_loadingView;
}

static NSString * const CongressActionTableVC = @"CongressActionTableVC";
static NSString * const CongressBillDetailVC = @"CongressBillDetailVC";
static NSString * const CongressSegmentedBillVC = @"CongressSegmentedBillVC";

@synthesize bill = _bill;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])
    {
        [self _initialize];
        self.restorationIdentifier = NSStringFromClass(self.class);
        self.restorationClass = [self class];
        _restorationBillId = nil;
    }
    return self;
}

-(void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.view = view;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_restorationBillId) {
        [SFBillService billWithId:_restorationBillId completionBlock:^(SFBill *bill) {
            if (bill) {
                [self setBill:bill];
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
        }];
        _restorationBillId = nil;
    }
    if (_bill) {
        [[[GAI sharedInstance] defaultTracker] sendEventWithCategory:@"Bill"
                                                          withAction:@"View"
                                                           withLabel:_bill.displayName
                                                           withValue:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Accessors

-(void)setBill:(SFBill *)bill
{
    _bill = bill;
    _shareableObjects = [NSMutableArray array];
    [_shareableObjects addObject:[NSString stringWithFormat:@"%@ via @congress_app", _bill.displayName]];
    [_shareableObjects addObject:_bill.shareURL];

    [self.view addSubview:_loadingView];
    [self.view bringSubviewToFront:_loadingView];

    __weak SFBillSegmentedViewController *weakSelf = self;
    [SFBillService billWithId:self.bill.billId completionBlock:^(SFBill *pBill) {
        __strong SFBillSegmentedViewController *strongSelf = weakSelf;
        if (pBill) {
            strongSelf->_bill = pBill;
        }
        strongSelf->_billDetailVC.bill = pBill;
        _actionListVC.items = [pBill.actions sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"actedAt" ascending:NO]]];

        [strongSelf.view layoutSubviews];
        [_loadingView fadeOutAndRemoveFromSuperview];
        [SFRollCallVoteService votesForBill:pBill.billId count:[NSNumber numberWithInt:50] completionBlock:^(NSArray *resultsArray) {
            strongSelf->_bill.rollCallVotes = resultsArray;
            strongSelf->_actionListVC.items = strongSelf->_bill.actionsAndVotes;
            [strongSelf->_actionListVC sortItemsIntoSectionsAndReload];
        }];
        
        if (_currentSegmentIndex != nil) {
            [_segmentedVC displayViewForSegment:_currentSegmentIndex];
            _currentSegmentIndex = nil;
        }

    }];

    self.title = self.bill.displayName;
    [self.view layoutSubviews];
}

#pragma mark - Private

-(void)_initialize{
    _sectionTitles = @[@"Summary", @"Activity"];

    _segmentedVC = [[self class] newSegmentedViewController];
    [self addChildViewController:_segmentedVC];
    _segmentedVC.view.frame = self.view.frame;
    [self.view addSubview:_segmentedVC.view];
    [_segmentedVC didMoveToParentViewController:self];

    
    _actionListVC = [[self class] newActionTableController];
    _billDetailVC = [[self class] newBillDetailViewController];
    [_segmentedVC setViewControllers:@[_billDetailVC, _actionListVC] titles:_sectionTitles];
    [_segmentedVC displayViewForSegment:0];

    CGSize size = self.view.frame.size;
    _loadingView = [[SSLoadingView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    _loadingView.backgroundColor = [UIColor primaryBackgroundColor];
    _loadingView.textLabel.text = @"Loading bill info.";
    [self.view addSubview:_loadingView];
}

+ (SFSegmentedViewController *)newSegmentedViewController
{
    SFSegmentedViewController *vc = [SFSegmentedViewController new];
    vc.restorationIdentifier = CongressSegmentedBillVC;
    vc.restorationClass = [self class];
    return vc;
}

+ (SFActionTableViewController *)newActionTableController
{
    SFActionTableViewController *vc = [[SFActionTableViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.restorationIdentifier = CongressActionTableVC;
    vc.restorationClass = [self class];
    return vc;
}

+ (SFBillDetailViewController *)newBillDetailViewController
{
    SFBillDetailViewController *vc = [SFBillDetailViewController new];
    vc.restorationIdentifier = CongressBillDetailVC;
    vc.restorationClass = [self class];
    return vc;
}

#pragma mark - UIViewControllerRestoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    return [[SFBillSegmentedViewController alloc] initWithNibName:nil bundle:nil];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    NSString *billId = _bill ? _bill.billId : _restorationBillId;
    [coder encodeObject:billId forKey:@"billId"];
    [coder encodeInteger:[_segmentedVC currentSegmentIndex] forKey:@"segmentIndex"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    _restorationBillId = [coder decodeObjectForKey:@"billId"];
    _currentSegmentIndex = [coder decodeIntegerForKey:@"segmentIndex"];
}

@end
