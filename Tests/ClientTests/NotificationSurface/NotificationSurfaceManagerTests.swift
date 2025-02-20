// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest
import Shared
import Common
@testable import Client

class NotificationSurfaceManagerTests: XCTestCase {
    private var messageManager: MockGleanPlumbMessageManagerProtocol!
    private var notificationManager: MockNotificationManager!
    private var notificationCenter: MockNotificationCenter!

    override func setUp() {
        super.setUp()
        DependencyHelperMock().bootstrapDependencies()
        notificationManager = MockNotificationManager()
        notificationCenter = MockNotificationCenter()
        messageManager = MockGleanPlumbMessageManagerProtocol()
    }

    override func tearDown() {
        super.tearDown()
        messageManager = nil
        notificationManager = nil
        notificationCenter = nil
    }

    func testShouldShowSurface_noMessage() {
        let subject = createSubject()

        XCTAssertFalse(subject.shouldShowSurface)
    }

    func testShouldShowSurface_expiredMessage() {
        let subject = createSubject()
        let message = createMessage(isExpired: true)
        messageManager.message = message

        XCTAssertFalse(subject.shouldShowSurface)
    }

    func testShouldShowSurface_validMessage() {
        let subject = createSubject()
        let message = createMessage(isExpired: false)
        messageManager.message = message

        XCTAssertTrue(subject.shouldShowSurface)
    }

    func testShowSurface_noMessage() {
        let subject = createSubject()

        XCTAssertFalse(subject.shouldShowSurface)

        subject.showNotificationSurface()

        XCTAssertFalse(notificationManager.scheduleWithIntervalWasCalled)
        XCTAssertEqual(notificationManager.scheduledNotifications, 0)
    }

    func testShowSurface_expiredMessage() {
        let subject = createSubject()
        let message = createMessage(isExpired: true)
        messageManager.message = message

        XCTAssertFalse(subject.shouldShowSurface)

        subject.showNotificationSurface()

        XCTAssertFalse(notificationManager.scheduleWithIntervalWasCalled)
        XCTAssertEqual(notificationManager.scheduledNotifications, 0)
    }

    func testShowSurface_validMessage() {
        let subject = createSubject()
        let message = createMessage(isExpired: false)
        messageManager.message = message

        XCTAssertTrue(subject.shouldShowSurface)

        subject.showNotificationSurface()

        XCTAssertTrue(notificationManager.scheduleWithIntervalWasCalled)
        XCTAssertEqual(notificationManager.scheduledNotifications, 1)
    }

    func testDidTapNotification_noMessageId() {
        let subject = createSubject()
        subject.didTapNotification([:])

        XCTAssertEqual(notificationCenter.postCallCount, 0)
    }

    func testDidTapNotification_noMessageFound() {
        let subject = createSubject()
        subject.didTapNotification([NotificationSurfaceManager.Constant.messageIdKey: "test"])

        XCTAssertEqual(notificationCenter.postCallCount, 0)
    }

    func testDidTapNotification_openNewTabAction() {
        let subject = createSubject()
        let message = createMessage(isExpired: false)
        messageManager.message = message

        XCTAssertTrue(subject.shouldShowSurface)

        subject.didTapNotification([NotificationSurfaceManager.Constant.messageIdKey: "test-notification"])

        XCTAssertEqual(notificationCenter.postCallCount, 1)
    }

    func testDidTapNotification_defaultAction() {
        let subject = createSubject()
        let message = createMessage(isExpired: false, action: "test-action")
        messageManager.message = message

        XCTAssertTrue(subject.shouldShowSurface)

        subject.didTapNotification([NotificationSurfaceManager.Constant.messageIdKey: "test-notification"])

        XCTAssertEqual(notificationCenter.postCallCount, 0)
    }

    // MARK: Helpers
    private func createSubject(file: StaticString = #file,
                               line: UInt = #line
    ) -> NotificationSurfaceManager {
        let subject = NotificationSurfaceManager(messagingManager: messageManager,
                                                 notificationManager: notificationManager,
                                                 notificationCenter: notificationCenter)
        trackForMemoryLeaks(subject, file: file, line: line)
        return subject
    }

    private func createMessage(
        for surface: MessageSurfaceId = .notification,
        isExpired: Bool,
        action: String = "OPEN_NEW_TAB"
    ) -> GleanPlumbMessage {
        let metadata = GleanPlumbMessageMetaData(id: "",
                                                 impressions: 0,
                                                 dismissals: 0,
                                                 isExpired: isExpired)

        return GleanPlumbMessage(id: "test-notification",
                                 data: MockNotificationMessageDataProtocol(surface: surface),
                                 action: action,
                                 triggers: [],
                                 style: MockStyleDataProtocol(),
                                 metadata: metadata)
    }

    private func createEngagementMessage(for surface: MessageSurfaceId = .notification) -> GleanPlumbMessage {
        let metadata = GleanPlumbMessageMetaData(id: "",
                                                 impressions: 0,
                                                 dismissals: 0,
                                                 isExpired: false)

        return GleanPlumbMessage(id: "test-notification",
                                 data: MockNotificationMessageDataProtocol(surface: surface),
                                 action: "OPEN_NEW_TAB",
                                 triggers: ["INACTIVE_NEW_USER", "ALLOWED_TIPS_NOTIFICATIONS"],
                                 style: MockStyleDataProtocol(),
                                 metadata: metadata)
    }
}

// MARK: - MockNotificationMessageDataProtocol
class MockNotificationMessageDataProtocol: MessageDataProtocol {
    var surface: MessageSurfaceId
    var isControl = true
    var title: String? = "title label test"
    var text: String = "text label test"
    var buttonLabel: String? = "button label test"

    init(surface: MessageSurfaceId = .notification) {
        self.surface = surface
    }
}
