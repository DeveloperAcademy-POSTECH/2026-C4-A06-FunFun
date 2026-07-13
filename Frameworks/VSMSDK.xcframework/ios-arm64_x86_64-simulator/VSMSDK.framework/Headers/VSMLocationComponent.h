#import <UIKit/UIKit.h>
#import "VSMMarkerLocation.h"

NS_ASSUME_NONNULL_BEGIN

@class VSMMapView;
@class VSMLocation;
@class VSMMarkerLocationIcon;

/**
 * 현위치의 스타일을 변경하기 위한 기능을 제공합니다.
 */
@interface VSMLocationComponent : NSObject

/** 초기화 메소드
 *@param mapView 지도 뷰
 *@see VSMMapView
 */
-(instancetype)initWithMapView:(VSMMapView*)mapView;

/** 내부 ID.
 */
@property (nonatomic, assign, readonly) NSUInteger objectId;

/** touchable - 디폴트:NO
 */
@property (nonatomic, assign) BOOL touchable;

/** 현위치 아이콘을 설정합니다.
 * 마지막으로 icon을 설정하면 즉시 아이콘 소스로 전환되어 기존 3D 모델 표출은 중지됩니다.
 *@see VSMMarkerLocationIcon
 */
@property (nonatomic, strong) VSMMarkerLocationIcon *icon;

/** 현위치 3D 모델을 설정합니다.
 * 마지막으로 object3D를 설정하면 즉시 모델 소스로 전환되어 기존 아이콘 표출은 중지됩니다.
 * `nil`을 설정하면 3D 모델 리소스는 해제되고 모델 소스 상태에서는 아무 것도 표시되지 않습니다.
 */
@property(nonatomic, strong) VSMMarkerLocation3DObject *object3D;

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

/** 현위치 아이콘을 크기를 설정합니다.
 */
@property (nonatomic, assign) CGSize iconSize;

/** 현위치 아이콘 표시 여부를 설정합니다.
 */
@property (nonatomic, assign) BOOL iconVisible;

/**
 * 현위치 마커의 높이(dp단위) 를 설정합니다. 기본값은 0 입니다.
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

/** 현위치 아이콘의 Render 방식을 설정합니다.
 * @see LocationMarkerRenderMode
 */
@property (nonatomic, assign) LocationMarkerRenderMode iconRenderMode;

/** 정확도를 표시하는 원의 표시 여부를 설정합니다.
 */
@property (nonatomic, assign) BOOL accuracyVisible;

/** 정확도를 표시하는 원의 fill 색상을 설정합니다.
 */
@property (nonatomic, strong) UIColor *accuracyFillColor;

/** 정확도를 표시하는 원의 stroke 색상을 설정합니다.
 */
@property (nonatomic, strong) UIColor *accuracyStrokeColor;

/** 정확도를 표시하는 원의 stroke 두께를 설정합니다.
 */
@property (nonatomic, assign) float accuracyStrokeWidth;

/** Internal Use Only
 */
-(void)updateLocation:(VSMLocation*)location;

/** Internal Use Only
*/
-(void)destroy;

/**
 * 3D 모델의 특정 Mesh에 임의 설정값을 적용합니다. @link VSMMarker3DObjectMeshProperty}
 */
- (void)setObject3DMeshProperty:(VSMMarker3DObjectMeshProperty *)object3DMeshProperty;

- (void)setObject3DMeshProperties:(NSArray<VSMMarker3DObjectMeshProperty *> *)props;

/**
 * 3D 모델 애니메이션 클립 배열을 설정합니다.
 * nil 또는 빈 배열이면 애니메이션이 해제됩니다.
 */
- (void)set3DModelAnimation:(nullable NSArray<VSMMarker3DAnimationClip*> *)animationClips;

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
 * 3D Model의 전체 밝기를 반환합니다. 기본값 1.0
 */
@property (nonatomic, assign, readonly) float object3DBrightness;

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
 * 3D Model 관련 렌더링 옵션을 초기화합니다.
 * 초기화 대상: brightness(1.0), saturation(1.0), shadow(NO, 0.1),
 * modelSize(0), altitude(0), headlight(off), taillight(off), signalLight(OFF),
 * meshProperty(전체), animation(nil)
 */
- (void)clear3DModelRenderOptions;

@end

NS_ASSUME_NONNULL_END
