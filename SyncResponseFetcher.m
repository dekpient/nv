//
//  SyncResponseFetcher.m
//  Notation
//
//  Created by Zachary Schneirov on 11/29/09.

/*Copyright (c) 2010, Zachary Schneirov. All rights reserved.
    This file is part of Notational Velocity.

    Notational Velocity is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Notational Velocity is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Notational Velocity.  If not, see <http://www.gnu.org/licenses/>. */


#import "SyncResponseFetcher.h"
#import "NSData_transformations.h"

@implementation SyncResponseFetcher

+ (void)initialize {
	
	static BOOL initialized = NO;
    [super initialize];
    if (!initialized) {
		[[NSURLCache sharedURLCache] setDiskCapacity:0];
    }
}


- (id)initWithURL:(NSURL*)aURL POSTData:(NSData*)POSTData headers:(NSDictionary *)aHeaders delegate:(id)aDelegate {
	return [self initWithURL:aURL POSTData:POSTData headers:aHeaders contentType:nil delegate:aDelegate];
 }

 - (id)initWithURL:(NSURL*)aURL POSTData:(NSData*)POSTData delegate:(id)aDelegate {
	return [self initWithURL:aURL POSTData:POSTData headers:nil contentType:nil delegate:aDelegate];
 }

 - (id)initWithURL:(NSURL*)aURL POSTData:(NSData*)POSTData headers:(NSDictionary *)aHeaders contentType:(NSString*)contentType delegate:(id)aDelegate {
	if ([self init]) {
		receivedData = [[NSMutableData alloc] init];
		requestURL = [aURL retain];
		delegate = aDelegate;
		dataToSend = [POSTData retain];
		dataToSendContentType = [contentType copy];
		requestHeaders = [aHeaders retain];
	}
	return self;
}

- (NSInvocation*)successInvocation {
	return successInvocation;
}

- (void)setRepresentedObject:(id)anObject {
	[representedObject autorelease];
	representedObject = [anObject retain];
}

- (id)representedObject {
	return representedObject;
}

- (BOOL)startWithSuccessInvocation:(NSInvocation*)anInvocation {

	successInvocation = [anInvocation retain];
	return [self start];
}

- (BOOL)start {
	
	if (isRunning) return YES;
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
	if (!request) {
		NSLog(@"%s: Couldn't create HTTP request with URL %@", _cmd, requestURL);
		return NO;
	}
	
	[request setHTTPShouldHandleCookies:NO];
	[request addValue:@"Sinus cardinalis NV 2.0B5" forHTTPHeaderField:@"User-agent"];
	
	if (requestHeaders) {
		for (NSString *field in [requestHeaders allKeys]) {
			[request addValue:[requestHeaders objectForKey:field] forHTTPHeaderField:field];
		}
	}
	
	//if POSTData is nil, do a plain GET request
	if (dataToSend) {
		if (dataToSendContentType) {
			[request addValue:dataToSendContentType forHTTPHeaderField:@"Content-Type"];
		}
		
		[request setHTTPBody:dataToSend];
		[request setHTTPMethod:@"POST"];
	}
	
	[self retain];
	[delegate retain];
	
	didCancel = NO;
	isRunning = YES;
	
	//NSLog(@"starting request for URL '%@'", requestURL);
	if (!(urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self])) {
		NSLog(@"%s: Couldn't create NSURLConnection with URLRequest %@", _cmd, request);
		isRunning = NO;
		[self release];
		[delegate release];
		return NO;
	}
	
	return YES;
}

- (BOOL)isRunning {
	return isRunning;
}

- (BOOL)didCancel {
	return didCancel;
}

- (void)cancel {
	if (!isRunning) return;
	
	didCancel = YES;
	
	[urlConnection cancel];
	[self _fetchDidFinishWithError:NSLocalizedString(@"Operation cancelled", 
													 @"Error string returned to indicate that the user cancelled a syncing service operation")];
}

- (void)dealloc {
	
	[dataToSend release];
	[dataToSendContentType release];
	[requestURL release];
	[receivedData release];
	[urlConnection release];
	[headers release];
	[representedObject release];
	
	[super dealloc];
}

- (id)delegate {
	return delegate;
}

- (NSURL*)requestURL {
	return requestURL;
}

- (NSDictionary*)headers {
	return headers;
}

- (NSInteger)statusCode {
	return lastStatusCode;
}

- (NSString*)errorMessage {
	return lastErrorMessage;
}

- (NSString*)description {
	return [NSString stringWithFormat:@"Fetcher(%X, %@)", self, requestURL];
}

- (void)_fetchDidFinishWithError:(NSString*)anErrString {
	
	if (!isRunning) {
		NSLog(@"not processing %s because fetcher was already stopped; should not be called", _cmd);
		return;
	}
	//assumes that anErrString will always be provided in the case of any error, and thus indicates the presence of such
	[delegate syncResponseFetcher:self receivedData:anErrString ? nil : receivedData returningError:anErrString];

	//delegate just had another opportunity to stop us, so check to see if he did that
	if (!isRunning) {
		return;
	}
	
	if (!anErrString) [successInvocation invoke];
	
	[successInvocation autorelease];
	successInvocation = nil;
	
	[lastErrorMessage autorelease];
	lastErrorMessage = [anErrString retain];
	
	[receivedData setLength:0];
	
	[urlConnection autorelease];
	urlConnection = nil;
	isRunning = NO;
	
	[self autorelease];
	[delegate autorelease];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[receivedData setLength:0];
	
	lastStatusCode = 0;
	BOOL responseValid = [response isKindOfClass:[NSHTTPURLResponse class]];
	lastStatusCode = [(NSHTTPURLResponse*)response statusCode];
	if (!responseValid) {
		[urlConnection cancel];
		[self _fetchDidFinishWithError:[NSHTTPURLResponse localizedStringForStatusCode:lastStatusCode]];
	} else if (responseValid) {
		[headers autorelease];
		headers = [[(NSHTTPURLResponse*)response allHeaderFields] copy];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if (data) {
		[receivedData appendData:data];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self _fetchDidFinishWithError:nil];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[self _fetchDidFinishWithError:[error localizedDescription]];
}

@end
