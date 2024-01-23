
enum XIDError: Error, Equatable {
	case decodeValidationFailure
	case invalidID
	case InvalidStringLength(have: Int, want: Int)
	case InvalidRawDataLength(have: Int, want: Int)
}
