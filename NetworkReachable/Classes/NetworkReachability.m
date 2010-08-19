//
//  NetworkReachability.m
//  NetworkReachable
//
//  Created by Hiroshi Hashiguchi on 10/08/12.
//  Copyright 2010 . All rights reserved.
//

#import "NetworkReachability.h"

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>


@implementation NetworkReachability

- (id)initWithHostname:(NSString*)hostname
{
	if (self = [super init]) {
		reachability_=
			SCNetworkReachabilityCreateWithName(kCFAllocatorDefault,
											[hostname UTF8String]);
	}
	return self;
}

+ (NetworkReachability*)networkReachabilityWithHostname:(NSString*)hostname
{
	return [[[self alloc] initWithHostname:hostname] autorelease];
}

- (void) dealloc
{
	CFRetain(reachability_);
	[super dealloc];
}


- (NSString*)getWiFiIPAddress
{
	BOOL success;
	struct ifaddrs * addrs;
	const struct ifaddrs * cursor;
	
	success = getifaddrs(&addrs) == 0;
	if (success) {
		cursor = addrs;
		while (cursor != NULL) {
			if (cursor->ifa_addr->sa_family == AF_INET
				&& (cursor->ifa_flags & IFF_LOOPBACK) == 0) {
				NSString *name =
				[NSString stringWithUTF8String:cursor->ifa_name];
				
				if ([name isEqualToString:@"en1"]) { // found the WiFi adapter
					return [NSString stringWithUTF8String:
							inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
				}
			}
			
			cursor = cursor->ifa_next;
		}
		freeifaddrs(addrs);
	}
	return NULL;
}


// return
//	 0: no connection
//	 1: celluar connection
//	 2: wifi connection
- (int)getConnectionMode
{
	if (reachability_) {
		SCNetworkReachabilityFlags flags = 0;
		SCNetworkReachabilityGetFlags(reachability_, &flags);
		
		BOOL isReachable = ((flags & kSCNetworkFlagsReachable) != 0);
		BOOL needsConnection = ((flags & kSCNetworkFlagsConnectionRequired) != 0);
		if (isReachable && !needsConnection) {
			if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
				return kNetworkReachableWWAN;
			}
			
			if ([self getWiFiIPAddress]) {
				return kNetworkReachableWiFi;
			}
			
		}
	}
	return kNetworkReachableNon;
}


static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
	NSAutoreleasePool* myPool = [[NSAutoreleasePool alloc] init];
	NetworkReachability* noteObject = (NetworkReachability*)info;
	[[NSNotificationCenter defaultCenter]
		postNotificationName:NetworkReachabilityChangedNotification object:noteObject];
	
	[myPool release];
}

- (BOOL)startNotifier
{
	BOOL ret = NO;
	SCNetworkReachabilityContext context = {0, self, NULL, NULL, NULL};
	if(SCNetworkReachabilitySetCallback(reachability_, ReachabilityCallback, &context))
	{
		if(SCNetworkReachabilityScheduleWithRunLoop(
													reachability_, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
		{
			ret = YES;
		}
	}
	return ret;
}	

- (void) stopNotifier
{
	if(reachability_!= NULL)
	{
		SCNetworkReachabilityUnscheduleFromRunLoop(reachability_, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}
}

@end
