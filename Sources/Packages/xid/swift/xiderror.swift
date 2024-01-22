
enum XIDError: Error, Equatable {
	case decodeValidationFailure
	case invalidID
	case invalidIDStringLength(have: Int, want: Int)
	case invalidRawDataLength(have: Int, want: Int)
}
