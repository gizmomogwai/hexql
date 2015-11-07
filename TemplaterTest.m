#import <XCTest/XCTest.h>
#import "Templater.h"

@interface TemplaterTest : XCTestCase {
    
@private
    NSDictionary* tested;
    
}
@end

@implementation TemplaterTest

- (void)setUp {
    [super setUp];
    tested = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"123", @"abc", @"456", @"def", nil];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testFillIn {
    XCTAssertEqualObjects([tested applyToTemplate:@"«abc»"], @"123");
}

- (void)testTemplateWantsDataThatsNotThere {
    XCTAssertThrows([tested applyToTemplate:@"«ghi»"]);
}
@end
