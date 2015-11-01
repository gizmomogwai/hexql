#import "CharFilter.h"

@interface AsciiCharFilter : CharFilter {
}

-(Boolean) filter:(const unichar)c;

@end
