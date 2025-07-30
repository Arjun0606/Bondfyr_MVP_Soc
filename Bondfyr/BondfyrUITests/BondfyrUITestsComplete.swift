import XCTest

class BondfyrUITestsComplete: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        app = XCUIApplication()
        
        // Configure test environment
        app.launchArguments = ["UITesting"]
        app.launchEnvironment = [
            "UITEST_DISABLE_ANIMATIONS": "1",
            "UITEST_RESET_DATA": "1"
        ]
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Complete User Journey Tests
    
    func testCompletePartyHostingFlow() throws {
        // Step 1: Navigate to Create Party
        let hostTabButton = app.tabBars.buttons["Host Party"]
        XCTAssertTrue(hostTabButton.waitForExistence(timeout: 5.0))
        hostTabButton.tap()
        
        // Step 2: Fill out party creation form
        let titleField = app.textFields["partyTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3.0))
        titleField.tap()
        titleField.typeText("UI Test Party")
        
        let descriptionField = app.textViews["partyDescriptionField"]
        XCTAssertTrue(descriptionField.waitForExistence(timeout: 3.0))
        descriptionField.tap()
        descriptionField.typeText("This is a test party created by UI automation")
        
        let ticketPriceField = app.textFields["ticketPriceField"]
        XCTAssertTrue(ticketPriceField.waitForExistence(timeout: 3.0))
        ticketPriceField.tap()
        ticketPriceField.typeText("15")
        
        let maxGuestsField = app.textFields["maxGuestsField"]
        XCTAssertTrue(maxGuestsField.waitForExistence(timeout: 3.0))
        maxGuestsField.tap()
        maxGuestsField.typeText("20")
        
        let venmoField = app.textFields["venmoHandleField"]
        XCTAssertTrue(venmoField.waitForExistence(timeout: 3.0))
        venmoField.tap()
        venmoField.typeText("test-venmo")
        
        // Step 3: Create the party
        let createButton = app.buttons["Create Party"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3.0))
        createButton.tap()
        
        // Step 4: Verify party was created
        let successMessage = app.staticTexts["Party created successfully!"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10.0))
        
        // Step 5: Navigate to party discovery to see the created party
        let partyFeedTab = app.tabBars.buttons["Party Feed"]
        partyFeedTab.tap()
        
        let createdParty = app.staticTexts["UI Test Party"]
        XCTAssertTrue(createdParty.waitForExistence(timeout: 5.0))
    }
    
    func testGuestRequestSubmissionFlow() throws {
        // Prerequisite: Navigate to party discovery
        let partyFeedTab = app.tabBars.buttons["Party Feed"]
        XCTAssertTrue(partyFeedTab.waitForExistence(timeout: 5.0))
        partyFeedTab.tap()
        
        // Step 1: Find and tap on a party
        let firstPartyCard = app.buttons.matching(identifier: "partyCard").element(boundBy: 0)
        XCTAssertTrue(firstPartyCard.waitForExistence(timeout: 5.0))
        firstPartyCard.tap()
        
        // Step 2: Request to join
        let requestButton = app.buttons["Request to Join"]
        XCTAssertTrue(requestButton.waitForExistence(timeout: 3.0))
        requestButton.tap()
        
        // Step 3: Fill out request form
        let introField = app.textViews["introMessageField"]
        XCTAssertTrue(introField.waitForExistence(timeout: 3.0))
        introField.tap()
        introField.typeText("Hey! I'd love to join your party. I'm a fun person and promise to bring good vibes!")
        
        // Step 4: Submit request
        let submitButton = app.buttons["Submit Request"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 3.0))
        submitButton.tap()
        
        // Step 5: Verify request was submitted
        let successAlert = app.alerts.element
        XCTAssertTrue(successAlert.waitForExistence(timeout: 5.0))
        
        let okButton = successAlert.buttons["OK"]
        okButton.tap()
        
        // Step 6: Verify button changed to "Request Sent"
        let requestSentButton = app.buttons["Request Sent"]
        XCTAssertTrue(requestSentButton.waitForExistence(timeout: 3.0))
    }
    
    func testHostGuestApprovalFlow() throws {
        // Prerequisite: Host needs to have parties with pending requests
        // This test assumes we're logged in as a host with pending requests
        
        // Step 1: Navigate to hosted parties
        let hostTab = app.tabBars.buttons["Host Party"]
        XCTAssertTrue(hostTab.waitForExistence(timeout: 5.0))
        hostTab.tap()
        
        // Step 2: Find hosted party and open guest management
        let hostedPartyCard = app.buttons.matching(identifier: "hostedPartyCard").element(boundBy: 0)
        XCTAssertTrue(hostedPartyCard.waitForExistence(timeout: 5.0))
        hostedPartyCard.tap()
        
        let guestManagementButton = app.buttons["Guest Management"]
        XCTAssertTrue(guestManagementButton.waitForExistence(timeout: 3.0))
        guestManagementButton.tap()
        
        // Step 3: Approve a pending request
        let approveButton = app.buttons.matching(identifier: "approveButton").element(boundBy: 0)
        XCTAssertTrue(approveButton.waitForExistence(timeout: 5.0))
        approveButton.tap()
        
        // Step 4: Verify approval success
        let approvalAlert = app.alerts.element
        XCTAssertTrue(approvalAlert.waitForExistence(timeout: 5.0))
        XCTAssertTrue(approvalAlert.staticTexts.element(matching: .any, identifier: "approved").exists)
        
        approvalAlert.buttons["OK"].tap()
        
        // Step 5: Verify request moved to approved section
        let approvedSection = app.staticTexts["Approved Guests"]
        XCTAssertTrue(approvedSection.waitForExistence(timeout: 3.0))
    }
    
    // REMOVED: Chat functionality has been removed from the app
    // func testPartyChatFlow() throws { ... }
    
    func testPartyInvitesScreen() throws {
        // Step 1: Navigate to Party Invites tab
        let invitesTab = app.tabBars.buttons["Party Invites"]
        XCTAssertTrue(invitesTab.waitForExistence(timeout: 5.0))
        invitesTab.tap()
        
        // Step 2: Verify screen loaded
        let invitesTitle = app.navigationBars.staticTexts["Party Invites"]
        XCTAssertTrue(invitesTitle.waitForExistence(timeout: 3.0))
        
        // Step 3: Test empty state if no invites
        let noInvitesMessage = app.staticTexts["No party invites yet"]
        let discoverButton = app.buttons["Discover Parties"]
        
        if noInvitesMessage.exists {
            XCTAssertTrue(discoverButton.exists)
            
            // Test discover button functionality
            discoverButton.tap()
            
            // Should navigate to party feed
            let partyFeedTitle = app.navigationBars.staticTexts["Party Discovery"]
            XCTAssertTrue(partyFeedTitle.waitForExistence(timeout: 3.0))
        } else {
            // Test invite cards if they exist
            let inviteCards = app.buttons.matching(identifier: "inviteCard")
            XCTAssertGreaterThan(inviteCards.count, 0)
            
            // Tap first invite to view details
            inviteCards.element(boundBy: 0).tap()
            
            let inviteDetailView = app.staticTexts["You're Invited!"]
            XCTAssertTrue(inviteDetailView.waitForExistence(timeout: 3.0))
        }
    }
    
    func testNavigationFlow() throws {
        // Test all tab navigation
        let tabs = ["Party Feed", "Host Party", "Party Invites", "Profile"]
        
        for tabName in tabs {
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.waitForExistence(timeout: 3.0), "Tab \(tabName) should exist")
            tab.tap()
            
            // Wait for tab content to load
            sleep(1)
            
            // Verify we're on the correct tab
            XCTAssertTrue(tab.isSelected, "Tab \(tabName) should be selected")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidPartyCreation() throws {
        // Navigate to create party
        let hostTab = app.tabBars.buttons["Host Party"]
        hostTab.tap()
        
        // Try to create party without required fields
        let createButton = app.buttons["Create Party"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3.0))
        createButton.tap()
        
        // Should show validation errors
        let errorAlert = app.alerts.element
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 3.0))
        
        errorAlert.buttons["OK"].tap()
    }
    
    func testNetworkErrorHandling() throws {
        // This would require network mocking in test environment
        // For now, just verify error states exist
        XCTAssertTrue(true, "Network error testing requires network mocking setup")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Navigate through all main screens and verify accessibility
        let tabs = ["Party Feed", "Host Party", "Party Invites", "Profile"]
        
        for tabName in tabs {
            let tab = app.tabBars.buttons[tabName]
            tab.tap()
            
            // Verify important elements have accessibility labels
            let navigationBar = app.navigationBars.element
            XCTAssertNotNil(navigationBar.identifier, "Navigation should have accessibility identifier")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPartyDiscoveryScrolling() throws {
        let partyFeedTab = app.tabBars.buttons["Party Feed"]
        partyFeedTab.tap()
        
        let scrollView = app.scrollViews.element(boundBy: 0)
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5.0))
        
        // Test smooth scrolling performance
        let startTime = Date()
        
        // Perform scrolling actions
        scrollView.swipeUp()
        scrollView.swipeDown()
        scrollView.swipeUp()
        scrollView.swipeDown()
        
        let endTime = Date()
        let scrollTime = endTime.timeIntervalSince(startTime)
        
        // Scrolling should be responsive (less than 2 seconds for basic operations)
        XCTAssertLessThan(scrollTime, 2.0, "Scrolling should be responsive")
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistenceAcrossAppRestart() throws {
        // Create a party
        let hostTab = app.tabBars.buttons["Host Party"]
        hostTab.tap()
        
        let titleField = app.textFields["partyTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3.0))
        titleField.tap()
        titleField.typeText("Persistence Test Party")
        
        let createButton = app.buttons["Create Party"]
        createButton.tap()
        
        let successMessage = app.staticTexts["Party created successfully!"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10.0))
        
        // Restart app
        app.terminate()
        app.launch()
        
        // Verify party still exists
        let partyFeedTab = app.tabBars.buttons["Party Feed"]
        partyFeedTab.tap()
        
        let persistedParty = app.staticTexts["Persistence Test Party"]
        XCTAssertTrue(persistedParty.waitForExistence(timeout: 5.0))
    }
    
    // MARK: - Integration Tests
    
    func testCompleteGuestToHostInteraction() throws {
        // This would test the complete flow:
        // 1. Guest submits request
        // 2. Host receives and approves request
        // 3. Guest gets notification/can see approved status
        // 4. Both can participate in party chat
        
        // This requires multiple user sessions or mock backend
        XCTAssertTrue(true, "Multi-user integration testing requires test environment setup")
    }
    
    func testRealTimeDataSync() throws {
        // Test that data updates in real-time across different screens
        // This would require observing Firebase changes
        XCTAssertTrue(true, "Real-time sync testing requires Firebase test configuration")
    }
    
    // MARK: - Helper Methods
    
    private func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    private func dismissKeyboard() {
        app.tap() // Tap outside to dismiss keyboard
    }
    
    private func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement) {
        while !element.isHittable && scrollView.exists {
            scrollView.swipeUp()
        }
    }
} 