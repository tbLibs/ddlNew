//
//  ObservableType+ObjectMapper.swift
//  ddlNew
//
//  Created by taobo on 2026/9/23.
//  基于 Ivan Bruel 2015 年的实现修改。
//

import Foundation
import RxSwift
import Moya
import ObjectMapper

// 将 Moya 响应映射为可变模型，映射失败时向下游发送错误。
public extension ObservableType where Element == Moya.Response {

    func mapObject<T: BaseMappable>(_ type: T.Type, context: MapContext? = nil) -> Observable<T> {
        flatMap { response in
            Observable.just(try response.mapObject(type, context: context))
        }
    }

    func mapArray<T: BaseMappable>(_ type: T.Type, context: MapContext? = nil) -> Observable<[T]> {
        flatMap { response in
            Observable.just(try response.mapArray(type, context: context))
        }
    }

    func mapObject<T: BaseMappable>(_ type: T.Type, atKeyPath keyPath: String, context: MapContext? = nil) -> Observable<T> {
        flatMap { response in
            Observable.just(try response.mapObject(type, atKeyPath: keyPath, context: context))
        }
    }

    func mapArray<T: BaseMappable>(_ type: T.Type, atKeyPath keyPath: String, context: MapContext? = nil) -> Observable<[T]> {
        flatMap { response in
            Observable.just(try response.mapArray(type, atKeyPath: keyPath, context: context))
        }
    }
}

// 将 Moya 响应映射为不可变模型，映射失败时向下游发送错误。
public extension ObservableType where Element == Moya.Response {

    func mapObject<T: ImmutableMappable>(_ type: T.Type, context: MapContext? = nil) -> Observable<T> {
        flatMap { response in
            Observable.just(try response.mapObject(type, context: context))
        }
    }

    func mapArray<T: ImmutableMappable>(_ type: T.Type, context: MapContext? = nil) -> Observable<[T]> {
        flatMap { response in
            Observable.just(try response.mapArray(type, context: context))
        }
    }

    func mapObject<T: ImmutableMappable>(_ type: T.Type, atKeyPath keyPath: String, context: MapContext? = nil) -> Observable<T> {
        flatMap { response in
            Observable.just(try response.mapObject(type, atKeyPath: keyPath, context: context))
        }
    }

    func mapArray<T: ImmutableMappable>(_ type: T.Type, atKeyPath keyPath: String, context: MapContext? = nil) -> Observable<[T]> {
        flatMap { response in
            Observable.just(try response.mapArray(type, atKeyPath: keyPath, context: context))
        }
    }
}
