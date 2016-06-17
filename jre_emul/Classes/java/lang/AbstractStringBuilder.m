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

#include "java/lang/AbstractStringBuilder.h"

#include "J2ObjC_source.h"
#include "java/io/InvalidObjectException.h"
#include "java/lang/ArrayIndexOutOfBoundsException.h"
#include "java/lang/Character.h"
#include "java/lang/Integer.h"
#include "java/lang/NegativeArraySizeException.h"
#include "java/lang/NullPointerException.h"
#include "java/lang/OutOfMemoryError.h"
#include "java/lang/StringIndexOutOfBoundsException.h"
#include "java/util/Arrays.h"
#include "libcore/util/EmptyArray.h"

// Full name as expected by generated metadata.
#define JavaLangAbstractStringBuilder_INITIAL_CAPACITY 16
// Shorter alias for convenience.
#define INITIAL_CAPACITY JavaLangAbstractStringBuilder_INITIAL_CAPACITY

static void JreStringBuilder_move(JreStringBuilder *self, jint size, jint index);

static void OutOfMemory() {
  @throw [[[JavaLangOutOfMemoryError alloc] init] autorelease];
}

static inline void NewBuffer(JreStringBuilder *sb, jint size) {
  sb->buffer_ = (jchar *)malloc(size * sizeof(jchar));
  if (__builtin_expect(sb->buffer_ == NULL, 0)) {
    OutOfMemory();
  }
  sb->bufferSize_ = size;
}

static JavaLangStringIndexOutOfBoundsException *IndexAndLength(JreStringBuilder *sb, jint index) {
  @throw [[[JavaLangStringIndexOutOfBoundsException alloc]
      initWithInt:sb->count_ withInt:index] autorelease];
}

static JavaLangStringIndexOutOfBoundsException *StartEndAndLength(
    JreStringBuilder *sb, jint start, jint end) {
  @throw [[[JavaLangStringIndexOutOfBoundsException alloc]
      initWithInt:sb->count_ withInt:start withInt:end - start] autorelease];
}

@implementation JavaLangAbstractStringBuilder

- (IOSCharArray *)getValue {
  return [IOSCharArray arrayWithChars:delegate_.buffer_ count:delegate_.count_];
}

- (void)setWithCharArray:(IOSCharArray *)val
                 withInt:(jint)len {
  if (val == nil) {
    val = LibcoreUtilEmptyArray_get_CHAR();
  }
  if (((IOSCharArray *) nil_chk(val))->size_ < len) {
    @throw [[[JavaIoInvalidObjectException alloc] initWithNSString:@"count out of range"]
        autorelease];
  }
  if (len > delegate_.bufferSize_) {
    free(delegate_.buffer_);
    NewBuffer(&delegate_, len);
  }
  memcpy(delegate_.buffer_, val->buffer_, len * sizeof(jchar));
  delegate_.count_ = len;
}

void JreStringBuilder_initWithCapacity(JreStringBuilder *sb, jint capacity) {
  NewBuffer(sb, capacity);
  sb->count_ = 0;
}

- (instancetype)init {
  JavaLangAbstractStringBuilder_init(self);
  return self;
}

- (instancetype)initWithInt:(jint)capacity {
  JavaLangAbstractStringBuilder_initWithInt_(self, capacity);
  return self;
}

- (instancetype)initWithNSString:(NSString *)string {
  JavaLangAbstractStringBuilder_initWithNSString_(self, string);
  return self;
}

void JavaLangAbstractStringBuilder_init(JavaLangAbstractStringBuilder *self) {
  NewBuffer(&self->delegate_, INITIAL_CAPACITY);
}

void JavaLangAbstractStringBuilder_initWithInt_(
    JavaLangAbstractStringBuilder *self, jint capacity) {
  if (capacity < 0) {
    @throw [[[JavaLangNegativeArraySizeException alloc] initWithNSString:
        JavaLangInteger_toStringWithInt_(capacity)] autorelease];
  }
  NewBuffer(&self->delegate_, capacity);
}

void JavaLangAbstractStringBuilder_initWithNSString_(
    JavaLangAbstractStringBuilder *self, NSString *string) {
  nil_chk(string);
  self->delegate_.count_ = (jint)[string length];
  NewBuffer(&self->delegate_, self->delegate_.count_ + INITIAL_CAPACITY);
  [string getCharacters:self->delegate_.buffer_ range:NSMakeRange(0, self->delegate_.count_)];
}

static void EnlargeBuffer(JreStringBuilder *sb, jint min) {
  jint newSize = MAX(((sb->bufferSize_ >> 1) + sb->bufferSize_) + 2, min);
  sb->buffer_ = (jchar *)realloc(sb->buffer_, newSize * sizeof(jchar));
  if (__builtin_expect(sb->buffer_ == NULL, 0)) {
    OutOfMemory();
  }
  sb->bufferSize_ = newSize;
}

void JreStringBuilder_appendNull(JreStringBuilder *sb) {
  jint newCount = sb->count_ + 4;
  if (newCount > sb->bufferSize_) {
    EnlargeBuffer(sb, newCount);
  }
  jchar *buf = sb->buffer_ + sb->count_;
  *(buf++) = 'n';
  *(buf++) = 'u';
  *(buf++) = 'l';
  *(buf++) = 'l';
  sb->count_ += 4;
}

void JreStringBuilder_appendBuffer(JreStringBuilder *sb, const unichar *buffer, int length) {
  int newCount = sb->count_ + length;
  if (newCount > sb->bufferSize_) {
    EnlargeBuffer(sb, newCount);
  }
  memcpy(sb->buffer_ + sb->count_, buffer, length * sizeof(jchar));
  sb->count_ = newCount;
}

void JreStringBuilder_appendCharArray(JreStringBuilder *sb, IOSCharArray *chars) {
  nil_chk(chars);
  JreStringBuilder_appendBuffer(sb, chars->buffer_, chars->size_);
}

void JreStringBuilder_appendCharArraySubset(
    JreStringBuilder *sb, IOSCharArray *chars, jint offset, jint length) {
  nil_chk(chars);
  JavaUtilArrays_checkOffsetAndCountWithInt_withInt_withInt_(chars->size_, offset, length);
  JreStringBuilder_appendBuffer(sb, chars->buffer_ + offset, length);
}

void JreStringBuilder_appendChar(JreStringBuilder *sb, jchar ch) {
  if (sb->count_ == sb->bufferSize_) {
    EnlargeBuffer(sb, sb->count_ + 1);
  }
  sb->buffer_[sb->count_++] = ch;
}

void JreStringBuilder_appendString(JreStringBuilder *sb, NSString *string) {
  if (string == nil) {
    JreStringBuilder_appendNull(sb);
    return;
  }
  jint length = (jint)CFStringGetLength((CFStringRef)string);
  jint newCount = sb->count_ + length;
  if (newCount > sb->bufferSize_) {
    EnlargeBuffer(sb, newCount);
  }
  CFStringGetCharacters((CFStringRef)string, CFRangeMake(0, length), sb->buffer_ + sb->count_);
  sb->count_ = newCount;
}

void JreStringBuilder_appendCharSequence(
    JreStringBuilder *sb, id<JavaLangCharSequence> s, jint start, jint end) {
  if (s == nil) {
    s = @"null";
  }
  if ((start | end) < 0 || start > end || end > [s length]) {
    @throw [[[JavaLangIndexOutOfBoundsException alloc] init] autorelease];
  }
  jint length = end - start;
  jint newCount = sb->count_ + length;
  if (newCount > sb->bufferSize_) {
    EnlargeBuffer(sb, newCount);
  }
  if ([s isKindOfClass:[NSString class]]) {
    [(NSString *)s getCharacters:sb->buffer_ + sb->count_ range:NSMakeRange(start, end - start)];
  } else if ([s isKindOfClass:[JavaLangAbstractStringBuilder class]]) {
    JavaLangAbstractStringBuilder *other = (JavaLangAbstractStringBuilder *)s;
    memcpy(sb->buffer_ + sb->count_, other->delegate_.buffer_ + start, length * sizeof(jchar));
  } else {
    jint j = sb->count_;
    for (jint i = start; i < end; i++) {
      sb->buffer_[j++] = [s charAtWithInt:i];
    }
  }
  sb->count_ = newCount;
}

- (jint)capacity {
  return delegate_.bufferSize_;
}

- (jchar)charAtWithInt:(jint)index {
  if (index < 0 || index >= delegate_.count_) {
    @throw IndexAndLength(&delegate_, index);
  }
  return delegate_.buffer_[index];
}

void JreStringBuilder_delete(JreStringBuilder *sb, jint start, jint end) {
  if (start >= 0) {
    if (end > sb->count_) {
      end = sb->count_;
    }
    if (end == start) {
      return;
    }
    if (end > start) {
      jint length = sb->count_ - end;
      if (length >= 0) {
        memmove(sb->buffer_ + start, sb->buffer_ + end, length * sizeof(jchar));
      }
      sb->count_ -= end - start;
      return;
    }
  }
  @throw StartEndAndLength(sb, start, end);
}

void JreStringBuilder_deleteCharAt(JreStringBuilder *sb, jint index) {
  if (index < 0 || index >= sb->count_) {
    @throw IndexAndLength(sb, index);
  }
  jint length = sb->count_ - index - 1;
  if (length > 0) {
    memmove(sb->buffer_ + index, sb->buffer_ + index + 1, length * sizeof(jchar));
  }
  sb->count_--;
}

- (void)ensureCapacityWithInt:(jint)min {
  if (min > delegate_.bufferSize_) {
    jint ourMin = delegate_.bufferSize_ * 2 + 2;
    EnlargeBuffer(&delegate_, MAX(ourMin, min));
  }
}

- (void)getCharsWithInt:(jint)start
                withInt:(jint)end
          withCharArray:(IOSCharArray *)dst
                withInt:(jint)dstStart {
  if (start > delegate_.count_ || end > delegate_.count_ || start > end) {
    @throw StartEndAndLength(&delegate_, start, end);
  }
  jint length = end - start;
  IOSArray_checkRange(delegate_.bufferSize_, start, length);
  nil_chk(dst);
  IOSArray_checkRange(dst->size_, dstStart, length);
  memcpy(dst->buffer_ + dstStart, delegate_.buffer_ + start, length * sizeof(jchar));
}

void JreStringBuilder_insertCharArray(JreStringBuilder *sb, jint index, IOSCharArray *chars) {
  if (index < 0 || index > sb->count_) {
    @throw IndexAndLength(sb, index);
  }
  nil_chk(chars);
  if (chars->size_ != 0) {
    JreStringBuilder_move(sb, chars->size_, index);
    memcpy(sb->buffer_ + index, chars->buffer_, chars->size_ * sizeof(jchar));
    sb->count_ += chars->size_;
  }
}

void JreStringBuilder_insertCharArraySubset(
    JreStringBuilder *sb, jint index, IOSCharArray *chars, jint start, jint length) {
  nil_chk(chars);
  if (index >= 0 && index <= sb->count_) {
    if (start >= 0 && length >= 0 && length <= chars->size_ - start) {
      if (length != 0) {
        JreStringBuilder_move(sb, length, index);
        memcpy(sb->buffer_ + index, chars->buffer_ + start, length * sizeof(jchar));
        sb->count_ += length;
      }
      return;
    }
  }
  @throw [[[JavaLangStringIndexOutOfBoundsException alloc] initWithNSString:
      [NSString stringWithFormat:@"this.length=%d; index=%d; chars.length=%d; start=%d; length=%d",
          sb->count_, index, chars->size_, start, length]] autorelease];
}

void JreStringBuilder_insertChar(JreStringBuilder *sb, jint index, jchar ch) {
  if (index < 0 || index > sb->count_) {
    @throw [[[JavaLangArrayIndexOutOfBoundsException alloc]
        initWithInt:sb->count_ withInt:index] autorelease];
  }
  JreStringBuilder_move(sb, 1, index);
  sb->buffer_[index] = ch;
  sb->count_++;
}

void JreStringBuilder_insertString(JreStringBuilder *sb, jint index, NSString *string) {
  if (index >= 0 && index <= sb->count_) {
    if (string == nil) {
      string = @"null";
    }
    jint min = (jint)[string length];
    if (min != 0) {
      JreStringBuilder_move(sb, min, index);
      [string getCharacters:sb->buffer_ + index range:NSMakeRange(0, min)];
      sb->count_ += min;
    }
  } else {
    @throw IndexAndLength(sb, index);
  }
}

void JreStringBuilder_insertCharSequence(
    JreStringBuilder *sb, jint index, id<JavaLangCharSequence> s, jint start,
    jint end) {
  if (s == nil) {
    s = @"null";
  }
  if ((index | start | end) < 0 || index > sb->count_ || start > end
      || end > [s length]) {
    @throw [[[JavaLangIndexOutOfBoundsException alloc] init] autorelease];
  }
  JreStringBuilder_insertString(sb, index, [[s subSequenceFrom:start to:end] description]);
}

- (jint)length {
  return delegate_.count_;
}

void JreStringBuilder_move(JreStringBuilder *sb, jint size, jint index) {
  jint newCount;
  if (sb->bufferSize_ - sb->count_ >= size) {
    memmove(sb->buffer_ + index + size, sb->buffer_ + index,
        (sb->count_ - index) * sizeof(jchar));
    return;
  }
  newCount = MAX(sb->count_ + size, sb->bufferSize_ * 2 + 2);
  jchar *oldBuffer = sb->buffer_;
  NewBuffer(sb, newCount);
  memcpy(sb->buffer_, oldBuffer, index * sizeof(jchar));
  memcpy(sb->buffer_ + index + size, oldBuffer + index, (sb->count_ - index) * sizeof(jchar));
  free(oldBuffer);
}

void JreStringBuilder_replace(JreStringBuilder *sb, jint start, jint end, NSString *string) {
  if (start >= 0) {
    if (end > sb->count_) {
      end = sb->count_;
    }
    if (end > start) {
      nil_chk(string);
      jint stringLength = (jint)[string length];
      jint diff = end - start - stringLength;
      if (diff > 0) {
        memmove(sb->buffer_ + start + stringLength, sb->buffer_ + end,
            (sb->count_ - end) * sizeof(jchar));
      } else if (diff < 0) {
        JreStringBuilder_move(sb, -diff, end);
      }
      [string getCharacters:sb->buffer_ + start range:NSMakeRange(0, stringLength)];
      sb->count_ -= diff;
      return;
    }
    if (start == end) {
      if (string == nil) {
        @throw [[[JavaLangNullPointerException alloc]
            initWithNSString:@"string == null"] autorelease];
      }
      JreStringBuilder_insertString(sb, start, string);
      return;
    }
  }
  @throw StartEndAndLength(sb, start, end);
}

void JreStringBuilder_reverse(JreStringBuilder *sb) {
  if (sb->count_ < 2) {
    return;
  }
  jchar *buf = sb->buffer_;
  jint end = sb->count_ - 1;
  jchar frontHigh = buf[0];
  jchar endLow = buf[end];
  jboolean allowFrontSur = true, allowEndSur = true;
  for (jint i = 0, mid = sb->count_ / 2; i < mid; i++, --end) {
    jchar frontLow = buf[i + 1];
    jchar endHigh = buf[end - 1];
    jboolean surAtFront = allowFrontSur && frontLow >= (jint)0xdc00 && frontLow <= (jint)0xdfff
        && frontHigh >= (jint)0xd800 && frontHigh <= (jint)0xdbff;
    if (surAtFront && (sb->count_ < 3)) {
      return;
    }
    jboolean surAtEnd = allowEndSur && endHigh >= (jint)0xd800 && endHigh <= (jint)0xdbff
        && endLow >= (jint)0xdc00 && endLow <= (jint)0xdfff;
    allowFrontSur = allowEndSur = true;
    if (surAtFront == surAtEnd) {
      if (surAtFront) {
        buf[end] = frontLow;
        buf[end - 1] = frontHigh;
        buf[i] = endHigh;
        buf[i + 1] = endLow;
        frontHigh = buf[i + 2];
        endLow = buf[end - 2];
        i++;
        end--;
      } else {
        buf[end] = frontHigh;
        buf[i] = endLow;
        frontHigh = frontLow;
        endLow = endHigh;
      }
    } else {
      if (surAtFront) {
        buf[end] = frontLow;
        buf[i] = endLow;
        endLow = endHigh;
        allowFrontSur = false;
      } else {
        buf[end] = frontHigh;
        buf[i] = endHigh;
        frontHigh = frontLow;
        allowEndSur = false;
      }
    }
  }
  if ((sb->count_ & 1) == 1 && (!allowFrontSur || !allowEndSur)) {
    buf[end] = allowFrontSur ? endLow : frontHigh;
  }
}

- (void)setCharAtWithInt:(jint)index
                withChar:(jchar)ch {
  if (index < 0 || index >= delegate_.count_) {
    @throw IndexAndLength(&delegate_, index);
  }
  delegate_.buffer_[index] = ch;
}

- (void)setLengthWithInt:(jint)length {
  if (length < 0) {
    @throw [[[JavaLangStringIndexOutOfBoundsException alloc]
        initWithNSString:[NSString stringWithFormat:@"length < 0: %d", length]] autorelease];
  }
  if (length > delegate_.bufferSize_) {
    EnlargeBuffer(&delegate_, length);
  }
  if (delegate_.count_ < length) {
    memset(delegate_.buffer_ + delegate_.count_, 0, (length - delegate_.count_) * sizeof(jchar));
  }
  delegate_.count_ = length;
}

- (NSString *)substringWithInt:(jint)start {
  if (start >= 0 && start <= delegate_.count_) {
    if (start == delegate_.count_) {
      return @"";
    }
    return [NSString stringWithCharacters:delegate_.buffer_ + start
                                   length:delegate_.count_ - start];
  }
  @throw IndexAndLength(&delegate_, start);
}

- (NSString *)substringWithInt:(jint)start
                       withInt:(jint)end {
  if (start >= 0 && start <= end && end <= delegate_.count_) {
    if (start == end) {
      return @"";
    }
    return [NSString stringWithCharacters:delegate_.buffer_ + start length:end - start];
  }
  @throw StartEndAndLength(&delegate_, start, end);
}

- (NSString *)description {
  return JreStringBuilder_toString(&delegate_);
}

NSString *JreStringBuilder_toString(JreStringBuilder *sb) {
  if (sb->count_ == 0) {
    return @"";
  }
  return [NSString stringWithCharacters:sb->buffer_ length:sb->count_];
}

NSString *JreStringBuilder_toStringAndDealloc(JreStringBuilder *sb) {
  if (sb->count_ == 0) {
    free(sb->buffer_);
    return @"";
  }
  NSString *result;
  jint wasted = sb->bufferSize_ - sb->count_;
  // Same test as used by the original AbstractString.java to determine whether
  // to use a shared buffer.
  if (wasted >= 256 || (wasted >= INITIAL_CAPACITY && wasted >= (sb->count_ >> 1))) {
    result = (NSString *)CFStringCreateWithCharacters(NULL, sb->buffer_, sb->count_);
    free(sb->buffer_);
  } else {
    // Don't free the buffer because we're passing it off to the CFString constructor.
    result = (NSString *)CFStringCreateWithCharactersNoCopy(
        NULL, sb->buffer_, sb->count_, kCFAllocatorMalloc);
  }
  return [result autorelease];
}

- (id<JavaLangCharSequence>)subSequenceFrom:(jint)start
                                         to:(jint)end {
  return [self substringWithInt:start withInt:end];
}

- (jint)indexOfWithNSString:(NSString *)string {
  return [self indexOfWithNSString:string withInt:0];
}

- (jint)indexOfWithNSString:(NSString *)subString
                    withInt:(jint)start {
  nil_chk(subString);
  if (start < 0) {
    start = 0;
  }
  jint subCount = (jint)[subString length];
  if (subCount > 0) {
    if (subCount + start > delegate_.count_) {
      return -1;
    }
    jchar firstChar = [subString characterAtIndex:0];
    while (true) {
      jint i = start;
      jboolean found = false;
      for (; i < delegate_.count_; i++) {
        if (delegate_.buffer_[i] == firstChar) {
          found = true;
          break;
        }
      }
      if (!found || subCount + i > delegate_.count_) {
        return -1;
      }
      jint o1 = i, o2 = 0;
      while (++o2 < subCount && delegate_.buffer_[++o1] == [subString characterAtIndex:o2]) {
      }
      if (o2 == subCount) {
        return i;
      }
      start = i + 1;
    }
  }
  return (start < delegate_.count_ || start == 0) ? start : delegate_.count_;
}

- (jint)lastIndexOfWithNSString:(NSString *)string {
  return [self lastIndexOfWithNSString:string withInt:delegate_.count_];
}

- (jint)lastIndexOfWithNSString:(NSString *)subString
                        withInt:(jint)start {
  nil_chk(subString);
  jint subCount = (jint)[subString length];
  if (subCount <= delegate_.count_ && start >= 0) {
    if (subCount > 0) {
      if (start > delegate_.count_ - subCount) {
        start = delegate_.count_ - subCount;
      }
      jchar firstChar = [subString characterAtIndex:0];
      while (true) {
        jint i = start;
        jboolean found = false;
        for (; i >= 0; --i) {
          if (delegate_.buffer_[i] == firstChar) {
            found = true;
            break;
          }
        }
        if (!found) {
          return -1;
        }
        jint o1 = i, o2 = 0;
        while (++o2 < subCount && delegate_.buffer_[++o1] == [subString characterAtIndex:o2]) {
        }
        if (o2 == subCount) {
          return i;
        }
        start = i - 1;
      }
    }
    return start < delegate_.count_ ? start : delegate_.count_;
  }
  return -1;
}

- (void)trimToSize {
  if (delegate_.count_ < delegate_.bufferSize_) {
    jchar *oldBuffer = delegate_.buffer_;
    NewBuffer(&delegate_, delegate_.count_);
    memcpy(delegate_.buffer_, oldBuffer, delegate_.count_ * sizeof(jchar));
    free(oldBuffer);
  }
}

// Defined in Character.java
jint JavaLangCharacter_codePointAtRaw(const jchar *seq, jint index, jint limit);
jint JavaLangCharacter_codePointBeforeRaw(const jchar *seq, jint index, jint start);
jint JavaLangCharacter_codePointCountRaw(const jchar *seq, jint offset, jint count);
jint JavaLangCharacter_offsetByCodePointsRaw(
    const jchar *seq, jint start, jint count, jint index, jint codePointOffset);

- (jint)codePointAtWithInt:(jint)index {
  if (index < 0 || index >= delegate_.count_) {
    @throw IndexAndLength(&delegate_, index);
  }
  return JavaLangCharacter_codePointAtRaw(delegate_.buffer_, index, delegate_.count_);
}

- (jint)codePointBeforeWithInt:(jint)index {
  if (index < 1 || index > delegate_.count_) {
    @throw IndexAndLength(&delegate_, index);
  }
  return JavaLangCharacter_codePointBeforeRaw(delegate_.buffer_, index, 0);
}

- (jint)codePointCountWithInt:(jint)start
                      withInt:(jint)end {
  if (start < 0 || end > delegate_.count_ || start > end) {
    @throw StartEndAndLength(&delegate_, start, end);
  }
  return JavaLangCharacter_codePointCountRaw(delegate_.buffer_, start, end - start);
}

- (jint)offsetByCodePointsWithInt:(jint)index
                          withInt:(jint)codePointOffset {
  return JavaLangCharacter_offsetByCodePointsRaw(
      delegate_.buffer_, 0, delegate_.count_, index, codePointOffset);
}

- (void)dealloc {
  free(delegate_.buffer_);
  [super dealloc];
}

+ (const J2ObjcClassInfo *)__metadata {
  static const J2ObjcMethodInfo methods[] = {
    { "getValue", "[C", 0x10, -1, -1, -1, -1, -1 },
    { "shareValue", "[C", 0x10, -1, -1, -1, -1, -1 },
    { "setWithCharArray:withInt:", "V", 0x10, 0, 1, -1, -1, -1 },
    { "init", NULL, 0x0, -1, -1, -1, -1, -1 },
    { "initWithInt:", NULL, 0x0, -1, -1, -1, -1, -1 },
    { "initWithNSString:", NULL, 0x0, -1, -1, -1, -1, -1 },
    { "appendNull", "V", 0x10, -1, -1, -1, -1, -1 },
    { "append0WithCharArray:", "V", 0x10, 2, -1, -1, -1, -1 },
    { "append0WithCharArray:withInt:withInt:", "V", 0x10, 2, -1, -1, -1, -1 },
    { "append0WithChar:", "V", 0x10, 2, -1, -1, -1, -1 },
    { "append0WithNSString:", "V", 0x10, 2, -1, -1, -1, -1 },
    { "append0WithJavaLangCharSequence:withInt:withInt:", "V", 0x10, 2, -1, -1, -1, -1 },
    { "capacity", "I", 0x1, -1, -1, -1, -1, -1 },
    { "charAtWithInt:", "C", 0x1, 3, -1, -1, -1, -1 },
    { "delete0WithInt:withInt:", "V", 0x10, 4, -1, -1, -1, -1 },
    { "deleteCharAt0WithInt:", "V", 0x10, 5, -1, -1, -1, -1 },
    { "ensureCapacityWithInt:", "V", 0x1, 6, -1, -1, -1, -1 },
    { "getCharsWithInt:withInt:withCharArray:withInt:", "V", 0x1, 7, -1, -1, -1, -1 },
    { "insert0WithInt:withCharArray:", "V", 0x10, 8, -1, -1, -1, -1 },
    { "insert0WithInt:withCharArray:withInt:withInt:", "V", 0x10, 8, -1, -1, -1, -1 },
    { "insert0WithInt:withChar:", "V", 0x10, 8, -1, -1, -1, -1 },
    { "insert0WithInt:withNSString:", "V", 0x10, 8, -1, -1, -1, -1 },
    { "insert0WithInt:withJavaLangCharSequence:withInt:withInt:", "V", 0x10, 8, -1, -1, -1, -1 },
    { "length", "I", 0x1, -1, -1, -1, -1, -1 },
    { "replace0WithInt:withInt:withNSString:", "V", 0x10, 9, -1, -1, -1, -1 },
    { "reverse0", "V", 0x10, -1, -1, -1, -1, -1 },
    { "setCharAtWithInt:withChar:", "V", 0x1, 10, -1, -1, -1, -1 },
    { "setLengthWithInt:", "V", 0x1, 11, -1, -1, -1, -1 },
    { "substringWithInt:", "LNSString", 0x1, 12, -1, -1, -1, -1 },
    { "substringWithInt:withInt:", "LNSString", 0x1, 12, -1, -1, -1, -1 },
    { "description", "LNSString", 0x1, 13, -1, -1, -1, -1 },
    { "toString0", "LNSString", 0x4, -1, -1, -1, -1, -1 },
    { "subSequenceFrom:to:", "LJavaLangCharSequence", 0x1, 14, -1, -1, -1, -1 },
    { "indexOfWithNSString:", "I", 0x1, 15, -1, -1, -1, -1 },
    { "indexOfWithNSString:withInt:", "I", 0x1, 15, -1, -1, -1, -1 },
    { "lastIndexOfWithNSString:", "I", 0x1, 16, -1, -1, -1, -1 },
    { "lastIndexOfWithNSString:withInt:", "I", 0x1, 16, -1, -1, -1, -1 },
    { "trimToSize", "V", 0x1, -1, -1, -1, -1, -1 },
    { "codePointAtWithInt:", "I", 0x1, 17, -1, -1, -1, -1 },
    { "codePointBeforeWithInt:", "I", 0x1, 18, -1, -1, -1, -1 },
    { "codePointCountWithInt:withInt:", "I", 0x1, 19, -1, -1, -1, -1 },
    { "offsetByCodePointsWithInt:withInt:", "I", 0x1, 20, -1, -1, -1, -1 },
  };
  static const J2ObjcFieldInfo fields[] = {
    { "INITIAL_CAPACITY", "I",
      .constantValue.asInt = JavaLangAbstractStringBuilder_INITIAL_CAPACITY, 0x18, -1, -1, -1, -1
    },
  };
  static const void *ptrTable[] = {
    "set", "LJavaIoInvalidObjectException;", "append0", "charAt", "delete0", "deleteCharAt0",
    "ensureCapacity", "getChars", "insert0", "replace0", "setCharAt", "setLength", "substring",
    "toString", "subSequence", "indexOf", "lastIndexOf", "codePointAt", "codePointBefore",
    "codePointCount", "offsetByCodePoints" };
  static const J2ObjcClassInfo _JavaLangAbstractStringBuilder = {
    5, "AbstractStringBuilder", "java.lang", -1, 0x400, 42, methods, 1, fields, -1, NULL, NULL, -1,
    ptrTable };
  return &_JavaLangAbstractStringBuilder;
}

@end
