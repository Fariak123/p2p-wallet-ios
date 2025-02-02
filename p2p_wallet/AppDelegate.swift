//
//  AppDelegate.swift
//  p2p wallet
//
//  Created by Chung Tran on 10/22/20.
//

@_exported import BEPureLayout
import FeeRelayerSwift
import Firebase
import Intercom
import KeyAppKitLogger
import KeyAppUI
import Lokalise
import Resolver
import Sentry
import SolanaSwift
import SwiftNotificationCenter
@_exported import SwiftyUserDefaults
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    @Injected private var notificationService: NotificationService

    static var shared: AppDelegate {
        UIApplication.shared.delegate as! AppDelegate
    }

    private lazy var proxyAppDelegate = AppDelegateProxyService()

    override init() {
        super.init()

        setupFirebaseLogging()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // TODO: - Support custom fiat later
        Defaults.fiat = .usd

        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        // TODO: - Swizzle localization later
//        Bundle.swizzleLocalization()
        IntercomStartingConfigurator().configure()

        setupNavigationAppearance()

        FirebaseApp.configure()

        setupLoggers()
        setupDefaultCurrency()

        // Sentry
        #if !DEBUG
        SentrySDK.start { options in
            options.dsn = .secretConfig("SENTRY_DSN")
            options.tracesSampleRate = 1.0
            options.enableNetworkTracking = true
            options.enableOutOfMemoryTracking = true
        }
        #endif

        Lokalise.shared.setProjectID(
            String.secretConfig("LOKALISE_PROJECT_ID")!,
            token: String.secretConfig("LOKALISE_TOKEN")!
        )
        Lokalise.shared.swizzleMainBundle()

        // Set app coordinator
        appCoordinator = AppCoordinator()
        appCoordinator!.start()
        window = appCoordinator?.window

        // notify notification Service
        notificationService.wasAppLaunchedFromPush(launchOptions: launchOptions)

        UIViewController.swizzleViewDidDisappear()
        UIViewController.swizzleViewDidAppear()

        return proxyAppDelegate.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task.detached(priority: .background) { [unowned self] in
            try await notificationService.sendRegisteredDeviceToken(deviceToken)
        }
        Intercom.setDeviceToken(deviceToken) { error in
            guard let error else { return }
            print("Intercom.setDeviceToken error: ", error)
        }
        proxyAppDelegate.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        Defaults.apnsDeviceToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        DefaultLogManager.shared.log(
            event: "Application: didFailToRegisterForRemoteNotificationsWithError: \(error)",
            logLevel: .debug
        )
        proxyAppDelegate.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        var isGoogleServiceUrlHanded = false
        Broadcaster.notify(AppUrlHandler.self) { isGoogleServiceUrlHanded = isGoogleServiceUrlHanded || $0.handle(url: url, options: options) }
        if isGoogleServiceUrlHanded {
            return true
        }

        return proxyAppDelegate.application(application, open: url, options: options)
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        return proxyAppDelegate.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        notificationService.didReceivePush(userInfo: userInfo)
        proxyAppDelegate.application(
            application,
            didReceiveRemoteNotification: userInfo,
            fetchCompletionHandler: completionHandler
        )
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        proxyAppDelegate.applicationDidBecomeActive(application)
    }

    func setupLoggers() {
        var loggers: [LogManagerLogger] = [
            SentryLogger(),
        ]
        if Environment.current == .debug {
            loggers.append(LoggerSwiftLogger())
        }

        SolanaSwift.Logger.setLoggers(loggers as! [SolanaSwiftLogger])
        FeeRelayerSwift.Logger.setLoggers(loggers as! [FeeRelayerSwiftLogger])
        KeyAppKitLogger.Logger.setLoggers(loggers as! [KeyAppKitLoggerType])
        DefaultLogManager.shared.setProviders(loggers)
    }

    private func setupNavigationAppearance() {
        let barButtonAppearance = UIBarButtonItem.appearance()
        let navBarAppearence = UINavigationBar.appearance()
        navBarAppearence.backIndicatorImage = .navigationBack
            .withRenderingMode(.alwaysTemplate)
            .withAlignmentRectInsets(.init(top: 0, left: -12, bottom: 0, right: 0))
        navBarAppearence.backIndicatorTransitionMaskImage = .navigationBack
            .withRenderingMode(.alwaysTemplate)
            .withAlignmentRectInsets(.init(top: 0, left: -12, bottom: 0, right: 0))
        barButtonAppearance.setBackButtonTitlePositionAdjustment(
            .init(horizontal: -UIScreen.main.bounds.width * 1.5, vertical: 0),
            for: .default
        )
        navBarAppearence.titleTextAttributes = [.foregroundColor: UIColor.black]
        navBarAppearence.tintColor = Asset.Colors.night.color
        barButtonAppearance.tintColor = Asset.Colors.night.color

        navBarAppearence.shadowImage = UIImage()
        navBarAppearence.isTranslucent = true
    }

    func setupDefaultCurrency() {
        guard Defaults.fiat != .usd else { return }
        // Migrate all users to default currency
        Defaults.fiat = .usd
    }

    private func setupFirebaseLogging() {
        var arguments = ProcessInfo.processInfo.arguments
        #if !RELEASE
        arguments.removeAll { $0 == "-FIRDebugDisabled" }
        arguments.append("-FIRDebugEnabled")
        #else
        arguments.removeAll { $0 == "-FIRDebugEnabled" }
        arguments.append("-FIRDebugDisabled")
        #endif
        ProcessInfo.processInfo.setValue(arguments, forKey: "arguments")
    }
}
