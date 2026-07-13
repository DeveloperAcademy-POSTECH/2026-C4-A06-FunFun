//
//  VSMMarkerText.h
//  VSMInterface
//
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/** 텍스트 + 스타일 한 세트. (값 객체)
 * 실제 렌더링 혹은 외부 노출용으로 사용합니다.
 */
@interface VSMMarkerText : NSObject

/** 표시할 텍스트
 */
@property (nonatomic, copy, nullable) NSString *text;

/** Fill color - 디폴트: [UIColor blackColor]
 */
@property (nonatomic, strong) UIColor *fillColor;

/** Stroke color - 디폴트: [UIColor whiteColor]
 */
@property (nonatomic, strong) UIColor *strokeColor;

/** Stroke width - 디폴트: 1
 */
@property (nonatomic, assign) CGFloat strokeWidth;

/** Font size - 디폴트: 14
 */
@property (nonatomic, assign) CGFloat fontSize;

/** Text tracking - 디폴트: 0
 */
@property (nonatomic, assign) int32_t textTracking;


/** 전체 필드를 지정하여 생성
 */
- (instancetype)initWithParam:(nullable NSString *)text
                   fillColor:(UIColor *)fillColor
                 strokeColor:(UIColor *)strokeColor
                 strokeWidth:(CGFloat)strokeWidth
                    fontSize:(CGFloat)fontSize
                textTracking:(int32_t)textTracking;

/** 복사 생성자
 */
- (instancetype)initWithMarkerText:(VSMMarkerText *)other;


@end

NS_ASSUME_NONNULL_END
