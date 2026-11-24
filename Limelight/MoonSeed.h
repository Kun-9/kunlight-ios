//
//  MoonSeed.h
//  Moonlight
//
//  Personal build: imports kunseed.json (made on the Mac by
//  tools/kunseed.py and copied into the app at build time) so the phone
//  starts with the Mac's PCs, pairing identity and orders.
//

#import <Foundation/Foundation.h>

@interface MoonSeed : NSObject

// Imports the bundled seed once per seed version. Call before the crypto
// identity is first read.
+ (void)applyIfNeeded;

@end
