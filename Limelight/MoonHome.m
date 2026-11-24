//
//  MoonHome.m
//  Moonlight
//
//  See MoonHome.h.
//

#import "MoonHome.h"
#import "AppAssetManager.h"

// Sunshine's stock Desktop entry; its art is a generic icon, so it gets a
// drawn cover with the PC's name instead
static NSString* const kStockDesktopId = @"881448767";
static const CGFloat kSmallScale = 0.75;
static const CGFloat kGap = 20;

#pragma mark - Carousel layout

// Horizontal row starting at the left margin. The selected item is full
// size, the rest smaller and dimmed, bottoms on one line, gaps even.
@interface MoonCarouselLayout : UICollectionViewFlowLayout
@end

@implementation MoonCarouselLayout

- (instancetype)init {
    self = [super init];
    self.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    self.minimumLineSpacing = kGap;
    self.minimumInteritemSpacing = 0;
    return self;
}

- (CGFloat)pitch {
    return self.itemSize.width + self.minimumLineSpacing;
}

- (void)prepareLayout {
    UICollectionView* cv = self.collectionView;
    CGSize b = cv.bounds.size;
    // Insets are not applied (content runs under the bar), so leave room for the bar by hand
    CGFloat barH = cv.safeAreaInsets.top;
    CGFloat area = b.height - barH - cv.safeAreaInsets.bottom;
    CGFloat h = floor(MIN(area * 0.86, 440));
    CGFloat w = floor(h * 0.75);
    self.itemSize = CGSizeMake(w, h);
    CGFloat left = [self leftPad];
    CGFloat top = barH + MAX(0, (area - h) / 2);
    // Right inset lets the last item reach the selected slot
    // Bottom inset fills the rest so the flow layout cannot re-center the row
    self.sectionInset = UIEdgeInsetsMake(top, left, MAX(0, b.height - top - h), MAX(left, b.width - left - w));
    [super prepareLayout];
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return YES;
}

- (CGFloat)leftPad {
    // Lines up with the settings icon in the bar
    return MAX(16, self.collectionView.safeAreaInsets.left - 8);
}

- (void)apply:(UICollectionViewLayoutAttributes*)a {
    CGFloat w = self.itemSize.width, h = self.itemSize.height;
    CGFloat anchor = self.collectionView.contentOffset.x + [self leftPad] + w / 2;
    CGFloat u = (a.center.x - anchor) / [self pitch];
    CGFloat au = fabs(u), sign = u < 0 ? -1 : 1;
    CGFloat small = w * kSmallScale;
    CGFloat offset = MIN(au, 1) * (w / 2 + kGap + small / 2) + MAX(au - 1, 0) * (small + kGap);
    CGFloat scale = 1 - (1 - kSmallScale) * MIN(au, 1);
    // Scaled around the center, so drop it to keep bottoms on one line
    a.center = CGPointMake(anchor + sign * offset, a.center.y + h * (1 - scale) / 2);
    a.transform = CGAffineTransformMakeScale(scale, scale);
    a.zIndex = (NSInteger)(100 - au * 10);
    // Items scrolled past fade out instead of crowding the left margin
    a.alpha = u < 0 ? MAX(0, 1 - au) : 1 - 0.45 * MIN(au, 1);
}

- (NSArray<UICollectionViewLayoutAttributes*>*)layoutAttributesForElementsInRect:(CGRect)rect {
    // Items are pulled toward the middle, so ask for a wider band
    CGRect wide = CGRectInset(rect, -rect.size.width, 0);
    NSMutableArray* out = [NSMutableArray array];
    for (UICollectionViewLayoutAttributes* a in [super layoutAttributesForElementsInRect:wide]) {
        UICollectionViewLayoutAttributes* c = [a copy];
        [self apply:c];
        if (CGRectIntersectsRect(c.frame, rect)) {
            [out addObject:c];
        }
    }
    return out;
}

- (UICollectionViewLayoutAttributes*)layoutAttributesForItemAtIndexPath:(NSIndexPath*)indexPath {
    UICollectionViewLayoutAttributes* a = [[super layoutAttributesForItemAtIndexPath:indexPath] copy];
    [self apply:a];
    return a;
}

- (UICollectionViewLayoutAttributes*)layoutAttributesForInteractivelyMovingItemAtIndexPath:(NSIndexPath*)indexPath
                                                                        withTargetPosition:(CGPoint)position {
    UICollectionViewLayoutAttributes* a = [super layoutAttributesForInteractivelyMovingItemAtIndexPath:indexPath withTargetPosition:position];
    a.transform = CGAffineTransformMakeScale(0.75, 0.75);
    a.zIndex = 1000;
    a.alpha = 1;
    return a;
}

- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposed withScrollingVelocity:(CGPoint)velocity {
    CGFloat p = [self pitch];
    NSInteger n = [self.collectionView numberOfItemsInSection:0];
    NSInteger i = (NSInteger)round(proposed.x / p);
    i = MAX(0, MIN(n - 1, i));
    return CGPointMake(i * p, proposed.y);
}

@end

#pragma mark - Backdrop

@interface MoonBackdrop : UIView
@property (nonatomic, strong) UIImageView* artA;
@property (nonatomic, strong) UIImageView* artB;
@property (nonatomic, strong) CAGradientLayer* base;
@property (nonatomic, strong) CAGradientLayer* fade;
@property (nonatomic, strong) UILabel* title;
@property (nonatomic, strong) UILabel* hint;
@property (nonatomic, strong) UILabel* empty;
@property (nonatomic) CGFloat coverTop;
@end

@implementation MoonBackdrop

- (instancetype)init {
    self = [super init];
    self.base = [CAGradientLayer layer];
    self.base.colors = @[(id)MoonHome.bgTop.CGColor, (id)MoonHome.bgBottom.CGColor];
    self.base.locations = @[@0, @0.75];
    [self.layer addSublayer:self.base];

    self.artA = [self makeArt];
    self.artB = [self makeArt];

    UIVisualEffectView* blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blur.frame = self.bounds;
    [self addSubview:blur];

    self.fade = [CAGradientLayer layer];
    self.fade.colors = @[(id)[MoonHome.bgTop colorWithAlphaComponent:0.2].CGColor,
                         (id)[MoonHome.bgBottom colorWithAlphaComponent:0.95].CGColor];
    self.fade.locations = @[@0.3, @1.0];
    [self.layer addSublayer:self.fade];

    self.title = [self label:22 weight:UIFontWeightBold color:UIColor.whiteColor];
    self.hint = [self label:13 weight:UIFontWeightRegular color:[UIColor colorWithWhite:0.8 alpha:1]];
    self.title.hidden = YES;
    self.hint.hidden = YES;
    self.empty = [self label:15 weight:UIFontWeightMedium color:[UIColor colorWithWhite:0.85 alpha:1]];
    for (UILabel* l in @[self.title, self.hint]) {
        l.layer.shadowColor = UIColor.blackColor.CGColor;
        l.layer.shadowOpacity = 0.9;
        l.layer.shadowRadius = 8;
        l.layer.shadowOffset = CGSizeZero;
    }
    return self;
}

- (UIImageView*)makeArt {
    UIImageView* v = [[UIImageView alloc] init];
    v.contentMode = UIViewContentModeScaleAspectFill;
    v.clipsToBounds = YES;
    v.alpha = 0;
    [self addSubview:v];
    return v;
}

- (UILabel*)label:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor*)color {
    UILabel* l = [[UILabel alloc] init];
    l.font = [MoonHome fontOfSize:size weight:weight];
    l.textColor = color;
    l.textAlignment = NSTextAlignmentCenter;
    [self addSubview:l];
    return l;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.base.frame = b;
    self.fade.frame = b;
    [CATransaction commit];
    self.artA.frame = CGRectInset(b, -40, -40);
    self.artB.frame = self.artA.frame;
    CGFloat w = b.size.width - 32;
    self.title.frame = CGRectMake(16, self.coverTop - 58, w, 28);
    self.hint.frame = CGRectMake(16, self.coverTop - 28, w, 18);
    self.empty.frame = CGRectMake(16, b.size.height / 2 - 12, w, 24);
}

@end

#pragma mark - MoonHome

@implementation MoonHome {
    __weak UICollectionView* _cv;
    __weak UINavigationItem* _nav;
    NSCache* _cache;
    void (^_onPick)(TemporaryHost*, UIView*);
    void (^_onMenu)(TemporaryApp*, UIView*);
    void (^_onAdd)(void);

    MoonBackdrop* _backdrop;
    BOOL _artIsA;
    NSInteger _shownIndex;
    NSString* _shownArtKey;

    UIScrollView* _pillScroll;
    NSArray<UIButton*>* _pills;
    NSArray<TemporaryHost*>* _pillHosts;
    NSString* _pillSignature;
    TemporaryHost* _selected;
    NSArray<TemporaryHost*>* _allHosts;
    NSTimer* _tick;

    UIButton* _dragPill;
    NSInteger _dragFrom;
    NSInteger _dragTo;
    CGFloat _dragStartX;
    CGFloat _dragPillStartX;

    NSIndexPath* _moving;
    CGPoint _moveStart;
    BOOL _moved;
}

+ (UIColor*)bgTop { return [UIColor colorWithRed:0x1c/255.0 green:0x23/255.0 blue:0x33/255.0 alpha:1]; }
+ (UIColor*)bgBottom { return [UIColor colorWithRed:0x0a/255.0 green:0x0c/255.0 blue:0x11/255.0 alpha:1]; }

+ (UIFont*)fontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    NSString* name = weight >= UIFontWeightBold ? @"Pretendard-Bold" :
                     weight >= UIFontWeightSemibold ? @"Pretendard-SemiBold" :
                     weight >= UIFontWeightMedium ? @"Pretendard-Medium" : @"Pretendard-Regular";
    return [UIFont fontWithName:name size:size] ?: [UIFont systemFontOfSize:size weight:weight];
}

+ (UIImage*)artForApp:(TemporaryApp*)app cache:(NSCache*)cache {
    if ([app.id isEqualToString:kStockDesktopId]) {
        return nil;
    }
    UIImage* image = [cache objectForKey:app];
    if (image == nil) {
        image = [UIImage imageWithContentsOfFile:[AppAssetManager boxArtPathForApp:app]];
        if (image != nil) {
            [cache setObject:image forKey:app];
        }
    }
    // Blank placeholder art from GFE / Sunshine (same check as UIAppView)
    if (image == nil ||
        (image.size.width == 130.f && image.size.height == 180.f) ||
        (image.size.width == 628.f && image.size.height == 888.f)) {
        return nil;
    }
    return image;
}

- (instancetype)initWithCollectionView:(UICollectionView*)collectionView
                        navigationItem:(UINavigationItem*)navigationItem
                                 cache:(NSCache*)cache
                                onPick:(void (^)(TemporaryHost*, UIView*))onPick
                                onMenu:(void (^)(TemporaryApp*, UIView*))onMenu
                                 onAdd:(void (^)(void))onAdd {
    self = [super init];
    _cv = collectionView;
    _nav = navigationItem;
    _cache = cache;
    _onPick = onPick;
    _onMenu = onMenu;
    _onAdd = onAdd;
    _shownIndex = -2;
    _apps = @[];

    collectionView.collectionViewLayout = [[MoonCarouselLayout alloc] init];
    collectionView.showsHorizontalScrollIndicator = NO;
    collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    collectionView.alwaysBounceVertical = NO;
    collectionView.alwaysBounceHorizontal = YES;
    collectionView.backgroundColor = MoonHome.bgBottom;
    _backdrop = [[MoonBackdrop alloc] init];
    collectionView.backgroundView = _backdrop;
    [collectionView addObserver:self forKeyPath:@"contentOffset" options:0 context:nil];
    [collectionView addObserver:self forKeyPath:@"bounds" options:0 context:nil];

    UILongPressGestureRecognizer* press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(carouselPress:)];
    press.minimumPressDuration = 0.35;
    [collectionView addGestureRecognizer:press];

    _pillScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 260, 34)];
    _pillScroll.showsHorizontalScrollIndicator = NO;
    _pillScroll.clipsToBounds = NO;
    navigationItem.titleView = _pillScroll;

    UIBarButtonItem* add = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"plus"]
                                                            style:UIBarButtonItemStylePlain
                                                           target:self action:@selector(addTapped)];
    navigationItem.rightBarButtonItem = add;
    if (@available(iOS 26.0, *)) {
        // Plain icon, no glass circle behind it
        add.hidesSharedBackground = YES;
        // No dimmed band under the bar
        collectionView.topEdgeEffect.hidden = YES;
    }

    // Discovery updates host state in place without telling anyone (the stock
    // icons poll too), so poll the chips once a second
    __weak MoonHome* weakSelf = self;
    _tick = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer* t) {
        [weakSelf tick];
    }];

    // See-through bar so the backdrop runs to the top edge
    UINavigationBarAppearance* bar = [[UINavigationBarAppearance alloc] init];
    [bar configureWithTransparentBackground];
    bar.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
    navigationItem.standardAppearance = bar;
    navigationItem.scrollEdgeAppearance = bar;
    navigationItem.compactAppearance = bar;
    navigationItem.compactScrollEdgeAppearance = bar;
    return self;
}

- (void)tick {
    if (_allHosts == nil) return;
    [self setHosts:_allHosts selected:_selected];
    if (_selected == nil) {
        // Open the first PC that is ready
        for (TemporaryHost* h in _pillHosts) {
            if (h.state == StateOnline && h.pairState == PairStatePaired) {
                _onPick(h, _cv);
                break;
            }
        }
    }
}

- (void)dealloc {
    [_tick invalidate];
    [_cv removeObserver:self forKeyPath:@"contentOffset"];
    [_cv removeObserver:self forKeyPath:@"bounds"];
}

- (void)addTapped {
    _onAdd();
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if ([keyPath isEqualToString:@"bounds"]) {
        CGFloat w = MAX(120, _cv.bounds.size.width - 130);
        if (fabs(_pillScroll.frame.size.width - w) > 1) {
            _pillScroll.frame = CGRectMake(0, 0, w, 34);
            [self layoutPills:NO];
        }
    }
    [self updateCurrent];
}

#pragma mark Ordering

- (NSArray<TemporaryHost*>*)orderedHosts:(NSArray<TemporaryHost*>*)hosts {
    NSArray* order = [[NSUserDefaults standardUserDefaults] arrayForKey:@"pcOrder"] ?: @[];
    return [hosts sortedArrayUsingComparator:^NSComparisonResult(TemporaryHost* a, TemporaryHost* b) {
        NSUInteger ia = [order indexOfObject:a.uuid ?: @""], ib = [order indexOfObject:b.uuid ?: @""];
        if (ia != ib) {
            return ia < ib ? NSOrderedAscending : NSOrderedDescending;
        }
        return [a.name caseInsensitiveCompare:b.name];
    }];
}

- (NSString*)appOrderKey:(TemporaryHost*)host {
    return [@"appOrder." stringByAppendingString:host.uuid ?: @""];
}

- (NSArray<TemporaryApp*>*)orderedApps:(NSArray<TemporaryApp*>*)apps forHost:(TemporaryHost*)host {
    NSArray* order = [[NSUserDefaults standardUserDefaults] arrayForKey:[self appOrderKey:host]] ?: @[];
    return [apps sortedArrayUsingComparator:^NSComparisonResult(TemporaryApp* a, TemporaryApp* b) {
        NSUInteger ia = [order indexOfObject:a.id ?: @""], ib = [order indexOfObject:b.id ?: @""];
        if (ia != ib) {
            return ia < ib ? NSOrderedAscending : NSOrderedDescending;
        }
        return [a.name caseInsensitiveCompare:b.name];
    }];
}

- (void)saveAppOrder:(NSArray<TemporaryApp*>*)apps forHost:(TemporaryHost*)host {
    NSMutableArray* ids = [NSMutableArray array];
    for (TemporaryApp* app in apps) {
        if (app.id) [ids addObject:app.id];
    }
    [[NSUserDefaults standardUserDefaults] setObject:ids forKey:[self appOrderKey:host]];
}

#pragma mark PC chips

- (void)setHosts:(NSArray<TemporaryHost*>*)hosts selected:(TemporaryHost*)selected {
    _selected = selected;
    _allHosts = [hosts copy];
    if (_dragPill != nil) {
        return; // never rebuild under the user's finger
    }
    NSArray* ordered = [self orderedHosts:hosts];
    NSMutableString* sig = [NSMutableString string];
    for (TemporaryHost* h in ordered) {
        [sig appendFormat:@"%@|%@|%d|%d|%d;", h.uuid, h.name, (int)h.state, (int)h.pairState, h == selected];
    }
    if ([sig isEqualToString:_pillSignature ?: @"-"]) {
        [self updateEmpty];
        return;
    }
    _pillSignature = sig;
    _pillHosts = ordered;

    for (UIView* v in _pills) {
        [v removeFromSuperview];
    }
    NSMutableArray* pills = [NSMutableArray array];
    for (TemporaryHost* h in ordered) {
        [pills addObject:[self makePill:h selected:h == selected]];
    }
    _pills = pills;
    [self layoutPills:NO];
    [self updateEmpty];
}

- (UIButton*)makePill:(TemporaryHost*)host selected:(BOOL)selected {
    UIButton* b = [UIButton buttonWithType:UIButtonTypeCustom];
    UIColor* fg = selected ? MoonHome.bgBottom : [UIColor colorWithWhite:0.92 alpha:1];
    b.backgroundColor = selected ? UIColor.whiteColor : [UIColor colorWithWhite:1 alpha:0.09];
    b.titleLabel.font = [MoonHome fontOfSize:13 weight:UIFontWeightMedium];
    [b setTitle:host.name forState:UIControlStateNormal];
    [b setTitleColor:fg forState:UIControlStateNormal];
    b.contentEdgeInsets = UIEdgeInsetsMake(0, 26, 0, 14);
    [b sizeToFit];
    b.frame = CGRectMake(0, 2, b.frame.size.width, 30);
    b.layer.cornerRadius = 15;

    UIView* dot = [[UIView alloc] initWithFrame:CGRectMake(13, 12, 6, 6)];
    dot.layer.cornerRadius = 3;
    dot.userInteractionEnabled = NO;
    dot.backgroundColor = host.state == StateOnline ?
        [UIColor colorWithRed:0x3e/255.0 green:0xcf/255.0 blue:0x8e/255.0 alpha:1] :
        [UIColor colorWithWhite:0.45 alpha:1];
    [b addSubview:dot];

    [b addTarget:self action:@selector(pillTapped:) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer* press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pillPress:)];
    press.minimumPressDuration = 0.35;
    [b addGestureRecognizer:press];
    [_pillScroll addSubview:b];
    return b;
}

// Puts the chips in their slots for the current order. While dragging,
// the dragged chip's slot moves to _dragTo and it follows the finger.
- (void)layoutPills:(BOOL)animated {
    NSMutableArray* order = [_pills mutableCopy];
    if (_dragPill != nil) {
        [order removeObject:_dragPill];
        [order insertObject:_dragPill atIndex:_dragTo];
    }
    CGFloat x = 0;
    NSMutableArray* frames = [NSMutableArray array];
    for (UIButton* b in order) {
        [frames addObject:[NSValue valueWithCGRect:CGRectMake(x, 2, b.frame.size.width, 30)]];
        x += b.frame.size.width + 8;
    }
    void (^apply)(void) = ^{
        for (NSUInteger i = 0; i < order.count; i++) {
            UIButton* b = order[i];
            if (b != self->_dragPill) {
                b.frame = [frames[i] CGRectValue];
            }
        }
    };
    if (animated) {
        [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:apply completion:nil];
    }
    else {
        apply();
    }
    _pillScroll.contentSize = CGSizeMake(MAX(0, x - 8), 34);
}

- (void)pillTapped:(UIButton*)b {
    NSUInteger i = [_pills indexOfObject:b];
    if (i != NSNotFound) {
        _onPick(_pillHosts[i], b);
    }
}

- (void)pillPress:(UILongPressGestureRecognizer*)g {
    UIButton* b = (UIButton*)g.view;
    CGFloat x = [g locationInView:_pillScroll].x;
    switch (g.state) {
        case UIGestureRecognizerStateBegan: {
            _dragPill = b;
            _dragFrom = _dragTo = [_pills indexOfObject:b];
            _dragStartX = x;
            _dragPillStartX = b.frame.origin.x;
            _pillScroll.scrollEnabled = NO;
            [_pillScroll bringSubviewToFront:b];
            [UIView animateWithDuration:0.12 animations:^{ b.transform = CGAffineTransformMakeScale(1.08, 1.08); }];
            [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            CGFloat cx = _dragPillStartX + (x - _dragStartX) + b.bounds.size.width / 2;
            b.center = CGPointMake(cx, b.center.y);
            // Target slot: how many other chips sit left of the dragged center
            NSInteger to = 0;
            for (UIButton* o in _pills) {
                if (o != b && CGRectGetMidX(o.frame) < cx) to++;
            }
            if (to != _dragTo) {
                _dragTo = to;
                [self layoutPills:YES];
            }
            break;
        }
        default: {
            NSInteger from = _dragFrom, to = _dragTo;
            [UIView animateWithDuration:0.15 animations:^{ b.transform = CGAffineTransformIdentity; }];
            _pillScroll.scrollEnabled = YES;
            NSMutableArray* hosts = [_pillHosts mutableCopy];
            NSMutableArray* pills = [_pills mutableCopy];
            if (to != from && g.state == UIGestureRecognizerStateEnded) {
                TemporaryHost* h = hosts[from];
                [hosts removeObjectAtIndex:from];
                [hosts insertObject:h atIndex:to];
                [pills removeObjectAtIndex:from];
                [pills insertObject:b atIndex:to];
                NSMutableArray* ids = [NSMutableArray array];
                for (TemporaryHost* hh in hosts) {
                    if (hh.uuid) [ids addObject:hh.uuid];
                }
                [[NSUserDefaults standardUserDefaults] setObject:ids forKey:@"pcOrder"];
                _pillHosts = hosts;
                _pills = pills;
                _pillSignature = nil;
            }
            _dragPill = nil;
            [self layoutPills:YES];
            break;
        }
    }
}

#pragma mark Carousel

- (void)setApps:(NSArray<TemporaryApp*>*)apps {
    _apps = [apps copy] ?: @[];
}

- (void)reloaded {
    _shownIndex = -2;
    [_cv.collectionViewLayout invalidateLayout];
    [_cv layoutIfNeeded];
    // Snap to a whole item; an offset left over from earlier insets would shift the row
    if (_apps.count > 0 && !_cv.isDragging && !_cv.isDecelerating) {
        [self scrollToIndex:[self currentIndex] animated:NO];
    }
    [self updateCurrent];
    [self updateEmpty];
}

- (void)updateEmpty {
    NSString* text = @"";
    if (_selected == nil) {
        text = _pillHosts.count == 0 ? @"PC 없음 · 오른쪽 위 +로 추가" : @"위에서 PC를 고르세요";
    }
    else if (_selected.state == StateOffline) {
        text = [NSString stringWithFormat:@"%@ 꺼져 있음", _selected.name];
    }
    else if (_selected.pairState == PairStateUnpaired) {
        text = [NSString stringWithFormat:@"%@ 페어링 필요", _selected.name];
    }
    _backdrop.empty.text = _apps.count == 0 ? text : @"";
}

- (NSInteger)currentIndex {
    if (_apps.count == 0) return -1;
    MoonCarouselLayout* l = (MoonCarouselLayout*)_cv.collectionViewLayout;
    NSInteger i = (NSInteger)round(_cv.contentOffset.x / [l pitch]);
    return MAX(0, MIN((NSInteger)_apps.count - 1, i));
}

- (void)scrollToIndex:(NSInteger)index animated:(BOOL)animated {
    MoonCarouselLayout* l = (MoonCarouselLayout*)_cv.collectionViewLayout;
    [_cv setContentOffset:CGPointMake(index * [l pitch], _cv.contentOffset.y) animated:animated];
}

- (void)updateCurrent {
    MoonCarouselLayout* l = (MoonCarouselLayout*)_cv.collectionViewLayout;
    CGFloat top = l.sectionInset.top;
    if (fabs(_backdrop.coverTop - top) > 0.5) {
        _backdrop.coverTop = top;
        [_backdrop setNeedsLayout];
    }

    NSInteger i = [self currentIndex];
    if (i == _shownIndex) return;
    _shownIndex = i;

    TemporaryApp* app = i >= 0 ? _apps[i] : nil;
    BOOL running = app != nil && [app.id isEqualToString:app.host.currentGame];
    BOOL otherRunning = app != nil && !running && app.host.currentGame.length > 0 && ![app.host.currentGame isEqualToString:@"0"];
    _backdrop.title.text = app.name ?: @"";
    _backdrop.hint.text = app == nil ? @"" : running ? @"탭해서 이어 하기" : otherRunning ? @"실행 중인 게임으로 이어 하기" : @"탭해서 시작";

    UIImage* art = app ? [MoonHome artForApp:app cache:_cache] : nil;
    NSString* key = art ? [NSString stringWithFormat:@"%p", art] : @"";
    if ([key isEqualToString:_shownArtKey ?: @"-"]) return;
    _shownArtKey = key;
    UIImageView* next = _artIsA ? _backdrop.artB : _backdrop.artA;
    UIImageView* prev = _artIsA ? _backdrop.artA : _backdrop.artB;
    _artIsA = !_artIsA;
    next.image = art;
    [UIView animateWithDuration:0.35 animations:^{
        next.alpha = art ? 0.55 : 0;
        prev.alpha = 0;
    }];
}

- (void)carouselPress:(UILongPressGestureRecognizer*)g {
    CGPoint p = [g locationInView:_cv];
    switch (g.state) {
        case UIGestureRecognizerStateBegan: {
            NSIndexPath* ip = [_cv indexPathForItemAtPoint:p];
            if (ip == nil) return;
            _moving = ip;
            _moveStart = p;
            _moved = NO;
            [_cv beginInteractiveMovementForItemAtIndexPath:ip];
            [_cv updateInteractiveMovementTargetPosition:[_cv cellForItemAtIndexPath:ip].center];
            [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (_moving == nil) return;
            if (hypot(p.x - _moveStart.x, p.y - _moveStart.y) > 10) _moved = YES;
            CGFloat y = CGRectGetMidY(((MoonCarouselLayout*)_cv.collectionViewLayout).collectionView.bounds);
            UICollectionViewLayoutAttributes* a = [_cv layoutAttributesForItemAtIndexPath:_moving];
            [_cv updateInteractiveMovementTargetPosition:CGPointMake(p.x, a ? a.center.y : y)];
            break;
        }
        case UIGestureRecognizerStateEnded: {
            if (_moving == nil) return;
            if (_moved) {
                [_cv endInteractiveMovement];
            }
            else {
                // A press without a drag opens the app menu
                [_cv cancelInteractiveMovement];
                NSIndexPath* ip = _moving;
                if (ip.item < (NSInteger)_apps.count) {
                    _onMenu(_apps[ip.item], [_cv cellForItemAtIndexPath:ip] ?: _cv);
                }
            }
            _moving = nil;
            break;
        }
        default:
            [_cv cancelInteractiveMovement];
            _moving = nil;
            break;
    }
}

+ (void)configureCell:(UICollectionViewCell*)cell app:(TemporaryApp*)app cache:(NSCache*)cache {
    for (UIView* v in [cell.contentView.subviews copy]) {
        [v removeFromSuperview];
    }
    for (UIView* v in [cell.subviews copy]) {
        if (v != cell.contentView && v != cell.backgroundView && v != cell.selectedBackgroundView) {
            [v removeFromSuperview]; // a UIAppView from the stock code path
        }
    }
    cell.layer.borderWidth = 0;
    cell.clipsToBounds = NO;
    cell.contentView.clipsToBounds = YES;
    cell.contentView.layer.cornerRadius = 16;
    cell.contentView.alpha = app.hidden ? 0.4 : 1.0;

    CGRect b = cell.contentView.bounds;
    UIImage* art = [MoonHome artForApp:app cache:cache];
    if (art != nil) {
        UIImageView* iv = [[UIImageView alloc] initWithFrame:b];
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.image = art;
        [cell.contentView addSubview:iv];
    }
    else {
        BOOL desktop = [app.id isEqualToString:kStockDesktopId];
        UIView* face = [[UIView alloc] initWithFrame:b];
        face.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        CAGradientLayer* g = [CAGradientLayer layer];
        g.type = kCAGradientLayerRadial;
        g.startPoint = CGPointMake(0.2, 0.1);
        g.endPoint = CGPointMake(1.3, 1.1);
        g.colors = @[(id)[UIColor colorWithRed:0x3a/255.0 green:0x44/255.0 blue:0x66/255.0 alpha:1].CGColor,
                     (id)[UIColor colorWithRed:0x1f/255.0 green:0x25/255.0 blue:0x36/255.0 alpha:1].CGColor,
                     (id)[UIColor colorWithRed:0x14/255.0 green:0x18/255.0 blue:0x22/255.0 alpha:1].CGColor];
        g.locations = @[@0, @0.5, @1];
        g.frame = CGRectMake(0, 0, 400, 540);
        [face.layer addSublayer:g];
        [cell.contentView addSubview:face];

        UILabel* name = [[UILabel alloc] init];
        name.textColor = UIColor.whiteColor;
        name.numberOfLines = 2;
        name.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        if (desktop) {
            UILabel* pc = [[UILabel alloc] initWithFrame:CGRectMake(14, b.size.height - 52, b.size.width - 28, 14)];
            pc.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
            pc.font = [MoonHome fontOfSize:10 weight:UIFontWeightRegular];
            pc.textColor = [UIColor colorWithWhite:1 alpha:0.5];
            pc.text = app.host.name;
            [cell.contentView addSubview:pc];
            name.frame = CGRectMake(14, b.size.height - 36, b.size.width - 28, 22);
            name.font = [MoonHome fontOfSize:16 weight:UIFontWeightSemibold];
            name.text = @"데스크탑";
        }
        else {
            name.frame = CGRectInset(b, 12, 0);
            name.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            name.textAlignment = NSTextAlignmentCenter;
            name.font = [MoonHome fontOfSize:15 weight:UIFontWeightMedium];
            name.textColor = [UIColor colorWithWhite:0.85 alpha:1];
            name.text = app.name;
        }
        [cell.contentView addSubview:name];
    }

    if ([app.id isEqualToString:app.host.currentGame]) {
        // Running: a plain green dot
        UIView* dot = [[UIView alloc] initWithFrame:CGRectMake(12, 12, 10, 10)];
        dot.backgroundColor = [UIColor colorWithRed:0x3e/255.0 green:0xcf/255.0 blue:0x8e/255.0 alpha:1];
        dot.layer.cornerRadius = 5;
        dot.layer.borderWidth = 2;
        dot.layer.borderColor = [UIColor colorWithWhite:0 alpha:0.35].CGColor;
        [cell.contentView addSubview:dot];
    }

    cell.layer.shadowColor = UIColor.blackColor.CGColor;
    cell.layer.shadowOpacity = 0.5;
    cell.layer.shadowRadius = 14;
    cell.layer.shadowOffset = CGSizeMake(0, 10);
    cell.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:cell.bounds cornerRadius:16].CGPath;
}

@end

#pragma mark - Other screens

static UIImage* sPendingArt;

@implementation MoonHome (Screens)

+ (UIImage*)pendingArt { return sPendingArt; }
+ (void)setPendingArt:(UIImage*)art { sPendingArt = art; }

+ (NSDictionary<NSString*, NSString*>*)koreanText {
    static NSDictionary* map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            @"Citrix X1 Mouse Support": @"Citrix X1 마우스",
            @"Frame Pacing Preference": @"프레임 페이싱",
            @"Frame Rate": @"프레임",
            @"HDR (Beta)": @"HDR (베타)",
            @"Multi-Controller Mode": @"여러 컨트롤러",
            @"On-Screen Controls": @"화면 버튼",
            @"Optimize Game Settings": @"게임 설정 최적화",
            @"Play Audio on PC": @"PC에서도 소리 내기",
            @"Preferred Codec": @"코덱",
            @"Resolution": @"해상도",
            @"Statistics Overlay": @"통계 표시",
            @"Swap A/B and X/Y Buttons": @"A/B·X/Y 바꾸기",
            @"Touch Mode": @"터치 방식",
            @"Custom": @"직접",
            @"Auto": @"자동",
            @"Full": @"전체",
            @"No": @"아니요",
            @"Yes": @"예",
            @"Off": @"끔",
            @"Safe Area": @"안전 영역",
            @"Simple": @"간단히",
            @"Single": @"하나",
            @"Smoothest Video": @"부드럽게",
            @"Lowest Latency": @"지연 최소",
            @"Touchpad": @"터치패드",
            @"Touchscreen": @"터치스크린",
            @"Set PC/Game resolution: ": @"PC·게임 해상도: ",
            @"Unsupported on this device": @"이 기기에서는 안 돼요",
        };
    });
    return map;
}

+ (void)styleSettingsView:(UIView*)root {
    static UIColor* text, *dim, *chip, *accent;
    text = [UIColor colorWithRed:0xe6/255.0 green:0xeb/255.0 blue:0xf5/255.0 alpha:1];
    dim = [UIColor colorWithRed:0x9a/255.0 green:0xa6/255.0 blue:0xc0/255.0 alpha:1];
    chip = [UIColor colorWithWhite:1 alpha:0.07];
    accent = [UIColor colorWithRed:0x7c/255.0 green:0x8c/255.0 blue:0xff/255.0 alpha:1];
    root.backgroundColor = [UIColor colorWithRed:0x16/255.0 green:0x1b/255.0 blue:0x26/255.0 alpha:1];
    NSDictionary* ko = [self koreanText];
    // Translate first so the new row can find the stats label, then style everything
    for (NSArray* pass in @[@[@0], @[@1]]) {
        if ([pass.firstObject intValue] == 1) {
            [self addStatsStyleRow:root];
            break;
        }
        NSMutableArray* st = [NSMutableArray arrayWithObject:root];
        while (st.count > 0) {
            UIView* v = st.lastObject;
            [st removeLastObject];
            if ([v isKindOfClass:UILabel.class] && ko[((UILabel*)v).text]) ((UILabel*)v).text = ko[((UILabel*)v).text];
            [st addObjectsFromArray:v.subviews];
        }
    }

    NSMutableArray* stack = [NSMutableArray arrayWithObject:root];
    while (stack.count > 0) {
        UIView* v = stack.lastObject;
        [stack removeLastObject];
        if ([v isKindOfClass:UISegmentedControl.class]) {
            UISegmentedControl* s = (UISegmentedControl*)v;
            for (NSUInteger i = 0; i < s.numberOfSegments; i++) {
                NSString* t = [s titleForSegmentAtIndex:i];
                if (t && ko[t]) [s setTitle:ko[t] forSegmentAtIndex:i];
            }
            s.backgroundColor = chip;
            s.selectedSegmentTintColor = UIColor.whiteColor;
            [s setTitleTextAttributes:@{NSFontAttributeName: [self fontOfSize:12 weight:UIFontWeightMedium],
                                        NSForegroundColorAttributeName: dim} forState:UIControlStateNormal];
            [s setTitleTextAttributes:@{NSFontAttributeName: [self fontOfSize:12 weight:UIFontWeightSemibold],
                                        NSForegroundColorAttributeName: MoonHome.bgBottom} forState:UIControlStateSelected];
            continue;
        }
        if ([v isKindOfClass:UISlider.class]) {
            UISlider* s = (UISlider*)v;
            s.minimumTrackTintColor = accent;
            s.maximumTrackTintColor = [UIColor colorWithRed:0x3a/255.0 green:0x3f/255.0 blue:0x4b/255.0 alpha:1];
            continue;
        }
        if ([v isKindOfClass:UILabel.class]) {
            UILabel* l = (UILabel*)v;
            if (l.text && ko[l.text]) l.text = ko[l.text];
            l.font = [self fontOfSize:13 weight:UIFontWeightMedium];
            l.textColor = text;
            // Labels were sized for the English text and font
            CGFloat need = ceil([l sizeThatFits:CGSizeMake(CGFLOAT_MAX, l.bounds.size.height)].width);
            if (need > l.bounds.size.width && l.textAlignment != NSTextAlignmentRight) {
                CGRect f = l.frame;
                f.size.width = need;
                l.frame = f;
            }
            l.textAlignment = l.textAlignment == NSTextAlignmentCenter ? NSTextAlignmentLeft : l.textAlignment;
            continue;
        }
        if ([v isKindOfClass:UIScrollView.class]) {
            v.backgroundColor = UIColor.clearColor;
        }
        else if (v != root) {
            // Row containers: no own fill, and let the wider Korean labels show
            v.backgroundColor = UIColor.clearColor;
            v.clipsToBounds = NO;
        }
        [stack addObjectsFromArray:v.subviews];
    }
}

// Adds "통계 모양" (card or strip) under the stock stats toggle
+ (void)addStatsStyleRow:(UIView*)root {
    UIScrollView* scroll = nil;
    UILabel* statsLabel = nil;
    NSMutableArray* stack = [NSMutableArray arrayWithObject:root];
    while (stack.count > 0) {
        UIView* v = stack.lastObject;
        [stack removeLastObject];
        if ([v isKindOfClass:UILabel.class] && [((UILabel*)v).text isEqualToString:@"통계 표시"]) {
            statsLabel = (UILabel*)v;
            scroll = (UIScrollView*)v.superview;
        }
        [stack addObjectsFromArray:v.subviews];
    }
    if (statsLabel == nil || [scroll viewWithTag:7701] != nil) return;
    UISegmentedControl* toggle = nil;
    for (UIView* v in scroll.subviews) {
        if ([v isKindOfClass:UISegmentedControl.class] && v.frame.origin.y > statsLabel.frame.origin.y &&
            (toggle == nil || v.frame.origin.y < toggle.frame.origin.y)) {
            toggle = (UISegmentedControl*)v;
        }
    }
    if (toggle == nil) return;
    CGFloat y = CGRectGetMaxY(toggle.frame) + (toggle.frame.origin.y - CGRectGetMaxY(statsLabel.frame));
    UILabel* l = [[UILabel alloc] initWithFrame:CGRectMake(statsLabel.frame.origin.x, y, statsLabel.frame.size.width, statsLabel.frame.size.height)];
    l.text = @"통계 모양";
    l.tag = 7701;
    [scroll addSubview:l];
    UISegmentedControl* seg = [[UISegmentedControl alloc] initWithItems:@[@"카드", @"한 줄 띠"]];
    seg.frame = CGRectMake(toggle.frame.origin.x, CGRectGetMaxY(l.frame) + (toggle.frame.origin.y - CGRectGetMaxY(statsLabel.frame)),
                           toggle.frame.size.width, toggle.frame.size.height);
    seg.autoresizingMask = toggle.autoresizingMask;
    seg.selectedSegmentIndex = [NSUserDefaults.standardUserDefaults integerForKey:@"statsStyle"] == 1 ? 1 : 0;
    [seg addAction:[UIAction actionWithHandler:^(UIAction* a) {
        [NSUserDefaults.standardUserDefaults setInteger:((UISegmentedControl*)a.sender).selectedSegmentIndex forKey:@"statsStyle"];
    }] forControlEvents:UIControlEventValueChanged];
    [scroll addSubview:seg];
}

+ (NSString*)stageText:(const char*)stageName {
    static NSDictionary* map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            @"platform initialization": @"준비",
            @"name resolution": @"주소 찾기",
            @"audio stream initialization": @"소리 준비",
            @"RTSP handshake": @"연결 약속",
            @"control stream initialization": @"제어 준비",
            @"video stream initialization": @"화면 준비",
            @"input stream initialization": @"입력 준비",
            @"control stream establishment": @"제어 연결",
            @"video stream establishment": @"화면 연결",
            @"audio stream establishment": @"소리 연결",
            @"input stream establishment": @"입력 연결",
        };
    });
    NSString* s = [NSString stringWithUTF8String:stageName];
    return map[s] ?: s;
}

// Blurred art behind a big rounded cover, app name and a spinner: the same
// start screen as the Mac build. Tags: 1 = title, 2 = step, 3 = tip.
+ (UIView*)streamStartViewWithFrame:(CGRect)frame appName:(NSString*)appName {
    UIView* v = [[UIView alloc] initWithFrame:frame];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.userInteractionEnabled = NO;
    CAGradientLayer* g = [CAGradientLayer layer];
    g.colors = @[(id)MoonHome.bgTop.CGColor, (id)MoonHome.bgBottom.CGColor];
    g.frame = CGRectMake(0, 0, MAX(frame.size.width, frame.size.height), MAX(frame.size.width, frame.size.height));
    [v.layer addSublayer:g];

    UIImage* art = sPendingArt;
    CGFloat h = floor(frame.size.height * 0.5), w = floor(h * 0.75);
    CGFloat cy = frame.size.height / 2 - 24;
    if (art) {
        UIImageView* bg = [[UIImageView alloc] initWithFrame:CGRectInset(v.bounds, -40, -40)];
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        bg.contentMode = UIViewContentModeScaleAspectFill;
        bg.image = art;
        bg.alpha = 0.5;
        [v addSubview:bg];
        UIVisualEffectView* blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        blur.frame = v.bounds;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [v addSubview:blur];

        UIView* shadow = [[UIView alloc] initWithFrame:CGRectMake((frame.size.width - w) / 2, cy - h / 2, w, h)];
        shadow.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        shadow.layer.shadowColor = UIColor.blackColor.CGColor;
        shadow.layer.shadowOpacity = 0.6;
        shadow.layer.shadowRadius = 18;
        shadow.layer.shadowOffset = CGSizeMake(0, 12);
        shadow.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:shadow.bounds cornerRadius:18].CGPath;
        UIImageView* cover = [[UIImageView alloc] initWithFrame:shadow.bounds];
        cover.contentMode = UIViewContentModeScaleAspectFill;
        cover.image = art;
        cover.layer.cornerRadius = 18;
        cover.clipsToBounds = YES;
        [shadow addSubview:cover];
        [v addSubview:shadow];
    }
    CGFloat textY = art ? cy + h / 2 + 22 : frame.size.height / 2 - 10;

    UILabel* title = [[UILabel alloc] initWithFrame:CGRectMake(16, textY, frame.size.width - 32, 22)];
    title.tag = 1;
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    title.textAlignment = NSTextAlignmentCenter;
    title.textColor = UIColor.whiteColor;
    title.font = [self fontOfSize:16 weight:UIFontWeightMedium];
    title.text = [NSString stringWithFormat:@"%@ 시작 중...", appName];
    [v addSubview:title];

    UILabel* step = [[UILabel alloc] initWithFrame:CGRectMake(16, textY + 26, frame.size.width - 32, 16)];
    step.tag = 2;
    step.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    step.textAlignment = NSTextAlignmentCenter;
    step.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    step.font = [self fontOfSize:12 weight:UIFontWeightRegular];
    [v addSubview:step];

    UILabel* tip = [[UILabel alloc] initWithFrame:CGRectMake(16, frame.size.height - 40, frame.size.width - 32, 16)];
    tip.tag = 3;
    tip.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    tip.textAlignment = NSTextAlignmentCenter;
    tip.textColor = [UIColor colorWithWhite:1 alpha:0.45];
    tip.font = [self fontOfSize:11 weight:UIFontWeightRegular];
    tip.text = @"왼쪽 끝에서 밀면 연결을 끊어요";
    [v addSubview:tip];
    return v;
}

@end

#pragma mark - Korean dialogs

#import <objc/runtime.h>

static NSString* MoonKo(NSString* s) {
    if (s.length == 0) return s;
    static NSDictionary* map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            @"Add Host Manually": @"PC 직접 추가",
            @"If Moonlight doesn't find your local gaming PC automatically,\nenter the IP address of your PC": @"PC 주소를 넣으세요",
            @"Cancel": @"취소",
            @"OK": @"확인",
            @"Help": @"도움말",
            @"Connection Error": @"연결 오류",
            @"Connection Failed": @"연결 실패",
            @"Connection Help": @"연결 도움말",
            @"Connection Interrupted": @"연결 끊김",
            @"Network Error": @"네트워크 오류",
            @"Failed to resolve host.": @"PC 주소를 찾지 못했어요.",
            @"Network Test Complete": @"네트워크 검사 끝",
            @"Pairing": @"페어링",
            @"Pairing Failed": @"페어링 실패",
            @"Quitting App Failed": @"게임 끝내기 실패",
            @"Remove Host": @"PC 지우기",
            @"Test Network": @"네트워크 검사",
            @"View All Apps": @"숨긴 게임도 보기",
            @"Wake PC": @"PC 깨우기",
            @"Wake-On-LAN": @"PC 깨우기",
            @"Launch App": @"시작",
            @"Resume App": @"이어 하기",
            @"Quit App": @"끝내기",
            @"Resume Running App": @"실행 중인 게임 이어 하기",
            @"Quit Running App and Start": @"실행 중인 게임 끝내고 시작",
            @"Show App": @"보이기",
            @"Hide App": @"숨기기",
            @"Hidden": @"숨김",
            @"Custom Resolution Selected": @"직접 정한 해상도",
            @"Enter Custom Resolution": @"해상도 입력",
            @"Slow connection to PC\nReduce your bitrate": @"PC 연결이 느려요\n비트레이트를 낮춰 보세요",
            @"Poor connection to PC": @"PC 연결이 불안정해요",
        };
    });
    NSString* t = map[s];
    if (t) return t;
    if ([s hasSuffix:@" is currently running"]) {
        return [[s substringToIndex:s.length - 21] stringByAppendingString:@" 실행 중"];
    }
    if ([s hasPrefix:@"Enter the following PIN on the host machine: "]) {
        NSString* pin = [[s substringFromIndex:46] componentsSeparatedByString:@"\n"].firstObject;
        return [NSString stringWithFormat:@"PIN: %@\n\nPC의 Sunshine 화면에서 이 번호를 넣으세요.", pin];
    }
    return s;
}

@implementation UIViewController (MoonKorean)

+ (void)load {
#if !TARGET_OS_TV
    // Personal build: every alert is translated on its way to the screen, so
    // the stock alert code stays untouched
    Method a = class_getInstanceMethod(self, @selector(presentViewController:animated:completion:));
    Method b = class_getInstanceMethod(self, @selector(moon_presentViewController:animated:completion:));
    method_exchangeImplementations(a, b);
#endif
}

- (void)moon_presentViewController:(UIViewController*)vc animated:(BOOL)animated completion:(void (^)(void))completion {
    if ([vc isKindOfClass:UIAlertController.class]) {
        UIAlertController* a = (UIAlertController*)vc;
        a.title = MoonKo(a.title);
        a.message = MoonKo(a.message);
        for (UIAlertAction* action in a.actions) {
            NSString* t = MoonKo(action.title);
            if (t != action.title) [action setValue:t forKey:@"title"];
        }
    }
    [self moon_presentViewController:vc animated:animated completion:completion];
}

@end

#pragma mark - Stats overlay

@interface MoonStatsView : UIView
@property (nonatomic, strong) NSMutableArray<NSNumber*>* rtts;
@end

@implementation MoonStatsView
- (void)drawRect:(CGRect)rect {
    // Sparkline of recent latency inside the marked area (tag 9's frame)
    UIView* area = [self viewWithTag:9];
    if (area == nil || self.rtts.count < 2) return;
    CGRect r = area.frame;
    double maxv = 1;
    for (NSNumber* n in self.rtts) maxv = MAX(maxv, n.doubleValue);
    maxv *= 1.25;
    UIBezierPath* p = [UIBezierPath bezierPath];
    for (NSUInteger i = 0; i < self.rtts.count; i++) {
        CGFloat x = r.origin.x + r.size.width * i / (40 - 1);
        CGFloat y = CGRectGetMaxY(r) - r.size.height * self.rtts[i].doubleValue / maxv;
        if (i == 0) [p moveToPoint:CGPointMake(x, y)]; else [p addLineToPoint:CGPointMake(x, y)];
    }
    [[UIColor colorWithRed:0x7c/255.0 green:0x8c/255.0 blue:0xff/255.0 alpha:1] setStroke];
    p.lineWidth = 1.5;
    [p stroke];
}
@end

static MoonStatsView* sStats;

@implementation MoonStats

+ (NSString*)korean:(NSString*)text { return MoonKo(text); }

+ (void)reset {
    [sStats removeFromSuperview];
    sStats = nil;
}

static double num(NSString* text, NSString* pattern, NSInteger group) {
    NSRegularExpression* re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSTextCheckingResult* m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (m == nil || [m rangeAtIndex:group].location == NSNotFound) return -1;
    return [[text substringWithRange:[m rangeAtIndex:group]] doubleValue];
}

static NSString* str(NSString* text, NSString* pattern) {
    NSRegularExpression* re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSTextCheckingResult* m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    return m ? [text substringWithRange:[m rangeAtIndex:1]] : @"";
}

static UILabel* lab(UIView* parent, CGRect f, CGFloat size, UIFontWeight w, UIColor* c, NSString* t) {
    UILabel* l = [[UILabel alloc] initWithFrame:f];
    l.font = [MoonHome fontOfSize:size weight:w];
    l.textColor = c;
    l.text = t;
    [parent addSubview:l];
    return l;
}

+ (void)showText:(NSString*)text inView:(UIView*)view {
    if (text == nil) {
        sStats.hidden = YES;
        return;
    }
    double fps = num(text, @"([0-9.]+) FPS", 1);
    double drop = num(text, @"connection: ([0-9.]+)%", 1);
    double rtt = num(text, @"latency: ([0-9]+) ms", 1);
    double var = num(text, @"variance: ([0-9]+) ms", 1);
    double host = num(text, @"min/max/avg: [0-9.]+/[0-9.]+/([0-9.]+)", 1);
    NSString* res = str(text, @"stream: ([0-9]+x[0-9]+)");
    NSString* codec = str(text, @"Codec: ([^)]+)\\)");

    if (sStats == nil || sStats.superview != view) {
        [sStats removeFromSuperview];
        sStats = [[MoonStatsView alloc] init];
        sStats.rtts = [NSMutableArray array];
        sStats.userInteractionEnabled = NO;
        sStats.backgroundColor = [UIColor colorWithRed:0x0a/255.0 green:0x0c/255.0 blue:0x11/255.0 alpha:0.72];
        sStats.opaque = NO;
        [view addSubview:sStats];
    }
    sStats.hidden = NO;
    [view bringSubviewToFront:sStats];
    if (rtt >= 0) {
        [sStats.rtts addObject:@(rtt)];
        while (sStats.rtts.count > 40) [sStats.rtts removeObjectAtIndex:0];
    }
    for (UIView* v in [sStats.subviews copy]) [v removeFromSuperview];

    UIColor* text1 = [UIColor colorWithRed:0xe6/255.0 green:0xeb/255.0 blue:0xf5/255.0 alpha:1];
    UIColor* dim = [UIColor colorWithRed:0x9a/255.0 green:0xa6/255.0 blue:0xc0/255.0 alpha:1];
    UIColor* good = [UIColor colorWithRed:0x3e/255.0 green:0xcf/255.0 blue:0x8e/255.0 alpha:1];
    UIColor* warn = [UIColor colorWithRed:0xe0/255.0 green:0xb2/255.0 blue:0x52/255.0 alpha:1];
    UIColor* bad = [UIColor colorWithRed:0xe0/255.0 green:0x5a/255.0 blue:0x52/255.0 alpha:1];
    BOOL isBad = drop > 5 || rtt > 60, isWarn = drop > 1 || rtt > 25;
    UIColor* dotColor = isBad ? bad : isWarn ? warn : good;
    NSString* state = isBad ? @"연결 나쁨" : isWarn ? @"연결 보통" : @"연결 좋음";
    NSString* rttText = rtt >= 0 ? [NSString stringWithFormat:@"%.0f ms", rtt] : @"-";

    UIEdgeInsets safe = view.safeAreaInsets;
    BOOL strip = [NSUserDefaults.standardUserDefaults integerForKey:@"statsStyle"] == 1;
    if (strip) {
        // One line, top middle
        UIView* dot = [[UIView alloc] initWithFrame:CGRectMake(14, 12, 7, 7)];
        dot.backgroundColor = dotColor;
        dot.layer.cornerRadius = 3.5;
        [sStats addSubview:dot];
        NSString* line = [NSString stringWithFormat:@"%@    프레임 %.0f    지연 %@    손실 %.1f%%", state, fps, rttText, MAX(drop, 0)];
        UILabel* l = lab(sStats, CGRectZero, 12, UIFontWeightMedium, text1, line);
        [l sizeToFit];
        l.frame = CGRectMake(28, 7, l.bounds.size.width, 17);
        CGFloat w = l.bounds.size.width + 42;
        sStats.frame = CGRectMake((view.bounds.size.width - w) / 2, MAX(8, safe.top) + 4, w, 31);
        sStats.layer.cornerRadius = 15.5;
        [sStats setNeedsDisplay];
        return;
    }

    CGFloat W = 230, x = 14;
    UIView* dot = [[UIView alloc] initWithFrame:CGRectMake(x, 19, 7, 7)];
    dot.backgroundColor = dotColor;
    dot.layer.cornerRadius = 3.5;
    [sStats addSubview:dot];
    lab(sStats, CGRectMake(x + 13, 14, 100, 16), 12, UIFontWeightMedium, dim, state);
    UILabel* fmt = lab(sStats, CGRectMake(W - 124, 14, 110, 16), 10, UIFontWeightRegular, [UIColor colorWithWhite:1 alpha:0.35],
                       [NSString stringWithFormat:@"%@ · %@", codec, res]);
    fmt.textAlignment = NSTextAlignmentRight;

    lab(sStats, CGRectMake(x, 44, 100, 14), 10, UIFontWeightRegular, dim, @"프레임");
    lab(sStats, CGRectMake(x, 58, 100, 26), 20, UIFontWeightSemibold, text1, fps >= 0 ? [NSString stringWithFormat:@"%.0f", fps] : @"-");
    lab(sStats, CGRectMake(x + 108, 44, 100, 14), 10, UIFontWeightRegular, dim, @"네트워크 지연");
    lab(sStats, CGRectMake(x + 108, 58, 110, 26), 20, UIFontWeightSemibold, text1, rttText);

    UIView* spark = [[UIView alloc] initWithFrame:CGRectMake(x, 94, W - 2 * x, 30)];
    spark.tag = 9;
    spark.userInteractionEnabled = NO;
    spark.backgroundColor = UIColor.clearColor;
    [sStats addSubview:spark];

    NSArray* rows = @[@[@"떨어진 프레임", [NSString stringWithFormat:@"%.2f%%", MAX(drop, 0)]],
                      @[@"흔들림", var >= 0 ? [NSString stringWithFormat:@"%.0f ms", var] : @"-"],
                      @[@"PC 처리", host >= 0 ? [NSString stringWithFormat:@"%.1f ms", host] : @"-"]];
    CGFloat y = 134;
    for (NSArray* r in rows) {
        lab(sStats, CGRectMake(x, y, 120, 18), 11, UIFontWeightRegular, dim, r[0]);
        UILabel* v = lab(sStats, CGRectMake(W - 114, y, 100, 18), 11, UIFontWeightMedium, text1, r[1]);
        v.textAlignment = NSTextAlignmentRight;
        y += 20;
    }
    sStats.frame = CGRectMake(MAX(14, safe.left), MAX(14, safe.top), W, y + 8);
    sStats.layer.cornerRadius = 14;
    [sStats setNeedsDisplay];
}

@end
