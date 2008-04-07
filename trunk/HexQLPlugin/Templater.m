#import "Templater.h"
#import <Foundation/NSException.h>

@implementation NSDictionary (Templater)
	
	- (NSString*) applyToTemplate: (NSString*) templateString {
    NSMutableString* res = [[[NSMutableString alloc] init] autorelease];

    Boolean escape = false;
    NSMutableString* replacementToken = [[[NSMutableString alloc]init]autorelease];
    NSUInteger length = [templateString length];
    NSUInteger i;
    for ( i=0; i<length; i++) {
      const unichar currentChar = [templateString characterAtIndex:i];
      if (escape) {
        if (currentChar == [@"»" characterAtIndex:0]) {
          NSString* toInsert = [self objectForKey:replacementToken];
          if (!toInsert) {
            NSLog(@"building exception");
            NSException* e = [NSException 
                              //exceptionWithName:@"TemplaterException" 
                              exceptionWithName:@"FileNotFoundException"
                              reason: [NSString stringWithFormat:@"parameter '%@' not found", replacementToken]
                              userInfo:nil];
            NSLog(@"throwing exception");
            @throw e;
          } else {
            [res appendString:toInsert];
          }
          escape = false;
        } else {
          [replacementToken appendString:[NSString stringWithCharacters:&currentChar length:1]];
        }
      } else {
        if (currentChar == [@"«" characterAtIndex:0]) {
          escape = true;
          replacementToken = [[[NSMutableString alloc]init]autorelease];
        } else {
          [res appendString:[NSString stringWithCharacters:&currentChar length:1]];
        }
      }
    }

    if (escape) {
      [[NSException exceptionWithName:@"TemplaterException" reason:@"wrong escape state" userInfo:nil]raise];
    }
    
		return res;
	}

@end
