import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging

enum UpdateNotificationPolicy {
    static let topic = "numpad_updates_v1"
    static let testTopic = "numpad_updates_test_v1"
    static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound]
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id1072547160")!

    static func canRegister(optedIn: Bool, authorization: UNAuthorizationStatus) -> Bool {
        optedIn && (authorization == .authorized || authorization == .provisional)
    }

    /// Campaign data is an allowlisted route, never an arbitrary URL to execute.
    static func destination(identifier: String, userInfo: [AnyHashable: Any]) -> URL? {
        if identifier == WhatsNewNotification.requestID { return URL(string: WhatsNew.deepLinkURLString) }
        guard userInfo["kind"] as? String == "numpad_update" else { return nil }
        let route = userInfo["deeplink"] as? String ?? "numpad://app-store"
        guard route == "numpad://app-store" || route == WhatsNew.deepLinkURLString else { return nil }
        return URL(string: route)
    }
}

protocol UpdateMessagingClient: AnyObject {
    func token(completion: @escaping (String?, Error?) -> Void)
    func subscribe(topic: String, completion: @escaping (Error?) -> Void)
    func unsubscribe(topic: String, completion: @escaping (Error?) -> Void)
    func deleteToken(completion: @escaping (Error?) -> Void)
}

private final class FirebaseUpdateMessagingClient: UpdateMessagingClient {
    func token(completion: @escaping (String?, Error?) -> Void) {
        Messaging.messaging().token { token, error in
            DispatchQueue.main.async { completion(token, error) }
        }
    }
    func subscribe(topic: String, completion: @escaping (Error?) -> Void) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
    func unsubscribe(topic: String, completion: @escaping (Error?) -> Void) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
    func deleteToken(completion: @escaping (Error?) -> Void) {
        Messaging.messaging().deleteToken { error in
            DispatchQueue.main.async { completion(error) }
        }
    }
}

/// Main-queue enrollment. Token operations stay serialized, but opt-out can bypass a topic
/// completion the SDK withholds while offline. Only successful current subscription means ready.
final class UpdateNotificationEnrollment {
    enum State: Equatable { case off, waiting, connecting, ready, failed }
    private let client: UpdateMessagingClient
    private let defaults: UserDefaults
    private let topic: String
    private let obsoleteTopic: String?
    private var enabled = false
    private var apnsReady = false
    private enum Operation { case token, topic, deletion }
    private var operation: Operation?
    private var operationGeneration = 0
    private var cleanupRevision = 0
    private(set) var token: String?
    private var subscribedToken: String?
    private var cleanedObsoleteForToken: String?
    private(set) var state: State = .off { didSet { if state != oldValue { didChange?() } } }
    var didChange: (() -> Void)?

    private var cleanupRequired: Bool {
        get { defaults.bool(forKey: Constants.updateNotificationsCleanupRequired.rawValue) }
        set { defaults.set(newValue, forKey: Constants.updateNotificationsCleanupRequired.rawValue) }
    }
    private var registeredTopic: String? {
        get { defaults.string(forKey: Constants.updateNotificationsTopic.rawValue) }
        set { defaults.set(newValue, forKey: Constants.updateNotificationsTopic.rawValue) }
    }

    init(client: UpdateMessagingClient, defaults: UserDefaults, topic: String, obsoleteTopic: String? = nil) {
        self.client = client
        self.defaults = defaults
        self.topic = topic
        self.obsoleteTopic = obsoleteTopic
    }

    func configure(enabled: Bool, apnsReady: Bool) {
        self.enabled = enabled
        self.apnsReady = apnsReady
        drive()
    }

    func tokenDidChange(_ value: String?) {
        guard let value, !value.isEmpty else { return }
        cleanupRequired = true
        cleanupRevision += 1
        if token != value { token = value; subscribedToken = nil; cleanedObsoleteForToken = nil }
        drive()
    }

    func retry() { drive() }

    private func begin(_ operation: Operation) -> Int {
        operationGeneration += 1
        self.operation = operation
        return operationGeneration
    }

    private func finish(_ generation: Int) -> Bool {
        guard generation == operationGeneration else { return false }
        operation = nil
        return true
    }

    private func finishTopic(_ generation: Int) -> Bool {
        guard finish(generation) else {
            // A topic API can finish its internal token preflight after we opted out. Never
            // fetch a token to unsubscribe while off; compensate by deleting the registration.
            // Preserve this intent if a deletion is already running.
            if !enabled {
                cleanupRequired = true
                cleanupRevision += 1
                drive()
            }
            return false
        }
        return true
    }

    private func drive() {
        if !enabled || (cleanupRequired && registeredTopic != topic) {
            token = nil
            subscribedToken = nil
            cleanedObsoleteForToken = nil
            guard cleanupRequired else { state = .off; return }
            // Firebase retains topic completions on recoverable network errors. Waiting for
            // one here would prevent cleanup even after the user reopened the app. Its token
            // deletion uses a separate SDK queue; invalidate the old topic callback instead.
            guard operation == nil || operation == .topic else { return }
            let generation = begin(.deletion)
            let revision = cleanupRevision
            state = .connecting
            // This app uses FCM only for updates. Deleting its registration removes every topic
            // subscription without fetching a new token just to unsubscribe.
            client.deleteToken { [weak self] error in
                guard let self, self.finish(generation) else { return }
                guard error == nil else { self.state = .failed; return }
                self.cleanupRequired = self.cleanupRevision != revision
                self.registeredTopic = nil
                self.token = nil
                self.subscribedToken = nil
                self.cleanedObsoleteForToken = nil
                self.drive()
            }
            return
        }
        guard operation == nil else { return }
        guard apnsReady else { state = .waiting; return }
        guard let token else {
            registeredTopic = topic
            cleanupRequired = true // Preserve cleanup intent even if the process exits mid-request.
            let generation = begin(.token)
            state = .connecting
            client.token { [weak self] value, error in
                guard let self, self.finish(generation) else { return }
                guard self.enabled else { self.drive(); return }
                // The delegate may have delivered a newer token while this fetch was in flight.
                if self.token == nil, error == nil, let value, !value.isEmpty { self.token = value }
                guard self.token != nil else { self.state = .failed; return }
                self.drive()
            }
            return
        }
        if let obsoleteTopic, obsoleteTopic != topic, cleanedObsoleteForToken != token {
            let generation = begin(.topic)
            state = .connecting
            // The SDK persists unfinished topic operations across launches. Enqueue removal
            // after those operations, before joining this build's audience. Token deletion
            // alone does not clear that SDK queue. This runs only with current opt-in and APNs.
            client.unsubscribe(topic: obsoleteTopic) { [weak self] error in
                guard let self, self.finishTopic(generation) else { return }
                guard self.enabled else { self.drive(); return }
                guard error == nil else { self.state = .failed; return }
                if self.token == token { self.cleanedObsoleteForToken = token }
                self.drive()
            }
            return
        }
        guard subscribedToken != token else { state = .ready; return }
        let generation = begin(.topic)
        state = .connecting
        client.subscribe(topic: topic) { [weak self] error in
            guard let self, self.finishTopic(generation) else { return }
            guard self.enabled else { self.drive(); return }
            guard error == nil else { self.state = .failed; return }
            if self.token == token { self.subscribedToken = token }
            self.drive()
        }
    }
}

/// Main-app only. FCM auto-initialization stays off; token creation follows explicit consent
/// AND APNs registration. No token or notification payload is written to analytics or logs.
final class UpdateNotifications: NSObject, MessagingDelegate {
    static let shared = UpdateNotifications()
    static let changed = Notification.Name("com.morevoltage.numpad.updateNotificationsChanged")

    @UserDefault(key: Constants.updateNotificationsEnabled.rawValue, defaultValue: false, userDefaults: .standard)
    private(set) static var isEnabled: Bool

    enum EnableResult: Equatable { case enabled, denied, failed, cancelled }
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private var apnsReady = false
    private var permissionGeneration = 0
    private var refreshGeneration = 0
    private var retryCount = 0
    private var retryWork: DispatchWorkItem?
    private var registrationPending = false
    private(set) var registrationFailed = false
    private lazy var enrollment = UpdateNotificationEnrollment(
        client: FirebaseUpdateMessagingClient(), defaults: .standard,
        topic: FeatureFlags.experimentalUIVisible ? UpdateNotificationPolicy.testTopic : UpdateNotificationPolicy.topic,
        obsoleteTopic: FeatureFlags.experimentalUIVisible ? UpdateNotificationPolicy.topic : UpdateNotificationPolicy.testTopic)

    var isReady: Bool { enrollment.state == .ready }
    var hasConnectionError: Bool { registrationFailed || enrollment.state == .failed }
    var testToken: String? { FeatureFlags.experimentalUIVisible ? enrollment.token : nil }

    func start() {
        Messaging.messaging().isAutoInitEnabled = false
        Messaging.messaging().delegate = self
        enrollment.didChange = { [weak self] in self?.enrollmentChanged() }
        refresh()
    }

    /// Called on foreground and when returning from Settings. Never asks for permission.
    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self, generation == self.refreshGeneration else { return }
                self.authorization = settings.authorizationStatus
                self.retryCount = 0
                self.reconcile()
            }
        }
    }

    /// Only an explicit app button invokes the OS prompt. Existing local-reminder permission
    /// alone never opts an installation into remote updates.
    func requestEnable(completion: @escaping (EnableResult) -> Void) {
        permissionGeneration += 1
        let generation = permissionGeneration
        UNUserNotificationCenter.current().requestAuthorization(options: UpdateNotificationPolicy.authorizationOptions) { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self, generation == self.permissionGeneration else { completion(.cancelled); return }
                guard error == nil else { completion(.failed); return }
                guard granted else { completion(.denied); return }
                Self.isEnabled = true
                self.refresh()
                completion(.enabled)
            }
        }
    }

    func disable() {
        permissionGeneration += 1
        refreshGeneration += 1
        Self.isEnabled = false
        EarlyBird.cancelReminders()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [WhatsNewNotification.requestID])
        retryCount = 0
        reconcile()
    }

    func didRegister(apnsToken: Data) {
        registrationPending = false
        registrationFailed = false
        // A late registration result cannot turn a disabled preference back on.
        guard UpdateNotificationPolicy.canRegister(optedIn: Self.isEnabled, authorization: authorization) else {
            UIApplication.shared.unregisterForRemoteNotifications()
            return
        }
        Messaging.messaging().apnsToken = apnsToken
        apnsReady = true
        reconcile()
    }

    func didFailRegistration() {
        registrationPending = false
        registrationFailed = true
        scheduleRetry()
        notify()
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        DispatchQueue.main.async { [weak self] in self?.enrollment.tokenDidChange(fcmToken) }
    }

    private func reconcile() {
        let allowed = UpdateNotificationPolicy.canRegister(optedIn: Self.isEnabled, authorization: authorization)
        if !allowed {
            UIApplication.shared.unregisterForRemoteNotifications()
            apnsReady = false
            registrationPending = false
            registrationFailed = false
        }
        enrollment.configure(enabled: allowed, apnsReady: apnsReady)
        if allowed && !apnsReady && !registrationPending {
            registrationPending = true
            UIApplication.shared.registerForRemoteNotifications()
        }
        notify()
    }

    private func enrollmentChanged() {
        if enrollment.state == .failed { scheduleRetry() }
        else if enrollment.state == .ready || enrollment.state == .off {
            retryWork?.cancel()
        }
        notify()
    }

    private func scheduleRetry() {
        guard retryCount < 3 else { return }
        retryWork?.cancel()
        let delay = [2.0, 10.0, 30.0][retryCount]
        retryCount += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self, UIApplication.shared.applicationState == .active else { return }
            self.reconcile()
        }
        retryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func notify() { NotificationCenter.default.post(name: Self.changed, object: nil) }
}
