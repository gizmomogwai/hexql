#import <Foundation/NSString.h>
#import <Foundation/NSStream.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSException.h>

#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>

#import <QuickLook/QuickLook.h>
#import <QuickLook/QLGenerator.h>
#import "Templater.h"
#import "CharFilter.h"
#import "AsciiCharFilter.h"

Boolean readFromUrl(CFURLRef url, UInt8* buffer, CFIndex length, CFIndex* bytesRead) {
	CFReadStreamRef input = CFReadStreamCreateWithFile(kCFAllocatorDefault, url);
	if (!input) 
	{
	  return false;
	}
	
	Boolean streamOpened = CFReadStreamOpen(input);
	if (!streamOpened)
	{
		return false;		
	}

	*bytesRead = CFReadStreamRead(input, buffer, length);
	if (*bytesRead == -1)
	{
	  return false;
	}
	return true;
}

NSString* createAscii(UInt8* buffer, CFIndex length) {
	NSMutableString* html = [[[NSMutableString alloc] init] autorelease];
  
  [html appendString:@"<code>"];

  CFStringRef help = (CFStringRef)[NSString stringWithCString:(const char*)buffer length:(NSUInteger)length];
  CFStringRef escaped = CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, help, NULL);
  NSString* stuff = [(NSString*)escaped stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br/>"];
  stuff = [stuff stringByReplacingOccurrencesOfString:@"\r" withString:@"<br/>"];
  stuff = [stuff stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
  stuff = [stuff stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"];
  [html appendString:(NSString*)stuff];

  CFRelease(escaped);
  
  [html appendString:@"</code>"];
 
  return html;
}
  

NSString* createTable(UInt8* buffer, CFIndex length, int itemsPerRow, NSString* format, NSString* className, CharFilter* filter) {
	NSMutableString* html = [[[NSMutableString alloc] init] autorelease];
  [html appendFormat:@"<table class=\"%@\">", className];
	
	Boolean newLine = true;
	int count = 0;
  int totalCount = 0;
	CFIndex i = 0;
	for (i=0; i<length; i++) {
		if (newLine) {
		  [html appendString:@"<tr>"];
		  newLine = false;
		}
		
    const unichar c = buffer[i];
    NSString* idString = [NSString stringWithFormat:@"%@-%d", className, totalCount];
    if ([filter filter:c]) {
		  [html appendString:[NSString stringWithFormat:format, idString, c]];
    } else {
      [html appendString:[NSString stringWithFormat:@"<td id=\"%@\" class=\"linkedTable\">&nbsp;</td>", idString]];
    }
		count++;
    totalCount++;

		if (count % itemsPerRow == 0) {		
		  newLine = true;
		  [html appendString:@"</tr>"];
		  count = 0;
		} else if (count % 8 == 0) {
		  [html appendString:@"<td class=\"leftSeparator\" />"];
		  [html appendString:@"<td class=\"rightSeparator\" />"];
		}
	}
	
	if (count > 0) {
		[html appendString:@"</tr>"];
	}
	
	[html appendString:@"</table>"];
	return html;
}

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    NSLog(@"hex ql");
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSBundle* bundle = [NSBundle bundleWithIdentifier:@"com.flopcode.hexql"];
	if (!bundle) {
	  NSLog(@"could not found boundle");
	  return 1;
	}	

	NSURL* templateUrl = [NSURL fileURLWithPath:[bundle pathForResource:@"template" ofType:@"dhtml"]];
	if (!templateUrl) {
	  NSLog(@"templateUrl not found");
	  return 1;
	}
	NSLog([templateUrl path]);
	
	NSString* template = [NSString stringWithContentsOfURL:templateUrl encoding:(NSStringEncoding)NSUTF8StringEncoding error:nil];
	if (!template) {
		NSLog(@"could not load from template");
		return 1;
	}
	NSLog(template);
	
	UInt8 buffer[1000];
	CFIndex numBytesRead = 0;
	if (readFromUrl(url, buffer, sizeof(buffer), &numBytesRead)) {
    NSMutableDictionary* templateDic = [[[NSMutableDictionary alloc]init]autorelease];
    [templateDic setObject:(NSString*)(CFURLGetString(url)) forKey:@"path"];
    [templateDic setObject:createTable(buffer, numBytesRead, 16, @"<td class=\"linkedTable\" id=\"%@\">%02X</td>", @"hex", [[[CharFilter alloc]init]autorelease]) forKey:@"hextable"];
    [templateDic setObject:createTable(buffer, numBytesRead, 16, @"<td class=\"linkedTable\" id=\"%@\">%c</td>", @"ascii", [[[AsciiCharFilter alloc]init]autorelease]) forKey:@"asciitable"];
    [templateDic setObject:createAscii(buffer, numBytesRead) forKey:@"ascii"];
    [templateDic setObject:[[NSURL fileURLWithPath:[bundle resourcePath]] absoluteString] forKey:@"resourcepath"];
    @try {
      NSString* html = [templateDic applyToTemplate:template];
      NSLog(html);
    	
      NSMutableDictionary* props = [[[NSMutableDictionary alloc] init] autorelease];
      [props setObject:@"UTF-8" forKey:(NSString*) kQLPreviewPropertyTextEncodingNameKey];
      [props setObject:@"text/html" forKey:(NSString*) kQLPreviewPropertyMIMETypeKey];
      CFStringRef fullPath = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
      [props setObject:[NSString stringWithFormat:@"Contents of %@", fullPath] forKey:(NSString*)kQLPreviewPropertyDisplayNameKey];
      [props setObject:[NSNumber numberWithInt:850] forKey:(NSString*)kQLPreviewPropertyWidthKey];
      [props setObject:[NSNumber numberWithInt:600] forKey:(NSString*)kQLPreviewPropertyHeightKey];
      QLPreviewRequestSetDataRepresentation(preview,
		                                        (CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding],
                                            kUTTypeHTML,
                                            (CFDictionaryRef)props);
    } @catch (NSException* e) {
      NSLog([e reason]);
      [pool release];
      return 1;
    }
  }
  [pool release];
  return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
}
