#import <UIKit/UIKit.h>
#import <simd/simd.h>
#import "VSMMarkerBase.h"
#import "VSMMarkerPolyline.h"
#import "MarkerImage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * 로케이션 마커 렌더 모드
 */
typedef NS_ENUM(NSInteger, LocationMarkerRenderMode)
{   /**
     * 그라운드
     */
    LocationMarkerRenderMode_Ground = 0,
    /**
     * 빌보드
     */
    LocationMarkerRenderMode_Billboard = 1
};

typedef NS_ENUM(NSInteger, VSMSignalLightType) {
    VSMSignalLightTypeOff    = 0,  // 모든 방향지시등 끔
    VSMSignalLightTypeLeft   = 1,  // 좌측
    VSMSignalLightTypeRight  = 2,  // 우측
    VSMSignalLightTypeHazard = 3,  // 비상등(좌/우 동시)
};

typedef NS_ENUM(NSInteger, VSMMarker3DObjectSourceType) {
    VSMMarker3DObjectSourceTypeResourceRef = 0,
    VSMMarker3DObjectSourceTypeFilePath = 1,
    VSMMarker3DObjectSourceTypeGLBData = 2,
};

/**
 * 3D 애니메이션 재생 상태
 */
typedef NS_ENUM(NSInteger, VSMMarker3DAnimationPlayState) {
    VSMMarker3DAnimationPlayStatePause = 0,
    VSMMarker3DAnimationPlayStateResume = 1,
};

/**
 * 3D 애니메이션 반복 모드
 */
typedef NS_ENUM(NSInteger, VSMMarker3DAnimationRepeatMode) {
    VSMMarker3DAnimationRepeatModeOnce = 0,
    VSMMarker3DAnimationRepeatModeLoop = 1,
};

/**
 * 3D 모델 애니메이션 클립 제어 정보
 */
@interface VSMMarker3DAnimationClip : NSObject<NSCopying>

/**
 * 제어 대상 클립 이름.
 * 비어있거나 매칭 실패 시 clipIndex를 fallback으로 사용합니다.
 */
@property (nonatomic, copy, nullable) NSString *clipName;

/**
 * 제어 대상 클립 인덱스 (0-based). 기본값: -1
 */
@property (nonatomic, assign) NSInteger clipIndex;

/**
 * 재생 상태. 기본값: Resume
 */
@property (nonatomic, assign) VSMMarker3DAnimationPlayState playState;

/**
 * 반복 모드. 기본값: Loop
 */
@property (nonatomic, assign) VSMMarker3DAnimationRepeatMode repeatMode;

/**
 * 재생 속도 배율. 기본값: 1.0
 */
@property (nonatomic, assign) float speed;

/**
 * 블렌딩 가중치(영향도). 기본값: 1.0
 */
@property (nonatomic, assign) float weight;

- (instancetype)initWithClipName:(nullable NSString *)clipName
                       clipIndex:(NSInteger)clipIndex
                       playState:(VSMMarker3DAnimationPlayState)playState
                      repeatMode:(VSMMarker3DAnimationRepeatMode)repeatMode
                           speed:(float)speed
                          weight:(float)weight NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithClipName:(nullable NSString *)clipName
                       clipIndex:(NSInteger)clipIndex
                          weight:(float)weight;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end


@class VSMMapPoint;


/**
 * 3D 위치 마커를 위한 파라미터에 사용되는 경로 정보입니다.
 */
@interface VSMMarkerLocation3DObjectResourceInfo : NSObject
/**
 * 3D 위치 마커를 위한 파라미터에 사용되는 경로 정보 팩토리 메소드
 * @param packageCode 서버상의 패키지 코드
 * @param resourceCode 서버상의 리소스 코드
 */
+ (instancetype)location3DObjectResourceInfoWithPackageCode:(nonnull NSString*)packageCode
                                               resourceCode:(nonnull NSString*)resourceCode;
@end



/**
 * 3D 위치 마커를 위한 파라미터입니다.
 */
@interface VSMMarkerLocation3DObject : NSObject

/** 3D 모델 소스 타입. 기본값: ResourceRef
 */
@property (nonatomic, assign) VSMMarker3DObjectSourceType sourceType;

/** 패키지 코드. 서버로 부터 내려 받을 패키지/리소스 코드 정보입니다.
 * @see VSMMarkerLocation3DObjectResourceCode
 */
@property (nonatomic, strong, nullable) VSMMarkerLocation3DObjectResourceInfo* resourceInfo;

/** 로컬 파일 기반 3D 모델 절대 경로 (Optional)
 */
@property (nonatomic, copy, nullable) NSString* filePath;

/** raw GLB binary data (Optional)
 */
@property (nonatomic, copy, nullable) NSData* glbData;

/** 부가 텍스처 (Optional)
 */
@property (nonatomic, strong, nullable) NSString* optionalTexturePath;

+ (instancetype)objectWithResourceInfo:(VSMMarkerLocation3DObjectResourceInfo *)resourceInfo;

+ (instancetype)objectWithFilePath:(NSString *)filePath;

+ (instancetype)objectWithGLBData:(NSData *)glbData;

@end

@interface VSMMarker3DObjectMeshProperty : NSObject

/**
 * mesh name
 */
@property (nonatomic, copy, readonly) NSString *meshName;

/**
 * mesh 기본 색상 ARGB 32bit. 기본값은 null 이며, mesh 데이터 원본 색상으로 표출합니다.
 * api 로 색상 명시할 경우, 해당 색상으로 표출합니다.
 */
@property (nonatomic, strong, nullable)  UIColor* baseColor;

/*
 * mesh 표출 여부. 기본값은 true 입니다.
 */
@property (nonatomic, assign) BOOL visible;

/*
 * mesh touch 가능 여부. 기본값은 true 입니다.
 */
@property (nonatomic, assign) BOOL touchable;

- (instancetype)initWithMeshName:(NSString *)meshName NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithProperty:(VSMMarker3DObjectMeshProperty *)other;
- (instancetype)init       NS_UNAVAILABLE;
+ (instancetype)new         NS_UNAVAILABLE;

@end


/** 위치 마커 아이콘
 */
@interface VSMMarkerLocationIcon : NSObject

/** Icon
 *@see MarkerImage
 */
@property (nonatomic, strong, nullable) MarkerImage* icon;

/** Icon3D
 *@see MarkerImage
 */
@property (nonatomic, strong, nullable) MarkerImage* icon3D;

@end

/**
 * 위치 가이드 라인 스타일
 */
@interface VSMMarkerLocationGuideStyle : NSObject

/** fillColor - 디폴트: blueColor
 * 색상
 */
@property (nonatomic, strong) UIColor* fillColor;

/** strokeColor - 디폴트: clearColor
 * 테두리 색상
 */
@property (nonatomic, strong) UIColor* strokeColor;

/** width - 디폴트: 1
 */
@property (nonatomic, assign) float width;

/** strokeWidth - 디폴트: 0
 */
@property (nonatomic, assign) float strokeWidth;

/** lineDash 디폴트
 *   lineDash.lineDash1 = 5
 *   lineDash.lineDash2 = 5
 *   lineDash.lineDash3 = 5
 *   lineDash.lineDash4 = 5
 *
 *   @see LineDashStyleData
 */
@property (nonatomic, copy) LineDashStyleData* lineDash;

@end

/**
 * 위치 마커 파라미터
 */
@interface VSMMarkerLocationParams : VSMMarkerBaseParams

/** Position (WGS84)
 * @see VSMMapPoint
 */
@property (nonatomic, strong) VSMMapPoint* position;

/** Icon
 * 마지막으로 Icon을 설정하면 즉시 아이콘 소스로 전환되어 기존 3D 모델 표출은 중지됩니다.
 * @see VSMMarkerLocationIcon
 */
@property (nonatomic, strong) VSMMarkerLocationIcon* icon;


/** RenderMode 디폴트값:LocationMarkerRenderMode_Ground
 * @see LocationMarkerRenderMode
 */
@property (nonatomic, assign) LocationMarkerRenderMode renderMode;

/** IconSize - 디폴트:(0, 0)
 */
@property (nonatomic, assign) CGSize iconSize;

/** bearing - 디폴트: 0
 * 회전 각(Degree)
 */
@property (nonatomic, assign) float bearing;

/**
 * 높이(dp) - 디폴트: 0
 */
@property (nonatomic, assign) float altitude;

/**
 * 3D 모델의 화면 표시 크기(dp)를 설정합니다. 모델 로컬 AABB(x,y,z)의 최장변 길이가 지정한 dp 크기로 보이도록 균등 스케일을 적용합니다.
 * 기본값은 0 으로 3D 모델의 원본사이즈로 표출합니다.
 * @param size
 * @return
 */
@property (nonatomic, assign) float object3DSize;

/**
 * 3D 모델 지면 그림자 활성화 여부. 기본값 NO
 */
@property (nonatomic, assign) BOOL object3DShadowEnabled;

/**
 * 3D 모델 지면 그림자 알파값. 0.0 ~ 1.0, 기본값 0.1
 */
@property (nonatomic, assign) float object3DShadowAlpha;


/**
 * 마커의 Anchor를 설정합니다.
 * @param x x 축 정규화 좌표. 기본값 : 0.5
 * @param y y 축 정규화 좌표. 기본값 : 0.5
 * @param z z 축 정규화 좌표. 기본값 : 0.0 (3D model 에 적용)
 * @return
 */
@property (nonatomic, assign) simd_float3 anchor;

/** showGuide - 디폴트:NO
 * 현위치가 지도 밖으로 벗어나는 경우 가이드선 출력 여부.
 */
@property (nonatomic, assign) BOOL showGuide;

/** 가이드 선 스타일
 * @see VSMMarkerLocationGuideStyle
 */
@property (nonatomic, strong) VSMMarkerLocationGuideStyle* guideStyle;

/** 3D 모델 정보
 * 마지막으로 3D 모델을 설정하면 즉시 모델 소스로 전환되어 기존 아이콘 표출은 중지됩니다.
 * `nil`을 설정하면 3D 모델 리소스는 해제되고 모델 소스 상태에서는 아무 것도 표시되지 않습니다.
 * @see VSMMarkerLocation3DObject
 */
@property (nonatomic, strong) VSMMarkerLocation3DObject* object3D;

/**
 * @depreacted VSMMarker3DObjectMeshProperty 로 대체
 * 3D 모델 중 표시하지 않을 Mesh 목록
 */
@property (nonatomic, nonatomic) NSArray<NSString*>* object3DFilterOut;

/**
 * @depreacted VSMMarker3DObjectMeshProperty 로 대체
 * 3D 모델 중 Hit영역에 포함되지 않을 Mesh 목록
 */
@property (nonatomic, nonatomic) NSArray<NSString*>* object3DHitBoundsFilterOut;

@property (nonatomic, nonatomic) NSMutableArray<VSMMarker3DObjectMeshProperty*> *object3DMeshProperty;

/**
 * 3D Model의 전체 밝기를 조절합니다. 기본값 1.0
 */
@property (nonatomic, assign) float object3DBrightness;

/**
 * 3D Model의 전체 표면 색상 채도. 1.0은 원본 채도, 0.0은 완전 무채색이며 기본값은 1.0
 */
@property (nonatomic, assign) float object3DSaturation;

@end

/** 위치 마커(오버레이) 클래스
 * 지도위에 현재 위치한 지점을 2D/3D모형으로 표출합니다.
 */
@interface VSMMarkerLocation : VSMMarkerBase

/** Position (WGS84)
 * @see VSMMapPoint
 */
@property (nonatomic, strong) VSMMapPoint* position;

/** Icon
 * 마지막으로 Icon을 설정하면 즉시 아이콘 소스로 전환되어 기존 3D 모델 표출은 중지됩니다.
 *@see VSMMarkerLocationIcon
 */
@property (nonatomic, strong) VSMMarkerLocationIcon* icon;


/**  3D 모델
 * 마지막으로 3D 모델을 설정하면 즉시 모델 소스로 전환되어 기존 아이콘 표출은 중지됩니다.
 * `nil`을 설정하면 3D 모델 리소스는 해제되고 모델 소스 상태에서는 아무 것도 표시되지 않습니다.
 * @see VSMMarkerLocation3DObject
 */
@property (nonatomic, strong) VSMMarkerLocation3DObject* object3D;

/**
 * @depreacted VSMMarker3DObjectMeshProperty 로 대체
 * 3D 모델 중 표시하지 않을 Mesh 목록
 */
@property (nonatomic, nonatomic) NSArray<NSString*>* object3DFilterOut;

/**
 * @depreacted VSMMarker3DObjectMeshProperty 로 대체
 * 3D 모델 중 Hit영역에서 제외 될  Mesh 목록
 */
@property (nonatomic, nonatomic) NSArray<NSString*>* object3DHitBoundsFilterOut;

/** RenderMode 디폴트값:LocationMarkerRenderMode_Ground
 * @see LocationMarkerRenderMode
 */
@property (nonatomic, assign) LocationMarkerRenderMode renderMode;

/** Icon Width/Height
 */
@property (nonatomic, assign) CGSize iconSize;

/** bearing
 * 회전 각(Degree)
 */
@property (nonatomic, assign) float bearing;

/**
 * 높이(dp)
 */
@property (nonatomic, assign) float altitude;

/**
 * 3D 모델의 화면 표시 크기(dp)를 설정합니다. 모델 로컬 AABB(x,y,z)의 최장변 길이가 지정한 dp 크기로 보이도록 균등 스케일을 적용합니다.
 * 기본값은 0 으로 3D 모델의 원본사이즈로 표출합니다.
 * @param size
 * @return
 */
@property (nonatomic, assign) float object3DSize;

/**
 * 마커의 Anchor를 설정합니다.
 * @param x x 축 정규화 좌표. 기본값 : 0.5
 * @param y y 축 정규화 좌표. 기본값 : 0.5
 * @param z z 축 정규화 좌표. 기본값 : 0.0 (3D model 에 적용)
 * @return
 */
@property (nonatomic, assign) simd_float3 anchor;

/** showGuide
 * 현위치가 지도 밖으로 벗어나는 경우 가이드선 출력 여부.
 */
@property (nonatomic, assign) BOOL showGuide;

/** 가이드 선 스타일
 *@see VSMMarkerLocationGuideStyle
 */
@property (nonatomic, strong) VSMMarkerLocationGuideStyle* guideStyle;

/**
 * 3D Model의 전체 밝기를 조절합니다. 기본값 1.0
 */
@property (nonatomic, assign) float object3DBrightness;

/**
 * 3D Model의 전체 표면 색상 채도. 1.0은 원본 채도, 0.0은 완전 무채색이며 기본값은 1.0
 */
@property (nonatomic, assign, readonly) float object3DSaturation;

/**
 * 3D 모델 지면 그림자 활성화 여부. 기본값 NO
 */
@property (nonatomic, assign, readonly) BOOL object3DShadowEnabled;

/**
 * 3D 모델 지면 그림자 알파값. 0.0 ~ 1.0, 기본값 0.1
 */
@property (nonatomic, assign, readonly) float object3DShadowAlpha;

/**
 * 현재 설정된 3D 모델 애니메이션 클립 배열. 설정되지 않은 경우 nil.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<VSMMarker3DAnimationClip*> *object3DAnimation;

/**
 * 3D 모델에 설정된 MeshProperty 목록을 반환합니다.
 */
- (NSDictionary<NSString*, VSMMarker3DObjectMeshProperty*> *)object3DMeshPropertyMap;

/** 초기화 메소드
 * @param markerID 마커ID. 삭제/제어시 필요합니다.
 * @param params 초기화 파라미터
 * @see VSMMarkerLocationParams
 */
- (id)initWithID:(NSString*)markerID params:(VSMMarkerLocationParams*)params;

/**
 * 3D 모델의 특정 Mesh에 임의 설정값을 적용합니다. @link VSMMarker3DObjectMeshProperty}
 */
- (void)setObject3DMeshProperty:(VSMMarker3DObjectMeshProperty *)object3DMeshProperty;

- (void)setObject3DMeshProperties:(NSArray<VSMMarker3DObjectMeshProperty *> *)props;

/**
 * 3D 카바타 전조등(헤드라이트) 조명을 설정합니다.
 * 스펙(https://tmobi.atlassian.net/wiki/spaces/VSMREL/pages/1431405197/TMAP+3D+Carvatar)에 정의된 3D model 데이터에만 적용됩니다.
 * @param enabled   조명 활성화 여부
 * @param lightColor  조명 색상
 * @param intensity 조명 퍼짐 강도(기본:1.0)
 */
- (void)set3DModelHeadlight:(BOOL)enabled
                        lightColor:(UIColor*)lightColor
                         intensity:(float)intensity;

/**
 * 후미등 조명을 설정합니다.
 * 스펙(https://tmobi.atlassian.net/wiki/spaces/VSMREL/pages/1431405197/TMAP+3D+Carvatar)에 정의된 3D model 데이터에만 적용됩니다.
 * @param enabled   조명 활성화 여부
 * @param lightColor  조명 색상
 * @param intensity 조명 퍼짐 강도(기본:1.0)
 */
- (void)set3DModelTaillight:(BOOL)enabled
                        lightColor:(UIColor*)lightColor
                         intensity:(float)intensity;

/**
 * 3D 카바타 방향지시등의 점등/점멸 상태를 설정합니다.
 * <b>우선순위</b>: Hazard 활성화 시 좌/우 설정은 무시됩니다.
 *
 * @param type           방향지시등 타입
 * @param lightColor      색상.
 * @param frontIntensity 전방 퍼짐 강도(기본:1.0)
 * @param rearIntensity  후방 퍼짐. 강도(기본:1.0)
 * @param periodMS       깜빡임 주기(ms). 0이면 항상 점등
 */
- (void)set3DModelSignalLight:(VSMSignalLightType)type
                    lightColor:(UIColor*)lightColor
               frontIntensity:(float)frontIntensity
                rearIntensity:(float)rearIntensity
                     periodMS:(NSInteger)periodMS;

/**
 * 3D Model의 전체 밝기를 조절합니다. 기본값 1.0
 */
- (void)set3DModelBrightness:(float)brightness;

/**
 * 3D Model의 전체 표면 색상 채도를 조절합니다. 1.0은 원본 채도, 0.0은 완전 무채색이며 기본값은 1.0 입니다.
 */
- (void)set3DModelSaturation:(float)saturation;

/**
 * 3D 모델의 지면 그림자 활성화 여부와 알파값을 함께 설정합니다.
 * alpha는 0.0 ~ 1.0 범위로 적용됩니다. 기본값은 enabled=NO, alpha=0.1 입니다.
 */
- (void)set3DModelShadow:(BOOL)enabled alpha:(float)alpha;

/**
 * 3D 모델 애니메이션 클립 배열을 설정합니다.
 * nil 또는 빈 배열이면 애니메이션이 해제됩니다.
 */
- (void)set3DModelAnimation:(nullable NSArray<VSMMarker3DAnimationClip*> *)animationClips;

/**
 * 3D Model 관련 렌더링 옵션을 초기화합니다.
 * 초기화 대상: brightness(1.0), saturation(1.0), shadow(NO, 0.1),
 * modelSize(0), altitude(0), headlight(off), taillight(off), signalLight(OFF),
 * meshProperty(전체), animation(nil)
 */
- (void)clear3DModelRenderOptions;

@end
NS_ASSUME_NONNULL_END
