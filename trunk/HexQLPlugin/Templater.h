#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

@interface NSDictionary (Templater)
- (NSString*) applyToTemplate:(NSString*) templateString;  
@end
