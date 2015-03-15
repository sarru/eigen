#import "ARArtworkSetViewController.h"
#import "ARViewInRoomViewController.h"
#import "ARArtworkViewController.h"

@interface ARArtworkSetViewController ()

@property (nonatomic, strong) Fair *fair;
@property (nonatomic, strong) PartnerShow *show;
@property (nonatomic, strong) NSArray *artworks;
@property (nonatomic, assign) NSInteger index;

@end

@implementation ARArtworkSetViewController

- (instancetype)initWithArtworkID:(NSString *)artworkID
{
    return [self initWithArtworkID:artworkID fair:nil];
}

- (instancetype)initWithArtworkID:(NSString *)artworkID fair:(Fair *)fair
{
    Artwork *artwork = [[Artwork alloc] initWithArtworkID:artworkID];
    return [self initWithArtwork:artwork fair:fair];
}

- (instancetype)initWithArtwork:(Artwork *)artwork
{
    return [self initWithArtwork:artwork fair:nil];
}

- (instancetype)initWithArtwork:(Artwork *)artwork fair:(Fair *)fair
{
    return [self initWithArtworkSet:@[artwork] fair:fair];
}

- (instancetype)initWithArtworkSet:(NSArray *)artworkSet
{
    return [self initWithArtworkSet:artworkSet fair:nil atIndex:0];
}

- (instancetype)initWithArtworkSet:(NSArray *)artworkSet fair:(Fair *)fair
{
    return [self initWithArtworkSet:artworkSet fair:fair atIndex:0];
}

- (instancetype)initWithArtworkSet:(NSArray *)artworkSet atIndex:(NSInteger)index
{
    return [self initWithArtworkSet:artworkSet fair:nil atIndex:index];
}

- (instancetype)initWithArtworkSet:(NSArray *)artworkSet fair:(Fair *)fair atIndex:(NSInteger)index
{
  return [self initWithArtworkSet:artworkSet fair:fair show:nil atIndex:index];
}

- (instancetype)initWithArtworkSet:(NSArray *)artworkSet fair:(Fair *)fair show:(PartnerShow *)show atIndex:(NSInteger)index;
{
    self = [super initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];

    if (!self) { return nil; }

    _show = show;
    _fair = fair;
    _artworks = artworkSet;
    _index = [self isValidArtworkIndex:index] ? index : 0;

    self.delegate = self;
    self.dataSource = self;
    self.automaticallyAdjustsScrollViewInsets = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    ARArtworkViewController *artworkVC = [self viewControllerForIndex:self.index];
    [self setViewControllers:@[artworkVC] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (BOOL)isValidArtworkIndex:(NSInteger)index
{
    if (index < 0 || index >= self.artworks.count) {
        return NO;
    }
    return YES;
}

- (ARArtworkViewController *)viewControllerForIndex:(NSInteger)index
{
    if (![self isValidArtworkIndex:index]) return nil;

    ARArtworkViewController *artworkViewController = [[ARArtworkViewController alloc] initWithArtwork:self.artworks[index] fair:self.fair show:self.show];
    artworkViewController.index = index;

    return artworkViewController;
}

#pragma mark -
#pragma mark Page view controller data source

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(ARArtworkViewController *)viewController
{
    if (self.artworks.count == 1) {
        return nil;
    }

    NSInteger newIndex = viewController.index - 1;
    if (newIndex < 0) {
        newIndex = self.artworks.count - 1;
    }
    return [self viewControllerForIndex:newIndex];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(ARArtworkViewController *)viewController
{
    if (self.artworks.count == 1) {
        return nil;
    }

    NSInteger newIndex = (viewController.index + 1) % self.artworks.count;
    return [self viewControllerForIndex:newIndex];
}

#pragma mark -
#pragma mark Page view controller delegate


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (self.navigationController) {
        UIGestureRecognizer *gesture = self.navigationController.interactivePopGestureRecognizer;
        [self.pagingScrollView.panGestureRecognizer requireGestureRecognizerToFail:gesture];
    }

    [self.currentArtworkViewController setHasFinishedScrolling];
}

- (void)orientationChanged:(NSNotification *)notification
{
    UIDevice *device = [notification object];
    UIDeviceOrientation orientation = [device orientation];
    Artwork *artwork = self.currentArtworkViewController.artwork;

    BOOL isTopViewController = self.navigationController.topViewController == self;
    BOOL isShowingModalViewController = [ARTopMenuViewController sharedController].presentedViewController != nil;
    BOOL canShowInRoom = self.currentArtworkViewController.artwork.canViewInRoom;

    if (![UIDevice isPad] && canShowInRoom && !isShowingModalViewController && isTopViewController) {

        if (UIInterfaceOrientationIsLandscape(orientation)) {
            ARViewInRoomViewController *viewInRoomVC = [[ARViewInRoomViewController alloc] initWithArtwork:artwork];
            viewInRoomVC.popOnRotation = YES;
            viewInRoomVC.rotationDelegate = self;

            [self.navigationController pushViewController:viewInRoomVC animated:YES];
        }
    }

    if (![UIDevice isPad]) {
        self.view.bounds = [UIScreen mainScreen].bounds;
    }
}

- (NSUInteger)supportedInterfaceOrientations
{
    return [UIDevice isPad] ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskAllButUpsideDown;
}

-(BOOL)shouldAutorotate
{
    return [UIDevice isPad] ? YES : self.currentArtworkViewController.artwork.canViewInRoom;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}


- (NSUInteger)pageViewControllerSupportedInterfaceOrientations:(UIPageViewController *)pageViewController
{
    return [self supportedInterfaceOrientations];
}

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray *)previousViewControllers transitionCompleted:(BOOL)completed;
{
    if (completed) {
        [self.currentArtworkViewController setHasFinishedScrolling];
    }
}

- (UIScrollView *)pagingScrollView
{
    return self.view.subviews.firstObject;
}

- (ARArtworkViewController *)currentArtworkViewController
{
    return self.viewControllers.lastObject;
}

- (NSDictionary *)dictionaryForAnalytics
{
    if (self.currentArtworkViewController.artwork) {
        return @{ @"artwork" : self.currentArtworkViewController.artwork.artworkID, @"type" : @"artwork" };
    }

    return nil;
}


@end
