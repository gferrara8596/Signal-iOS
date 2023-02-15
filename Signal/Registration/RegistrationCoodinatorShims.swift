//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Contacts
import Foundation

extension RegistrationCoordinatorImpl {

    public enum Shims {
        public typealias ContactsStore = _RegistrationCoordinator_CNContactsStoreShim
        public typealias OWS2FAManager = _RegistrationCoordinator_OWS2FAManagerShim
        public typealias ProfileManager = _RegistrationCoordinator_ProfileManagerShim
        public typealias PushRegistrationManager = _RegistrationCoordinator_PushRegistrationManagerShim
        public typealias RemoteConfig = _RegistrationCoordinator_RemoteConfigShim
        public typealias TSAccountManager = _RegistrationCoordinator_TSAccountManagerShim
        public typealias UDManager = _RegistrationCoordinator_UDManagerShim
    }
    public enum Wrappers {
        public typealias ContactsStore = _RegistrationCoordinator_CNContactsStoreWrapper
        public typealias OWS2FAManager = _RegistrationCoordinator_OWS2FAManagerWrapper
        public typealias ProfileManager = _RegistrationCoordinator_ProfileManagerWrapper
        public typealias PushRegistrationManager = _RegistrationCoordinator_PushRegistrationManagerWrapper
        public typealias RemoteConfig = _RegistrationCoordinator_RemoteConfigWrapper
        public typealias TSAccountManager = _RegistrationCoordinator_TSAccountManagerWrapper
        public typealias UDManager = _RegistrationCoordinator_UDManagerWrapper
    }
}

// MARK: CNContacts

public protocol _RegistrationCoordinator_CNContactsStoreShim {

    func needsContactsAuthorization() -> Guarantee<Bool>

    func requestContactsAuthorization() -> Guarantee<Void>
}

public class _RegistrationCoordinator_CNContactsStoreWrapper: _RegistrationCoordinator_CNContactsStoreShim {

    public init() {}

    public func needsContactsAuthorization() -> Guarantee<Bool> {
        return .value(CNContactStore.authorizationStatus(for: .contacts) == .notDetermined)
    }

    public func requestContactsAuthorization() -> Guarantee<Void> {
        let (guarantee, future) = Guarantee<Void>.pending()
        CNContactStore().requestAccess(for: CNEntityType.contacts) { (granted, error) -> Void in
            if granted {
                Logger.info("User granted contacts permission")
            } else {
                // Unfortunately, we can't easily disambiguate "not granted" and
                // "other error".
                Logger.warn("User denied contacts permission or there was an error. Error: \(String(describing: error))")
            }
            future.resolve()
        }
        return guarantee
    }
}

// MARK: - OWS2FAManager

public protocol _RegistrationCoordinator_OWS2FAManagerShim {

    func pinCode(_ tx: DBReadTransaction) -> String?
}

public class _RegistrationCoordinator_OWS2FAManagerWrapper: _RegistrationCoordinator_OWS2FAManagerShim {

    private let manager: OWS2FAManager
    public init(_ manager: OWS2FAManager) { self.manager = manager }

    public func pinCode(_ tx: DBReadTransaction) -> String? {
        manager.pinCode(with: SDSDB.shimOnlyBridge(tx))
    }
}

// MARK: - ProfileManager

public protocol _RegistrationCoordinator_ProfileManagerShim {

    var hasProfileName: Bool { get }

    // NOTE: non-optional because OWSProfileManager generates a random key
    // if one doesn't already exist.
    var localProfileKey: OWSAES256Key { get }
}

public class _RegistrationCoordinator_ProfileManagerWrapper: _RegistrationCoordinator_ProfileManagerShim {

    private let manager: ProfileManagerProtocol
    public init(_ manager: ProfileManagerProtocol) { self.manager = manager }

    public var hasProfileName: Bool { manager.hasProfileName }

    public var localProfileKey: OWSAES256Key { manager.localProfileKey() }
}

// MARK: - PushRegistrationManager

public protocol _RegistrationCoordinator_PushRegistrationManagerShim {

    func needsNotificationAuthorization() -> Guarantee<Bool>

    func registerUserNotificationSettings() -> Guarantee<Void>

    func requestPushToken() -> Guarantee<String?>
}

public class _RegistrationCoordinator_PushRegistrationManagerWrapper: _RegistrationCoordinator_PushRegistrationManagerShim {

    private let manager: PushRegistrationManager
    public init(_ manager: PushRegistrationManager) { self.manager = manager }

    public func needsNotificationAuthorization() -> Guarantee<Bool> {
        return manager.needsNotificationAuthorization()
    }

    public func registerUserNotificationSettings() -> Guarantee<Void> {
        return manager.registerUserNotificationSettings()
    }

    public func requestPushToken() -> Guarantee<String?> {
        return manager.requestPushTokens(forceRotation: false)
            .map { $0.0 }
            .recover { _ in return .value(nil) }
    }
}

// MARK: - RemoteConfig

public protocol _RegistrationCoordinator_RemoteConfigShim {

    var canReceiveGiftBadges: Bool { get }
}

public class _RegistrationCoordinator_RemoteConfigWrapper: _RegistrationCoordinator_RemoteConfigShim {

    public init() {}

    public var canReceiveGiftBadges: Bool { RemoteConfig.canSendGiftBadges }
}

// MARK: - TSAccountManager

public protocol _RegistrationCoordinator_TSAccountManagerShim {

    func hasDefinedIsDiscoverableByPhoneNumber() -> Bool

    func isManualMessageFetchEnabled(_ transaction: DBReadTransaction) -> Bool

    func getOrGenerateRegistrationId(_ transaction: DBWriteTransaction) -> UInt32
    func getOrGeneratePniRegistrationId(_ transaction: DBWriteTransaction) -> UInt32

    func isDiscoverableByPhoneNumber(_ transaction: DBReadTransaction) -> Bool
}

public class _RegistrationCoordinator_TSAccountManagerWrapper: _RegistrationCoordinator_TSAccountManagerShim {

    private let manager: TSAccountManager
    public init(_ manager: TSAccountManager) { self.manager = manager }

    public func hasDefinedIsDiscoverableByPhoneNumber() -> Bool {
        return manager.hasDefinedIsDiscoverableByPhoneNumber()
    }

    public func isManualMessageFetchEnabled(_ transaction: DBReadTransaction) -> Bool {
        return manager.isManualMessageFetchEnabled(SDSDB.shimOnlyBridge(transaction))
    }

    public func getOrGenerateRegistrationId(_ transaction: DBWriteTransaction) -> UInt32 {
        return manager.getOrGenerateRegistrationId(transaction: SDSDB.shimOnlyBridge(transaction))
    }

    public func getOrGeneratePniRegistrationId(_ transaction: DBWriteTransaction) -> UInt32 {
        return manager.getOrGeneratePniRegistrationId(transaction: SDSDB.shimOnlyBridge(transaction))
    }

    public func isDiscoverableByPhoneNumber(_ transaction: DBReadTransaction) -> Bool {
        return manager.isDiscoverableByPhoneNumber(with: SDSDB.shimOnlyBridge(transaction))
    }
}

// MARK: - UDManager

public protocol _RegistrationCoordinator_UDManagerShim {

    func shouldAllowUnrestrictedAccessLocal(transaction: DBReadTransaction) -> Bool
}

public class _RegistrationCoordinator_UDManagerWrapper: _RegistrationCoordinator_UDManagerShim {

    private let manager: OWSUDManager
    public init(_ manager: OWSUDManager) { self.manager = manager }

    public func shouldAllowUnrestrictedAccessLocal(transaction: DBReadTransaction) -> Bool {
        return manager.shouldAllowUnrestrictedAccessLocal(transaction: SDSDB.shimOnlyBridge(transaction))
    }
}