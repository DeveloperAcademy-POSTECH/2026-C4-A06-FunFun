//
//  VSMMap.h
//  TAModule
//
//  Created by 1001921 on 2015. 3. 24..
//
//

#import <Foundation/Foundation.h>
#import "VSMMapDefine.h"

#define VSMMapInstance [VSMMap sharedInstance]

#define MAP_DL_ON_IOS 1

/**
 * VSM 로그 레벨.
 */
typedef NS_ENUM(NSInteger, VSMLogLevel) {
    VSMLogLevelError = 0,
    VSMLogLevelWarning = 1,
    VSMLogLevelInfo = 2,
    VSMLogLevelDebug = 3,
    VSMLogLevelVerbose = 4
};

/**
 * SDK 내부 로그를 수신하기 위한 블록 타입.
 * 주의: 콜백은 엔진 내부 스레드에서 호출됩니다.
 *
 * @param logLevel 로그 레벨
 * @param tag 로그 태그
 * @param message 로그 메시지
 */
typedef void (^VSMLogHandlerBlock)(VSMLogLevel logLevel, NSString* _Nonnull tag, NSString* _Nonnull message);

typedef void (^MapDLEnddedBlock)(BOOL result, NSError *error);

@interface VSMMap : NSObject

/**	싱글톤 VSMMap 객체를 반환합니다.
 */
+ (VSMMap*) sharedInstance;

/**    VSM Engine를 초기화 함.
 
 @return VSM Map Engine 초기화 시작 성공/실패 여부.
 */
- (bool) initEngine;

/**	VSM Engine을 종료 함.
 */
- (BOOL) destoryVSMEngine;

/** Engine Version 리턴
 
 @return Engine Version
 */
+ (NSString*) getEngineVersion;

/** Map Tile Cache 제거
 
    @return 성공 여부
 */
- (BOOL) cleanUpDiskCache;

/** Disk Cache Size 설정
 @param limit cache size (Bytes)
 */
- (void) setDiskCacheSizeLimit:(NSUInteger)limit;

/** 현재 설정된 최대 Disk Cache Size를 반환 (Bytes)
 */
- (NSUInteger) getDiskCacheSizeLimit;

/** 사용 중인 Disk Cache Size를 반환 (Bytes)
 */
- (NSUInteger) getDiskCacheSize;

/** 지도 Tile DB Caching Mode 설정
 @param mode DB Caching Mode
 @return 정상 설정 여부
 @see DB_CACHING_MODE
 */
- (BOOL) setTileDBCachingMode:(DB_CACHING_MODE)mode;

/** 지도 Tile DB Caching Mode 리턴
 
 @return DB Caching Mode
 @see DB_CACHING_MODE
 */
- (DB_CACHING_MODE) getTileDBCachingMode;

/** 신규 Embedded Map 존재 여부 확인

 */
- (void) checkNewEmbeddedMap;

/** Embedded Map Download 시작
 
    @param enddedBlock Embedded Map DL 완료후 수행할 block
    @return 동작 정상 수행 여부
 */
- (bool) startEmbeddedMapDownloadWithCompletion:(MapDLEnddedBlock) enddedBlock;


/** Embedded Map Download에 대한 Delegate를 등록합니다.
 
    @param downloadStatusCB Embedded Map Download에 대한 Delegate
 */
- (void) setEmbeddedMapDownloadDelegate:(id<EmbeddedMapDLStatusDelegate>)downloadStatusCB;

/** Embedded Map Download 정지
 
    @return 동작 정상 수행 여부
 */
- (bool) stopEmbeddedMapDownload;

/** Embedded Map 삭제
 
    @return 동작 정상 수행 여부
 */
- (bool) deleteEmbeddedMapDownload;

/** Embedded Map Download 현재 Status 리턴
 
 @return Embedded Map Download 현재 Status 리턴
 */
- (EmbeddedMapDLStatus) getEmbeddedMapDLStatus;

/** 다운로드 지도의 사용가능 여부를 조회하는 함수.

    @return 다운로드 지도의 사용가능 여부를 반환.
 */
- (bool) getEmbeddedMapAvailable;

/** 다운로드 지도의 신규 업데이트가 존재여부를 조회하는 함수.

    @return 지도의 신규 업데이트 여부를 반환.
 */
- (bool) getMapUpdateAvailable;

/** 지도 다운로드의 이어받기 가능여부를 조회하는 함수.
 
    @return 지도 다운로드의 이어받기 가능여부를 반환.
 */
- (bool) getMapContinuousDownloadAvailable;

/** 지도 전체 다운로드 크기를 조회하는 함수.
    
    @return 지도 전체 다운로드 크기를 반환.
 */
- (int) getMapTotalDownloadSize;

/** 다운로드 중인 지도의 크기를 조회하는 함수.

    @return 다운로드 중인 지도의 크기를 반환.
 */
- (int) getMapDownloadedSize;

/** 다운로드 지도의 버전을 조회하는 함수.

    @return 다운로드 지도의 버전을 조회하는 함수.
 */
- (NSString*) getEmbeddedMapLocalVersion;

/** 네트워크 상태에 대한 Delegate를 등록합니다.
 *  @param networkStatusCB  네트워크 상태에 대한 Delegate
 */
- (void) setNetworkDelegate:(id<NetworkStatusDelegate>)networkStatusCB;


/** VSM Rake logging을 위한 delegate 설정. deprecated
 
 @param delegate VSM Rake logging을 위한 delegate
 */
- (void) setVSMRakeLogEventDelegate:(id)delegate ;

#pragma mark - Unreleased API
// [twice] tyler added
- (void) forceSetEmbeddedMapDLStatus:(EmbeddedMapDLStatus)status;

- (void) enableMMRendering:(bool)enable;

/**
 * 로그 핸들러를 설정합니다.
 * 설정 시 엔진 내부 로그가 핸들러 블록으로 전달됩니다.
 * nil 전달 시 기본 동작(stdout/stderr)으로 복원됩니다.
 * 주의: 콜백은 엔진 내부 스레드에서 호출됩니다.
 *
 * @param handler 로그 핸들러 블록 (nil 허용)
 */
+ (void) installLogHandler:(nullable VSMLogHandlerBlock)handler;

@end
