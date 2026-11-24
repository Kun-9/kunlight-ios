//
//  MoonHome.h
//  Moonlight
//
//  Personal build: console-style home screen. PC chips sit in the
//  navigation bar, the selected PC's apps form a horizontal carousel with
//  the selected cover centered over a blurred copy of its art. Long-press
//  and drag reorders PCs and apps. Kept in its own file so upstream
//  changes to MainFrameViewController merge with only a few hook lines.
//

#import <UIKit/UIKit.h>
#import "TemporaryHost.h"
#import "TemporaryApp.h"

NS_ASSUME_NONNULL_BEGIN

@interface MoonHome : NSObject

// Theme
+ (UIColor*)bgTop;
+ (UIColor*)bgBottom;
+ (UIFont*)fontOfSize:(CGFloat)size weight:(UIFontWeight)weight;

// Box art from the cache or disk, or nil for none / the stock placeholder
+ (nullable UIImage*)artForApp:(TemporaryApp*)app cache:(NSCache*)cache;

- (instancetype)initWithCollectionView:(UICollectionView*)collectionView
                        navigationItem:(UINavigationItem*)navigationItem
                                 cache:(NSCache*)cache
                                onPick:(void (^)(TemporaryHost* host, UIView* view))onPick
                                onMenu:(void (^)(TemporaryApp* app, UIView* view))onMenu
                                 onAdd:(void (^)(void))onAdd;

// PC chips. Rebuilt only when something visible changed.
- (void)setHosts:(NSArray<TemporaryHost*>*)hosts selected:(nullable TemporaryHost*)selected;

// Hosts in the user's saved order, unknown ones after by name
- (NSArray<TemporaryHost*>*)orderedHosts:(NSArray<TemporaryHost*>*)hosts;

// Apps in the user's saved order for that PC, new ones after by name
- (NSArray<TemporaryApp*>*)orderedApps:(NSArray<TemporaryApp*>*)apps forHost:(TemporaryHost*)host;
- (void)saveAppOrder:(NSArray<TemporaryApp*>*)apps forHost:(TemporaryHost*)host;

// The app list shown in the carousel changed
@property (nonatomic, copy) NSArray<TemporaryApp*>* apps;
- (void)reloaded;

// Index of the centered app, or -1
- (NSInteger)currentIndex;
- (void)scrollToIndex:(NSInteger)index animated:(BOOL)animated;

// Cell content for an app
+ (void)configureCell:(UICollectionViewCell*)cell app:(TemporaryApp*)app cache:(NSCache*)cache;

@end

NS_ASSUME_NONNULL_END

// Settings sidebar and stream start screen in the same look (personal build)
@interface MoonHome (Screens)
+ (void)styleSettingsView:(UIView*)root;
+ (NSString*)stageText:(const char*)stageName;
// Box art of the app about to stream, set right before the stream view opens
@property (class, nonatomic, strong, nullable) UIImage* pendingArt;
+ (UIView*)streamStartViewWithFrame:(CGRect)frame appName:(NSString*)appName;
@end

// Stats overlay as a card or a one-line strip (personal build). Feed it the
// stock overlay text once a second; nil hides it.
@interface MoonStats : NSObject
+ (void)showText:(nullable NSString*)text inView:(UIView*)view;
+ (void)reset;
// Connection warnings and other stock overlay text, in Korean
+ (NSString*)korean:(NSString*)text;
@end
