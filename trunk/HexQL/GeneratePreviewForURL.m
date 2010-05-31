#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>

#import <QuickLook/QuickLook.h>

#import "Templater.h"
#import "CharFilter.h"
#import "AsciiCharFilter.h"

NSData* readFromUrl(NSURL* url) {
  NSFileHandle* filehandle = [NSFileHandle fileHandleForReadingFromURL:url error:nil];
  if (!filehandle) {
    NSLog(@"got no filehandle");
  }
  
  return [filehandle readDataOfLength:4096];
}

NSString* createAscii(NSData* data) {
  NSMutableString* html = [[NSMutableString new] autorelease];
  
  [html appendString:@"<code>"];

  NSString* bufferAsNsString = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
  CFStringRef help = (CFStringRef)bufferAsNsString;
  CFStringRef escaped = CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, help, NULL);
  [bufferAsNsString release];
  NSString* stuff = [(NSString*)escaped stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br/>"];
  stuff = [stuff stringByReplacingOccurrencesOfString:@"\r" withString:@"<br/>"];
  stuff = [stuff stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
  stuff = [stuff stringByReplacingOccurrencesOfString:@" " withString:@"&nbsp;"];
  [html appendString:(NSString*)stuff];

  CFRelease(escaped);
  
  [html appendString:@"</code>"];
 
  return html;
}
  

NSString* createTable(NSData* data, int itemsPerRow, NSString* format, NSString* className, CharFilter* filter) {
  NSMutableString* html = [[NSMutableString new] autorelease];
  [html appendFormat:@"<table class=\"striped %@\" cellspacing=\"0\">", className];
  [html appendString:@"<tr><th></th>"];
  {
    CFIndex i = 0;
    for (i=0; i<itemsPerRow; i++) {
      [html appendString:[NSString stringWithFormat:@"<th>%02X</th>", i]];
    }
    
  }
  [html appendString:@"</tr>"];

  Boolean newLine = true;
  int count = 0;
  int totalCount = 0;
  {
    NSUInteger i; 
    for (i=0; i<[data length]; i++) {
      if (newLine) {
        [html appendString:@"<tr class=\"striped\">"];
        [html appendString:[NSString stringWithFormat:@"<th>%04X</th>", i]] ;
        newLine = false;
      }
      
      const unichar c = ((const char*)[data bytes])[i];
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
      } 
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
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  NSBundle* bundle = [NSBundle bundleWithIdentifier:@"com.flopcode.hexql"];
  if (!bundle) {
    NSLog(@"could not find boundle");
    return 1;
  }	

  NSURL* templateUrl = [NSURL fileURLWithPath:[bundle pathForResource:@"template" ofType:@"dhtml"]];
  if (!templateUrl) {
    NSLog(@"templateUrl not found");
    return 1;
  }
  NSLog(@"%@", [templateUrl path]);
	
  NSString* template = [NSString stringWithContentsOfURL:templateUrl encoding:(NSStringEncoding)NSUTF8StringEncoding error:nil];
  if (!template) {
    NSLog(@"could not load from template");
    return 1;
  }

  NSData* firstBytes = readFromUrl(url);
  if (firstBytes) {
    NSMutableDictionary* templateDic = [[[NSMutableDictionary alloc]init]autorelease];
    [templateDic setObject:(NSString*)(CFURLGetString(url)) forKey:@"path"];
    [templateDic setObject:createTable(firstBytes, 16, @"<td class=\"linkedTable\" id=\"%@\">%02X</td>", @"hex", [[[CharFilter alloc]init]autorelease]) forKey:@"hextable"];
    [templateDic setObject:createTable(firstBytes, 16, @"<td class=\"linkedTable\" id=\"%@\">%c</td>", @"ascii", [[[AsciiCharFilter alloc]init]autorelease]) forKey:@"asciitable"];
    [templateDic setObject:createAscii(firstBytes) forKey:@"ascii"];
    [templateDic setObject:[[NSURL fileURLWithPath:[bundle resourcePath]] absoluteString] forKey:@"resourcepath"];
    @try {
      NSString* html = [templateDic applyToTemplate:template];

      BOOL res = [html writeToFile:@"/Users/gizmo/out.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
      NSLog(@"hat soweit geklappt %d", res);
      
      NSMutableDictionary* props = [[[NSMutableDictionary alloc] init] autorelease];
      [props setObject:@"UTF-8" forKey:(NSString*) kQLPreviewPropertyTextEncodingNameKey];
      [props setObject:@"text/html" forKey:(NSString*) kQLPreviewPropertyMIMETypeKey];
      CFStringRef fullPath = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
      [props setObject:[NSString stringWithFormat:@"Contents of %@", fullPath] forKey:(NSString*)kQLPreviewPropertyDisplayNameKey];
      [props setObject:[NSNumber numberWithInt:890] forKey:(NSString*)kQLPreviewPropertyWidthKey];
      [props setObject:[NSNumber numberWithInt:600] forKey:(NSString*)kQLPreviewPropertyHeightKey];
      QLPreviewRequestSetDataRepresentation(preview,
					    (CFDataRef)[html dataUsingEncoding:NSUTF8StringEncoding],
                                            kUTTypeHTML,
                                            (CFDictionaryRef)props);
    } @catch (NSException* e) {
      NSLog(@"%@", [e reason]);
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
