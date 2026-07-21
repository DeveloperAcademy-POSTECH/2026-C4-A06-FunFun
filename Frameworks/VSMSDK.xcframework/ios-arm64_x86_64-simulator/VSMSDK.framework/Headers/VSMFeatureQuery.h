//
//  VSMFeatureQuery.h
//  VSMSDK
//
//  Feature Query API for iOS
//

#import <Foundation/Foundation.h>
#import "VSMMapViewDefine.h"

@class VSMMapPoint;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Enums

/**
 * Feature의 지오메트리 타입
 */
typedef NS_ENUM(NSInteger, VSMFeatureGeometryType) {
    /** 점 (POI 등) */
    VSMFeatureGeometryTypePoint = 0,
    /** 선 (도로 등) */
    VSMFeatureGeometryTypePolyline = 1,
    /** 면 (건물 등) */
    VSMFeatureGeometryTypePolygon = 2
};

#pragma mark - VSMFeatureInfo

/**
 * 지도 Feature의 정보를 담는 데이터 클래스.
 * Feature는 지도 상의 개별 요소(POI, 도로, 건물 등)를 나타냅니다.
 */
@interface VSMFeatureInfo : NSObject

/**
 * Feature의 대표 좌표 (WGS84 경위도)
 */
@property (nonatomic, strong, readonly, nullable) VSMMapPoint *geoPoint;

/**
 * Feature의 지오메트리 좌표 목록 (WGS84 경위도)
 * Point 타입의 경우 단일 좌표, Polyline/Polygon의 경우 여러 좌표를 포함합니다.
 */
@property (nonatomic, strong, readonly, nonnull) NSArray<VSMMapPoint *> *geometry;

/**
 * Feature의 지오메트리 타입
 */
@property (nonatomic, assign, readonly) VSMFeatureGeometryType geometryType;

/**
 * Feature의 속성 정보
 * 키-값 쌍으로 이루어진 추가 속성들을 포함합니다.
 */
@property (nonatomic, strong, readonly, nonnull) NSDictionary<NSString *, id> *properties;

/**
 * VSMFeatureInfo 생성자
 * @param geoPoint Feature의 대표 좌표
 * @param geometry Feature의 지오메트리 좌표 목록
 * @param geometryType Feature의 지오메트리 타입
 * @param properties Feature의 속성 정보
 */
- (instancetype)initWithGeoPoint:(nullable VSMMapPoint *)geoPoint
                        geometry:(nullable NSArray<VSMMapPoint *> *)geometry
                    geometryType:(VSMFeatureGeometryType)geometryType
                      properties:(nullable NSDictionary<NSString *, id> *)properties;

/**
 * 특정 키에 해당하는 속성 값을 반환합니다.
 * @param key 속성 키
 * @return 속성 값, 없으면 nil
 */
- (nullable id)propertyForKey:(NSString *)key;

/**
 * 특정 키에 해당하는 속성 값을 문자열로 반환합니다.
 * @param key 속성 키
 * @return 속성 값의 문자열 표현, 없으면 nil
 */
- (nullable NSString *)propertyAsStringForKey:(NSString *)key;

@end

#pragma mark - VSMFeatureGroup

/**
 * 동일한 레이어에 속한 Feature들의 그룹
 */
@interface VSMFeatureGroup : NSObject

/**
 * 레이어 타입
 */
@property (nonatomic, assign, readonly) VSMMapExtendLayerType layer;

/**
 * 해당 레이어에 속한 Feature 목록
 */
@property (nonatomic, strong, readonly, nonnull) NSArray<VSMFeatureInfo *> *features;

/**
 * 해당 레이어에 속한 Feature 개수
 */
@property (nonatomic, assign, readonly) NSInteger featureCount;

/**
 * VSMFeatureGroup 생성자
 * @param layer 레이어 타입
 * @param features Feature 목록
 */
- (instancetype)initWithLayer:(VSMMapExtendLayerType)layer
                     features:(NSArray<VSMFeatureInfo *> *)features;

@end

#pragma mark - VSMFeatureQueryResult

/**
 * Feature 조회 결과를 담는 데이터 클래스.
 * 조회된 Feature들은 레이어별로 그룹화되어 제공됩니다.
 */
@interface VSMFeatureQueryResult : NSObject

/**
 * 레이어별 Feature 그룹 목록
 */
@property (nonatomic, strong, readonly, nonnull) NSArray<VSMFeatureGroup *> *groups;

/**
 * 조회된 총 Feature 개수
 */
@property (nonatomic, assign, readonly) NSInteger totalFeatureCount;

/**
 * 조회된 레이어 그룹의 개수
 */
@property (nonatomic, assign, readonly) NSInteger groupCount;

/**
 * 조회 결과가 비어있는지 확인
 */
@property (nonatomic, assign, readonly, getter=isEmpty) BOOL empty;

/**
 * VSMFeatureQueryResult 생성자
 * @param groups 레이어별 Feature 그룹 목록
 * @param totalFeatureCount 조회된 총 Feature 개수
 */
- (instancetype)initWithGroups:(NSArray<VSMFeatureGroup *> *)groups
             totalFeatureCount:(NSInteger)totalFeatureCount;

/**
 * 특정 레이어 타입에 해당하는 Feature 그룹을 반환합니다.
 * @param layer 레이어 타입
 * @return 해당 레이어의 Feature 그룹, 없으면 nil
 */
- (nullable VSMFeatureGroup *)groupByLayer:(VSMMapExtendLayerType)layer;

@end

#pragma mark - VSMFeatureQueryOptions

/**
 * Feature 조회 옵션을 설정하는 클래스.
 * Builder 패턴을 사용하여 옵션을 설정할 수 있습니다.
 */
@interface VSMFeatureQueryOptions : NSObject

/**
 * 지오메트리 정보 포함 여부 (기본값: YES)
 */
@property (nonatomic, assign, readonly) BOOL includeGeometry;

/**
 * 속성 정보 포함 여부 (기본값: YES)
 */
@property (nonatomic, assign, readonly) BOOL includeProperties;

/**
 * 레이어당 최대 Feature 수 (0 = 제한 없음, 기본값: 0)
 */
@property (nonatomic, assign, readonly) NSInteger maxFeaturesPerLayer;

/**
 * 조회할 레이어 필터
 * 비어있으면 조회하지 않습니다.
 */
@property (nonatomic, strong, readonly, nonnull) NSSet<NSNumber *> *layerFilter;

/**
 * 기본 옵션으로 생성된 VSMFeatureQueryOptions (SOCIAL_REPORT 레이어 조회)
 */
+ (instancetype)defaultOptions;

@end

#pragma mark - VSMFeatureQueryOptionsBuilder

/**
 * VSMFeatureQueryOptions를 생성하기 위한 Builder 클래스
 */
@interface VSMFeatureQueryOptionsBuilder : NSObject

/**
 * 지오메트리 정보 포함 여부 (기본값: YES)
 */
@property (nonatomic, assign) BOOL includeGeometry;

/**
 * 속성 정보 포함 여부 (기본값: YES)
 */
@property (nonatomic, assign) BOOL includeProperties;

/**
 * 레이어당 최대 Feature 수 (기본값: 0, 무제한)
 */
@property (nonatomic, assign) NSInteger maxFeaturesPerLayer;

/**
 * 조회할 레이어 필터
 */
@property (nonatomic, strong, readonly, nonnull) NSMutableSet<NSNumber *> *layerFilter;

/**
 * 조회할 레이어를 추가합니다.
 * @param layer 추가할 레이어
 * @return Builder 인스턴스
 */
- (VSMFeatureQueryOptionsBuilder *)addLayerFilter:(VSMMapExtendLayerType)layer;

/**
 * 설정된 옵션으로 VSMFeatureQueryOptions를 생성합니다.
 * @return VSMFeatureQueryOptions 인스턴스
 */
- (VSMFeatureQueryOptions *)build;

@end

#pragma mark - VSMFeatureQueryCallback Protocol

/**
 * Feature 조회 결과를 수신하기 위한 델리게이트 프로토콜.
 * 실시간 Feature 조회가 활성화된 경우, 지도 렌더링 시
 * 화면에 보이는 Feature 정보가 이 콜백을 통해 전달됩니다.
 */
@protocol VSMFeatureQueryDelegate <NSObject>

/**
 * Feature 조회 결과가 수신되었을 때 호출됩니다.
 * 이 메서드는 렌더링 스레드에서 호출될 수 있으므로,
 * UI 업데이트가 필요한 경우 메인 스레드로 전환해야 합니다.
 * @param result 조회된 Feature 정보
 */
- (void)onFeatureQueryResult:(VSMFeatureQueryResult *)result;

@end

NS_ASSUME_NONNULL_END
