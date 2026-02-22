import Foundation
import NetworkExtension
import os
import TerracottaShared

// FFI函数包装器 - 用于调用Rust库函数
func create_room(_ roomName: UnsafePointer<CChar>, _ errPtr: UnsafeMutablePointer<UnsafePointer<CChar>?>?, _ result: UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32 {
    return terracotta_ios_create_room(roomName, errPtr, result)
}

func join_room(_ roomCode: UnsafePointer<CChar>, _ errPtr: UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32 {
    return terracotta_ios_join_room(roomCode, errPtr)
}

// 导入C函数声明
@_silgen_name("create_room")
private func terracotta_ios_create_room(_ roomName: UnsafePointer<CChar>, _ errPtr: UnsafeMutablePointer<UnsafePointer<CChar>?>?, _ result: UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32

@_silgen_name("join_room")
private func terracotta_ios_join_room(_ roomCode: UnsafePointer<CChar>, _ errPtr: UnsafeMutablePointer<UnsafePointer<CChar>?>?) -> Int32