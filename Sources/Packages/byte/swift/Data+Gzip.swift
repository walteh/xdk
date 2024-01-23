//
//  Data+Gzip.swift
//  nugg.xyz
//
//  Created by walter on 11/24/22.
//  Copyright © 2022 nugg.xyz LLC. All rights reserved.
//
//  Adapted from github.com/1024jp/GzipSwift by 1024jp <wolfrosch.com> under MIT
//

import struct Foundation.Data

import zlib

/// Compression level whose rawValue is based on the zlib's constants.
public struct CompressionLevel: RawRepresentable {
	/// Compression level in the range of `0` (no compression) to `9` (maximum compression).
	public let rawValue: Int32

	public static let noCompression = Self(Z_NO_COMPRESSION)
	public static let bestSpeed = Self(Z_BEST_SPEED)
	public static let bestCompression = Self(Z_BEST_COMPRESSION)

	public static let defaultCompression = Self(Z_DEFAULT_COMPRESSION)

	public init(rawValue: Int32) {
		self.rawValue = rawValue
	}

	public init(_ rawValue: Int32) {
		self.rawValue = rawValue
	}
}

/// Errors on gzipping/gunzipping based on the zlib error codes.
public struct GzipError: Swift.Error {
	// cf. http://www.zlib.net/manual.html

	public enum Kind: Equatable {
		/// The stream structure was inconsistent.
		///
		/// - underlying zlib error: `Z_STREAM_ERROR` (-2)
		case stream

		/// The input data was corrupted
		/// (input stream not conforming to the zlib format or incorrect check value).
		///
		/// - underlying zlib error: `Z_DATA_ERROR` (-3)
		case data

		/// There was not enough memory.
		///
		/// - underlying zlib error: `Z_MEM_ERROR` (-4)
		case memory

		/// No progress is possible or there was not enough room in the output buffer.
		///
		/// - underlying zlib error: `Z_BUF_ERROR` (-5)
		case buffer

		/// The zlib library version is incompatible with the version assumed by the caller.
		///
		/// - underlying zlib error: `Z_VERSION_ERROR` (-6)
		case version

		/// An unknown error occurred.
		///
		/// - parameter code: return error by zlib
		case unknown(code: Int)
	}

	/// Error kind.
	public let kind: Kind

	/// Returned message by zlib.
	public let message: String

	init(code: Int32, msg: UnsafePointer<CChar>?) {
		self.message = msg.flatMap { String(validatingUTF8: $0) } ?? "Unknown gzip error"

		self.kind = {
			switch code {
			case Z_STREAM_ERROR:
				return .stream
			case Z_DATA_ERROR:
				return .data
			case Z_MEM_ERROR:
				return .memory
			case Z_BUF_ERROR:
				return .buffer
			case Z_VERSION_ERROR:
				return .version
			default:
				return .unknown(code: Int(code))
			}
		}()
	}

	public var localizedDescription: String {
		return self.message
	}
}

public extension Data {
	/// Whether the receiver is compressed in gzip format.
	var isGzipped: Bool {
		return self.starts(with: [0x1F, 0x8B]) // check magic number
	}

	/// Create a new `Data` instance by compressing the receiver using zlib.
	/// Throws an error if compression failed.
	///
	/// The `wBits` parameter allows for managing the size of the history buffer. The possible values are:
	///
	///     Value       Window size logarithm    Input
	///     +9 to +15   Base 2                   Includes zlib header and trailer
	///     -9 to -15   Absolute value of wbits  No header and trailer
	///     +25 to +31  Low 4 bits of the value  Includes gzip header and trailing checksum
	///
	/// - Parameter level: Compression level.
	/// - Parameter wBits: Manage the size of the history buffer.
	/// - Returns: Gzip-compressed `Data` instance.
	/// - Throws: `GzipError`
	func gzipped(level: CompressionLevel = .defaultCompression, wBits: Int32 = MAX_WBITS + 16) throws -> Data {
		guard !self.isEmpty else {
			return Data()
		}

		var stream = z_stream()
		var status: Int32

		status = deflateInit2_(&stream, level.rawValue, Z_DEFLATED, wBits, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(DataSize.stream))

		guard status == Z_OK else {
			// deflateInit2 returns:
			// Z_VERSION_ERROR  The zlib library version is incompatible with the version assumed by the caller.
			// Z_MEM_ERROR      There was not enough memory.
			// Z_STREAM_ERROR   A parameter is invalid.

			throw GzipError(code: status, msg: stream.msg)
		}

		var data = Data(capacity: DataSize.chunk)
		repeat {
			if Int(stream.total_out) >= data.count {
				data.count += DataSize.chunk
			}

			let inputCount = self.count
			let outputCount = data.count

			self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
				stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!).advanced(by: Int(stream.total_in))
				stream.avail_in = uint(inputCount) - uInt(stream.total_in)

				data.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
					stream.next_out = outputPointer.bindMemory(to: Bytef.self).baseAddress!.advanced(by: Int(stream.total_out))
					stream.avail_out = uInt(outputCount) - uInt(stream.total_out)

					status = deflate(&stream, Z_FINISH)

					stream.next_out = nil
				}

				stream.next_in = nil
			}

		} while stream.avail_out == 0

		guard deflateEnd(&stream) == Z_OK, status == Z_STREAM_END else {
			throw GzipError(code: status, msg: stream.msg)
		}

		data.count = Int(stream.total_out)

		return data
	}

	/// Create a new `Data` instance by decompressing the receiver using zlib.
	/// Throws an error if decompression failed.
	///
	/// The `wBits` parameter allows for managing the size of the history buffer. The possible values are:
	///
	///     Value                        Window size logarithm    Input
	///     +8 to +15                    Base 2                   Includes zlib header and trailer
	///     -8 to -15                    Absolute value of wbits  Raw stream with no header and trailer
	///     +24 to +31 = 16 + (8 to 15)  Low 4 bits of the value  Includes gzip header and trailer
	///     +40 to +47 = 32 + (8 to 15)  Low 4 bits of the value  zlib or gzip format
	///
	/// - Parameter wBits: Manage the size of the history buffer.
	/// - Returns: Gzip-decompressed `Data` instance.
	/// - Throws: `GzipError`
	func gunzipped(wBits: Int32 = MAX_WBITS + 32) throws -> Data {
		guard !self.isEmpty else {
			return Data()
		}

		var stream = z_stream()
		var status: Int32

		status = inflateInit2_(&stream, wBits, ZLIB_VERSION, Int32(DataSize.stream))

		guard status == Z_OK else {
			// inflateInit2 returns:
			// Z_VERSION_ERROR   The zlib library version is incompatible with the version assumed by the caller.
			// Z_MEM_ERROR       There was not enough memory.
			// Z_STREAM_ERROR    A parameters are invalid.

			throw GzipError(code: status, msg: stream.msg)
		}

		var data = Data(capacity: self.count * 2)
		repeat {
			if Int(stream.total_out) >= data.count {
				data.count += self.count / 2
			}

			let inputCount = self.count
			let outputCount = data.count

			self.withUnsafeBytes { (inputPointer: UnsafeRawBufferPointer) in
				stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputPointer.bindMemory(to: Bytef.self).baseAddress!).advanced(by: Int(stream.total_in))
				stream.avail_in = uint(inputCount) - uInt(stream.total_in)

				data.withUnsafeMutableBytes { (outputPointer: UnsafeMutableRawBufferPointer) in
					stream.next_out = outputPointer.bindMemory(to: Bytef.self).baseAddress!.advanced(by: Int(stream.total_out))
					stream.avail_out = uInt(outputCount) - uInt(stream.total_out)

					status = inflate(&stream, Z_SYNC_FLUSH)

					stream.next_out = nil
				}

				stream.next_in = nil
			}

		} while status == Z_OK

		guard inflateEnd(&stream) == Z_OK, status == Z_STREAM_END else {
			// inflate returns:
			// Z_DATA_ERROR   The input data was corrupted (input stream not conforming to the zlib format or incorrect check value).
			// Z_STREAM_ERROR The stream structure was inconsistent (for example if next_in or next_out was NULL).
			// Z_MEM_ERROR    There was not enough memory.
			// Z_BUF_ERROR    No progress is possible or there was not enough room in the output buffer when Z_FINISH is used.

			throw GzipError(code: status, msg: stream.msg)
		}

		data.count = Int(stream.total_out)

		return data
	}
}

private enum DataSize {
	static let chunk = 1 << 14
	static let stream = MemoryLayout<z_stream>.size
}

public extension Data {
	func ungzip() throws -> Data {
		if self.isGzipped {
			return try self.gunzipped()
		} else {
			return self
		}
	}
}
