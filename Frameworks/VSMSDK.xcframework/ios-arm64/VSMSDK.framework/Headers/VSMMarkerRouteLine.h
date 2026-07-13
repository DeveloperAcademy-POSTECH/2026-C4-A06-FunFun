#import "VSMMarkerBase.h"
#import "MarkerImage.h"

NS_ASSUME_NONNULL_BEGIN

@class UIColor;
@class UIImage;

typedef NS_ENUM(NSInteger, RouteLineMarkerLineType)
{   /**
     * 일반 라인
     */
    RouteLineMarkerLineType_Line = 0,
    /**
     * 도트(점선) 라인
     */
    RouteLineMarkerLineType_Dot = 1
};

/**
 * 경로선 방향 지시자 렌더링 스타일 속성입니다.
 */
@interface VSMRouteDirectionIndicatorStyle : NSObject
/** size - 유효범위: 0이상 디폴트: 9
 * 방향 지시자 아이콘 사이즈
 */
@property (nonatomic, assign) float size;

/** interval - 유효범위: 0이상 디폴트: 36
 * 방향 지시자 등장 주기
 */
@property (nonatomic, assign) float interval;

/** alpha - 유효범위:0~1 디폴트: 0.8
 */
@property (nonatomic, assign) float alpha;

/** image
 * 방향 지시자 아이콘 이미지
 */
@property (nonatomic, strong) MarkerImage* image;

@property (nonatomic, strong) NSArray<MarkerImage*>* congestionImages;

@end


/**
 * 경로선 렌더링 스타일 속성입니다.
 */
@interface VSMRouteLineStyle : NSObject

/**
 * 경로선 선형 타입. 디폴트 : RouteLineMarkerLineType_Line(0)
 */
@property (nonatomic, assign) RouteLineMarkerLineType lineType;

/** width - 유효범위: 0이상 디폴트: 9(dp)
 * 경로선 너비
 */
@property (nonatomic, assign) float width;

/**
 * 경로 내부선 너비 - 유효범위:0이상 디폴트:0(dp)
 * 본선 너비를 초과할 수 없습니다.
 */
@property (nonatomic, assign) float innerLinewidth;

/** outlineWidth - 유효범위: 0이상 디폴트: 2(dp)
 * 경로 외곽선 너비
 */
@property (nonatomic, assign) float outlineWidth;

/** height 디폴트: 0(dp)
 * 경로 높이
 * 경로 높이가 0보다 클 경우 trunArrow는 경로선과 같은 높이로 그려지며, 0인경우 turnArrow는 기본 높이(10.0dp)로 그려짐.
 */
@property (nonatomic, assign) float height;

/**
 * Line type이 pattern 타입인 경우, 패턴간 빈공간 간격. (dp 단위)
 */
@property (nonatomic, assign) float patternGap;

/** colorBasic - 디폴트: 0xff1e5e94
 * 경로선 색
 */
@property (nonatomic, strong) UIColor* colorBasic;

/** colorPassed - 디폴트: 0xff747474
 * 지나온 경로선 색 (현재 prgress보다 작은 범위 적용)
 */
@property (nonatomic, strong) UIColor* colorPassed;

/** colorCongestion - 디폴트: (0xff464646, 0xff0c753d, 0xff9f5804, 0xff823a2f) (NO, GOOD, SLOW,BAD)
 */
@property (nonatomic, strong) NSArray<UIColor*>* colorCongestion;   // 0: no data, 1: good, 2: slow, 3: bad

/** colorBasic - 디폴트: 0xff1e5e94
 * 경로 내부선 색상
 */
@property (nonatomic, strong) UIColor* innerLineColorBasic;

/** colorPassed - 디폴트: 0xff747474
 * 지나온 경로 내부선 색상 색 (현재 prgress보다 작은 범위 적용)
 */
@property (nonatomic, strong) UIColor* innerLineColorPassed;

/** colorCongestion - 디폴트: (0xff464646, 0xff0c753d, 0xff9f5804, 0xff823a2f) (NO, GOOD, SLOW,BAD)
 *  교통정보 반영된 경로 내부선 색상
 */
@property (nonatomic, strong) NSArray<UIColor*>* innerLineColorCongestion;   // 0: no data, 1: good, 2: slow, 3: bad

/** outlineColorBasic - 디폴트: (0xff1e5e94)
 * 외곽선 색
 */
@property (nonatomic, strong) UIColor* outlineColorBasic;

/** outlineColorPassed - 디폴트: (0xff747474)
 * 지나온 경로 와곽선 색 (현재 prgress보다 작은 범위 적용)
 */
@property (nonatomic, strong) UIColor* outlineColorPassed;

/** outlineColorCongestion - 디폴트: (0xff464646, 0xff0c753d, 0xff9f5804, 0xff823a2f) (NO, GOOD, SLOW,BAD)
 */
@property (nonatomic, strong) NSArray<UIColor*>* outlineColorCongestion;   // 0: no data, 1: good, 2: slow, 3: bad

/** oppositeColor - 디폴트: 0xffc6c6c6
 */
@property (nonatomic, strong) UIColor* oppositeColor;

/** oppositeColor - 디폴트: 0xffc6c6c6
 */
@property (nonatomic, strong) UIColor* oppositeInnerLineColor;

/** oppositeOutlineColor - 디폴트: 0xff737573
 */
@property (nonatomic, strong) UIColor* oppositeOutlineColor;

/** glow 효과 여부 - 디폴트: NO
 */
@property (nonatomic, assign) bool hasGlowEffect;

/** gradient 효과 여부 - 디폴트: NO
 */
@property (nonatomic, assign) bool hasGradientEffect;

/** 방향 지시자 스타일 파라미터
 */
@property (nonatomic, strong) VSMRouteDirectionIndicatorStyle* directionIndicatorStyle;

@end

/**
 * 경로선 회전 지점 화살표 렌더링 스타일 속성입니다.
 */
@interface VSMRouteTurnArrowStyle : NSObject
/** width - 유효범위: 0이상  디폴트:9
 */
@property (nonatomic, assign) float width;
/** outlineWidth - 유효범위: 0이상  디폴트:2
 */
@property (nonatomic, assign) float outlineWidth;
/** length - 유효범위: 0이상  디폴트:44
 */
@property (nonatomic, assign) float length;
/** headSize - 유효범위: 0이상  디폴트:11
 */
@property (nonatomic, assign) float headSize;

/** color - 디폴트: 0xffffffff
 */
@property (nonatomic, strong) UIColor* color;

/** outlineColor - 디폴트: 0xff787878
 */
@property (nonatomic, strong) UIColor* outlineColor;

/** maxCountShow - 디폴트: -1
 */
@property (nonatomic, assign) int32_t maxCountShow;

@end

/**
 * 안내점 렌더링 스타일 속성입니다.
 */
@interface VSMRouteManeuverStyle : NSObject
/** size - 디폴트: -1
 * 안내점 아이콘 사이즈
 */
@property (nonatomic, assign) float width;

/** size - 디폴트: -1
 * 안내점 아이콘 사이즈
 */
@property (nonatomic, assign) float height;

/** image
 * 안내점아이콘 이미지
 */
@property (nonatomic, strong) MarkerImage* image;

@end

/**
 * 경로선 마커 초기화를 위한 파라미터
 */
@interface VSMMarkerRouteLineParams : VSMMarkerBaseParams

/**
 * 경로선 바이너리 데이터
 */
@property (nonatomic, strong) NSData* routeData;

/** showTurnArrow - 디폴트: YES
  * 회전 지점 화살표 표출 여부
 */
@property (nonatomic, assign) BOOL showTurnArrow;

/** showManeuver - 디폴트: NO
  * 안내점 표출 여부
 */
@property (nonatomic, assign) BOOL showManeuver;

/** showDirectionIndicator - 디폴트: YES
 * 방향 지시자 표출 여부
 */
@property (nonatomic, assign) BOOL showDirectionIndicator;

/** showTraffic - 디폴트: NO
 * 교통 정보 표출 여부
 */
@property (nonatomic, assign) BOOL showTraffic;

/** progress - 디폴트: 0
 * 시작지부터 목적지 까지의 진행도 (0~100)
 */
@property (nonatomic, assign) float progress;

/** 경로선 스타일 파라미터
 */
@property (nonatomic, strong) VSMRouteLineStyle* lineStyle;

/**
 * 경로 데이터의 특정 link 전용 스타일을 설정합니다.
 *
 * 기본 경로 선형의 styleId {@link MarkerConstants#MARKER_ROUTELINE_STYLE_ID_DEFAULT} 와 다른 값을 사용해야 합니다.
 * width, outlineWidth, height 는 기본 경로 선형의 LineStyle({@link MarkerConstants#MARKER_ROUTELINE_STYLE_ID_DEFAULT} 을 사용합니다.
 */
@property (nonatomic, strong) NSDictionary<NSNumber*, VSMRouteLineStyle*> *additionalLineStyle;

/** 회전 지점 화살표 스타일 파라미터
 */
@property (nonatomic, strong) VSMRouteTurnArrowStyle* turnArrowStyle;

/** 안내점 스타일 파라미터. 스타일의 개수만큼 경로상에 표현됨
 * @see VSMRouteTurnArrowStyle
 */
@property (nonatomic, strong) NSArray<VSMRouteManeuverStyle*>* maneuverPointStyles;


/** @deprecated {#{@link VSMRouteLineStyle}} 통해 설정 하도록 변경되었습니다.
 * 방향 지시자 스타일 파라미터
 */
@property (nonatomic, strong) VSMRouteDirectionIndicatorStyle* directionIndicatorStyle;

/** oppositeOutlineColor - 디폴트: 0x66000000
 */
@property (nonatomic, strong) UIColor* shadowColor;

@end

/**
 * 경로선 마커(오버레이)입니다.
 * 지도 위에 경로선을 그립니다.
 */
@interface VSMMarkerRouteLine : VSMMarkerBase

/** showTurnArrow
 * 회전 지점 화살표 표출 여부
 */
@property (nonatomic, assign) BOOL showTurnArrow;

/** showManeuver
 * 안내점 표출 여부
 */
@property (nonatomic, assign) BOOL showManeuver;

/** showDirectionIndicator
 * 방향 지시자 표출 여부
 */
@property (nonatomic, assign) BOOL showDirectionIndicator;

/** showTraffic
 * 교통 정보 표출 여부
 */
@property (nonatomic, assign) BOOL showTraffic;

/** progress
 * 시작지부터 목적지 까지의 진행도 (0~100)
 */
@property (nonatomic, assign) float progress;

/** 경로선 스타일 파라미터
 * @see VSMRouteLineStyle
 */
@property (nonatomic, strong) VSMRouteLineStyle* lineStyle;

/** 회전 지점 화살표 스타일 파라미터
 * @see VSMRouteTurnArrowStyle
 */
@property (nonatomic, strong) VSMRouteTurnArrowStyle* turnArrowStyle;

/** 안내점 스타일 파라미터. 스타일의 개수만큼 경로상에 표현됨
 * @see VSMRouteTurnArrowStyle
 */
@property (nonatomic, strong) NSArray<VSMRouteManeuverStyle*>* maneuverPointStyles;

/** @deprecated. {#{@link VSMRouteLineStyle}} 통해 설정 하도록 변경되었습니다.
 * 방향 지시자 스타일 파라미터
 * @see VSMRouteDirectionIndicatorStyle
 */
@property (nonatomic, strong) VSMRouteDirectionIndicatorStyle* directionIndicatorStyle;

/** oppositeOutlineColor - 디폴트: 0x66000000
 */
@property (nonatomic, strong) UIColor* shadowColor;

/**
 * 초기화 메소드
 * @param markerID 마커ID. 삭제/제어시 필요합니다.
 * @param params 초기화 파라미터
 * @see VSMMarkerRouteLineParams
 */
- (instancetype)initWithID:(NSString*)markerID params:(VSMMarkerRouteLineParams *)params;

/**
 * 경로 정보 설정
 * @param routeData 경로 바이너리 데이터
 */
- (void)setRouteData:(NSData *)routeData;

/**
 * 경로 데이터의 특정 link 전용 스타일을 설정합니다.
 *
 * 기본 경로 선형의 styleId {@link MarkerConstants#MARKER_ROUTELINE_STYLE_ID_DEFAULT} 와 다른 값을 사용해야 합니다.
 * width, outlineWidth, height 는 기본 경로 선형의 LineStyle({@link MarkerConstants#MARKER_ROUTELINE_STYLE_ID_DEFAULT} 을 사용합니다.
 *
 * @param styleId   경로 link data의 styleId{@link LinkInfo#styleId()}
 * @param lineStyle
 */
-(void)setAdditionalLineStyle:(VSMRouteLineStyle *)lineStyle styleId:(short)styleId;

-(void)removeAdditionalLineStyle:(short)styleId;

@end

NS_ASSUME_NONNULL_END
