//
//  MoonSeed.m
//  Moonlight
//

#import "MoonSeed.h"
#import "DataManager.h"
#import "TemporaryHost.h"
#import "Utils.h"

@implementation MoonSeed

+ (void)writeDocument:(NSString*)name data:(NSData*)data {
    NSString* dir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    [data writeToFile:[dir stringByAppendingPathComponent:name] atomically:YES];
}

+ (void)applyIfNeeded {
    NSURL* url = [NSBundle.mainBundle URLForResource:@"kunseed" withExtension:@"json"];
    if (url == nil) {
        return;
    }
    NSDictionary* seed = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:url] options:0 error:nil];
    NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
    NSString* version = seed[@"version"];
    if (![seed isKindOfClass:NSDictionary.class] || version == nil || [version isEqualToString:[defaults stringForKey:@"kunseedVersion"]]) {
        return;
    }

    // Same client identity as the Mac, so every PC it paired with trusts this device
    NSData* cert = [[NSData alloc] initWithBase64EncodedString:seed[@"cert"] options:0];
    NSData* key = [[NSData alloc] initWithBase64EncodedString:seed[@"key"] options:0];
    NSData* p12 = [[NSData alloc] initWithBase64EncodedString:seed[@"p12"] options:0];
    if (cert.length && key.length && p12.length) {
        [self writeDocument:@"client.crt" data:cert];
        [self writeDocument:@"client.key" data:key];
        [self writeDocument:@"client.p12" data:p12];
    }

    DataManager* dataMan = [[DataManager alloc] init];
    if ([seed[@"uniqueId"] length] > 0) {
        [dataMan updateUniqueId:seed[@"uniqueId"]];
    }

    NSMutableDictionary* existing = [NSMutableDictionary dictionary];
    for (TemporaryHost* h in [dataMan getHosts]) {
        if (h.uuid) existing[h.uuid] = h;
    }
    for (NSDictionary* h in seed[@"hosts"]) {
        TemporaryHost* host = existing[h[@"uuid"]] ?: [[TemporaryHost alloc] init];
        id (^str)(NSString*) = ^id(NSString* k) { return [h[k] isKindOfClass:NSString.class] ? h[k] : nil; };
        host.uuid = h[@"uuid"];
        host.name = str(@"name") ?: host.name;
        host.address = str(@"address") ?: host.address;
        host.localAddress = str(@"localAddress") ?: host.localAddress;
        host.externalAddress = str(@"externalAddress") ?: host.externalAddress;
        host.mac = str(@"mac") ?: host.mac;
        host.serverCert = [[NSData alloc] initWithBase64EncodedString:str(@"serverCert") ?: @"" options:0];
        host.pairState = PairStatePaired;
        [dataMan updateHost:host];

        NSArray* appOrder = h[@"appOrder"];
        NSString* appKey = [@"appOrder." stringByAppendingString:host.uuid];
        // Mac order only as a starting point; never overwrite an order set on this device
        if ([appOrder isKindOfClass:NSArray.class] && appOrder.count > 0 && [defaults objectForKey:appKey] == nil) {
            [defaults setObject:appOrder forKey:appKey];
        }
    }
    if ([seed[@"pcOrder"] isKindOfClass:NSArray.class] && [seed[@"pcOrder"] count] > 0 && [defaults objectForKey:@"pcOrder"] == nil) {
        [defaults setObject:seed[@"pcOrder"] forKey:@"pcOrder"];
    }
    [defaults setObject:version forKey:@"kunseedVersion"];
    Log(LOG_I, @"Imported KUNLIGHT seed %@ (%lu PCs)", version, (unsigned long)[seed[@"hosts"] count]);
}

@end
