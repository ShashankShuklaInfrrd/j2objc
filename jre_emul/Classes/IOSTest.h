// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
//  IOSTest.h
//  JreEmulation
//

#ifndef IOSTEST_H
#define IOSTEST_H

#import <XCTest/XCTest.h>
#import "java/lang/Throwable.h"

@interface IOSTest : XCTestCase {
}

- (instancetype)initWithSelector:(SEL)selector;
@end

__attribute__((always_inline)) inline void IOSTest_initialize(void) { }
FOUNDATION_EXPORT void JreInitTestClass(Class testClass);
FOUNDATION_EXPORT NSString* JreGetStackTraceText(JavaLangThrowable* exception);

#define XCTEST_BEGIN()  @try {

#define XCTEST_END()    } @catch (JavaLangThrowable* ex) { XCTFail(@"%@", JreGetStackTraceText(ex)); }

/**
 Copy following source into a source file of your Test build environment.

#import "IOSTest.h"

@implementation IOSTest

- (instancetype)initWithSelector:(SEL)selector {
  JreInitTestClass(self);
  self = [super initWithSelector:selector];
  return [self init];
}

@end
#endif
 */

#endif // IOSTEST_H
