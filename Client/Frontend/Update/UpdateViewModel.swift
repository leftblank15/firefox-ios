// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation
import Shared

class UpdateViewModel: OnboardingViewModelProtocol,
                       FeatureFlaggable,
                       AppVersionUpdateCheckerProtocol {
    let profile: Profile
    var hasSyncableAccount: Bool?

    var shouldShowSingleCard: Bool {
        return enabledCards.count == 1
    }

    var isFeatureEnabled: Bool {
        return true
    }

    var enabledCards: [IntroViewModel.InformationCards] {
        if hasSyncableAccount ?? false {
            return [.updateWelcome]
        }

        return [.updateWelcome, .updateSignSync]
    }

    // If the feature is enabled and is not clean install
    var shouldShowFeature: Bool {
        return featureFlags.isFeatureEnabled(.onboardingUpgrade, checking: .buildOnly) && !isFreshInstall
    }

    var isFreshInstall: Bool {
        return profile.prefs.stringForKey(PrefsKeys.AppVersion.Latest) == nil
    }

    init(profile: Profile) {
        self.profile = profile
    }

    func shouldShowUpdateSheet(force: Bool = false,
                               appVersion: String = AppInfo.appVersion) -> Bool {
        guard !force else { return true }

        guard shouldShowFeature else {
            saveAppVersion(for: appVersion)
            return false
        }

        // If it's fresh install, we don't show the update onboarding
        guard !isFreshInstall else {
            saveAppVersion(for: appVersion)
            return false
        }

        // Version number saved in user prefs is not the same as current version
        guard !isMajorVersionUpdate(using: profile, and: appVersion) else {
            saveAppVersion(for: appVersion)
            return true
        }

        return false
    }

    // Function added to wait for AccountManager initialization to get
    // if the user is Sign in with Sync Account to decide which cards to show
    func hasSyncableAccount(completion: @escaping () -> Void) {
        profile.hasSyncAccount { result in
            self.hasSyncableAccount = result
            ensureMainThread {
                completion()
            }
        }
    }

    func hasSyncableAccount() async -> Bool {
        return await withCheckedContinuation { continuation in
            profile.hasSyncAccount { hasSync in
                self.hasSyncableAccount = hasSync
                continuation.resume(returning: hasSync)
            }
        }
    }

    func positionForCard(cardType: IntroViewModel.InformationCards) -> Int? {
        return enabledCards.firstIndex(of: cardType)
    }

    func sendCloseButtonTelemetry(index: Int) {
        let extra = [TelemetryWrapper.EventExtraKey.cardType.rawValue: enabledCards[index].telemetryValue]

        TelemetryWrapper.recordEvent(category: .action,
                                     method: .tap,
                                     object: .onboardingClose,
                                     extras: extra)
    }

    func getInfoModel(cardType: IntroViewModel.InformationCards) -> OnboardingModelProtocol? {
        switch cardType {
        case .updateWelcome:
            return OnboardingInfoModel(image: UIImage(named: ImageIdentifiers.onboardingWelcomev106),
                                       title: .Upgrade.WelcomeTitle,
                                       description: .Upgrade.WelcomeDescription,
                                       primaryAction: .Upgrade.WelcomeAction,
                                       secondaryAction: nil,
                                       a11yIdRoot: AccessibilityIdentifiers.Upgrade.welcomeCard)
        case .updateSignSync:
            return OnboardingInfoModel(image: UIImage(named: ImageIdentifiers.onboardingSyncv106),
                                       title: .Upgrade.SyncSignTitle,
                                       description: .Upgrade.SyncSignDescription,
                                       primaryAction: .Upgrade.SyncAction,
                                       secondaryAction: .Onboarding.LaterAction,
                                       a11yIdRoot: AccessibilityIdentifiers.Upgrade.signSyncCard)
        case .welcome, .signSync, .notification:
            // Cases not supported by the upgrade screen
            return nil
        }
    }

    private func saveAppVersion(for appVersion: String) {
        profile.prefs.setString(appVersion, forKey: PrefsKeys.AppVersion.Latest)
    }
}
