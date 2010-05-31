#import "AsciiCharFilter.h"

@implementation AsciiCharFilter 

-(Boolean) filter:(const unichar)c {
  const unichar smallA = [@"a" characterAtIndex:0];
  const unichar smallZ = [@"z" characterAtIndex:0];
  const unichar bigA = [@"A" characterAtIndex:0];
  const unichar bigZ = [@"Z" characterAtIndex:0];
  const unichar zero = [@"0" characterAtIndex:0];
  const unichar nine = [@"9" characterAtIndex:0];
  return (c >= smallA && c <= smallZ) || (c >= bigA && c <= bigZ) || (c >= zero && c <= nine);
}
 
@end
