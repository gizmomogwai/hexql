#import "Foundation/Foundation.h"
#import "CoreFoundation/CoreFoundation.h"
#import "CoreServices/CoreServices.h"

#import "QuickLook/QuickLook.h"

#import "Templater.h"
#import "CharFilter.h"
#import "AsciiCharFilter.h"

/**
 * read the first 4k from the url
 */
NSData* readFirstBytes(CFURLRef url) {
  NSFileHandle* filehandle = [NSFileHandle fileHandleForReadingFromURL:(NSURL*)url error:nil];
  if (!filehandle) {
    NSLog(@"got no filehandle");
  }
  
  return [filehandle readDataOfLength:4096];
}

/**
 * converts the given data to a ascii string representation
 * charachters not printable by ascii are left out
 */
NSString* createAscii(NSData* data) {
  NSMutableString* html = [[NSMutableString new] autorelease];
  
  [html appendString:@"<code>"];

  NSMutableString* bufferAsNsString = [NSMutableString new] ;//[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
  const char* bytes = (const char*)[data bytes];
  for (int i=0; i<[data length]; i++) {
    [bufferAsNsString appendFormat:@"%c", bytes[i]];
  }
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
  
/**
 * create a html table from the data
 */
NSString* createTable(NSData* data,
                      int itemsPerRow,
                      NSString* format,
                      NSString* className,
                      CharFilter* filter) {
  NSMutableString* html = [[NSMutableString new] autorelease];
  [html appendFormat:@"<table class=\"striped %@\" cellspacing=\"0\">", className];
  [html appendString:@"<tr><th></th>"];
  {
    CFIndex i = 0;
    for (i=0; i<itemsPerRow; i++) {
      [html appendString:[NSString stringWithFormat:@"<th>%02lX</th>", i]];
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
        [html appendString:[NSString stringWithFormat:@"<th>%04lX</th>", (unsigned long)i]] ;
        newLine = false;
      }
      
      const unichar c = ((const unsigned char*)[data bytes])[i];
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

NSString* getTemplateFromBundle(NSBundle *bundle)
{
    NSURL* templateUrl = [NSURL
                          fileURLWithPath:[bundle
                                           pathForResource:@"template"
                                           ofType:@"dhtml"]];
    if (!templateUrl) {
        NSLog(@"templateUrl not found");
        return nil;
    }
    NSLog(@"%@", [templateUrl path]);
    
    NSString* template = [NSString
                          stringWithContentsOfURL:templateUrl
                          encoding:(NSStringEncoding)NSUTF8StringEncoding error:nil];
    if (!template) {
        NSLog(@"could not load from template");
        return nil;
    }
    return template;
}

OSStatus GeneratePreviewForURL(void *thisInterface,
                               QLPreviewRequestRef preview,
                               CFURLRef url,
                               CFStringRef contentTypeUTI,
                               CFDictionaryRef options)
{
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
  // open bundle
  NSBundle* bundle = [NSBundle bundleWithIdentifier:@"com.flopcode.hexql"];
  if (!bundle) {
    NSLog(@"could not find boundle");
    return 1;
  }	

  NSString *template = getTemplateFromBundle(bundle);
  if (!template) {
    return 1;
  }
    
  NSData* firstBytes = readFirstBytes(url);
  if (firstBytes) {
    NSMutableDictionary* templateDic = [[[NSMutableDictionary alloc]init]autorelease];
    [templateDic
       setObject:(NSString*)(CFURLGetString(url))
       forKey:@"path"];
    [templateDic
       setObject:createTable(firstBytes, 16, @"<td id=\"%@\">%02X </td>", @"hex", [[[CharFilter alloc]init] autorelease])
       forKey:@"hextable"];
    [templateDic
       setObject:createTable(firstBytes, 16, @"<td id=\"%@\">%c</td>", @"ascii", [[[AsciiCharFilter alloc]init]autorelease])
       forKey:@"asciitable"];
    [templateDic
       setObject:createAscii(firstBytes)
       forKey:@"ascii"];
    [templateDic
       setObject:[[NSURL fileURLWithPath:[bundle resourcePath]] absoluteString]
       forKey:@"resourcepath"];
    @try {
      NSString* html = [templateDic applyToTemplate:template];
      NSString* debug = [[NSUserDefaults standardUserDefaults] stringForKey:@"HexQL.debug"];
      if ([debug compare:@"yes"] == NSOrderedSame) {
        BOOL res = [html writeToFile:@"/tmp/out.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        NSLog(@"hat soweit geklappt %d", res);
      }
      
      NSMutableDictionary* props = [[[NSMutableDictionary alloc] init] autorelease];
      [props
         setObject:@"UTF-8"
         forKey:(NSString*) kQLPreviewPropertyTextEncodingNameKey];
      [props
         setObject:@"text/html"
         forKey:(NSString*) kQLPreviewPropertyMIMETypeKey];
      CFStringRef fullPath = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
        NSLog(@"mhhh %@", fullPath);
      [props
         setObject:[NSString stringWithFormat:@"Contents of %@", fullPath]
         forKey:(NSString*)kQLPreviewPropertyDisplayNameKey];
      [props
         setObject:[NSNumber numberWithInt:890]
         forKey:(NSString*)kQLPreviewPropertyWidthKey];
      [props
         setObject:[NSNumber numberWithInt:600]
         forKey:(NSString*)kQLPreviewPropertyHeightKey];
        
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
