//
//  Features.swift
//  FeatureFlags
//
//  Created by Babich Ivan on 10.06.2022.
//

public extension Feature {
    static let coinGeckoPriceProvider = Feature(rawValue: "coinGeckoPriceProvider")
    static let buyScenarioEnabled = Feature(rawValue: "keyapp_buy_scenario_enabled")
    static let buyBankTransferEnabled = Feature(rawValue: "buy_bank_transfer_enabled")
    static let settingsFeature = Feature(rawValue: "settingsFeature")
    static let newOnboardingFlow = Feature(rawValue: "newOnboardingFlow")

    // Username
    static let onboardingUsernameEnabled = Feature(rawValue: "ios_onboarding_username_enabled")
    static let onboardingUsernameButtonSkipEnabled = Feature(rawValue: "ios_onboarding_username_button_skip_enabled")

    // Onboarding
    static let mockedApiGateway = Feature(rawValue: "mockedApiGateway")
    static let mockedTKeyFacade = Feature(rawValue: "mockedTKeyFacade")
    static let mockedDeviceShare = Feature(rawValue: "mockedDeviceShare")
    static let simulatedSocialError = Feature(rawValue: "simulatedSocialError")

    // MARK: - Solana tracking

    static let solanaNegativeStatus = Feature(rawValue: "solana_negative_status_enabled")
}
