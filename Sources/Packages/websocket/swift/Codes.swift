//
//  Frame.swift
//  nugg.xyz
//
//  Created by walter on 11/24/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//
//  Inspied by github.com/daltoniam/Starscream by Dalton Cherry
//

import Foundation

let FinMask: UInt8 = 0x80
let OpCodeMask: UInt8 = 0x0F
let RSVMask: UInt8 = 0x70
let RSV1Mask: UInt8 = 0x40
let MaskMask: UInt8 = 0x80
let PayloadLenMask: UInt8 = 0x7F
let MaxFrameSize: Int = 32

// Standard WebSocket close codes
public enum CloseCode: UInt16 {
	case normal = 1000
	case goingAway = 1001
	case protocolError = 1002
	case protocolUnhandledType = 1003
	// 1004 reserved.
	case noStatusReceived = 1005
	// 1006 reserved.
	case encoding = 1007
	case policyViolated = 1008
	case messageTooBig = 1009
}

public enum FrameOpCode: UInt8 {
	case continueFrame = 0x0
	case textFrame = 0x1
	case binaryFrame = 0x2
	// 3-7 are reserved.
	case connectionClose = 0x8
	case ping = 0x9
	case pong = 0xA
	// B-F reserved.
	case unknown = 100
}
