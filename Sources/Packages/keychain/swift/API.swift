//
//  API.swift
//
//
//  Created by walter on 3/2/23.
//

import Foundation
import XDK

public enum KeychainError: Swift.Error {
	case unhandled(status: OSStatus)
	case readCredentials__SecItemCopyMatching__ItemNotFound
	case addCredentials__SecItemAdd__SecAuthFailed
	case duplicate_item
	case auth_failed
	case auth_approved_but_no_value_found
	case auth_request_denied_by_user
	case no_auth_saved
	case auth_already_saved
	case evalutePolicy_returned_nothing
	case cannot_create_address_from_compressed_key
	case errSecParam
}
