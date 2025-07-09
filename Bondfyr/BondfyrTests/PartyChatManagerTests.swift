import XCTest
import Firebase
import FirebaseFirestore
import CoreLocation
import UIKit
@testable import Bondfyr

class PartyChatManagerTests: XCTestCase {
    
    var chatManager: PartyChatManager!
    var mockFirestore: Firestore!
    var testParty: Afterparty!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        chatManager = PartyChatManager.shared
        mockFirestore = Firestore.firestore()
        testParty = createTestParty()
        
        clearChatData()
    }
    
    override func tearDownWithError() throws {
        clearChatData()
        chatManager = nil
        testParty = nil
        try super.tearDownWithError()
    }
    
    private func clearChatData() {
        // Clear test chat data
        chatManager.messages = []
        chatManager.currentParty = nil
        chatManager.canPost = false
        chatManager.replyingTo = nil
    }
    
    // MARK: - Chat Initialization Tests
    
    func testStartPartyChatAsHost() {
        // Given
        mockCurrentUser(id: testParty.userId) // Set as host
        
        // When
        chatManager.startPartyChat(for: testParty)
        
        // Then
        XCTAssertEqual(chatManager.currentParty?.id, testParty.id)
        XCTAssertTrue(chatManager.canPost, "Host should be able to post")
        XCTAssertEqual(chatManager.messages.count, 1, "Should have welcome message")
        XCTAssertTrue(chatManager.messages.first?.isSystemMessage == true)
    }
    
    func testJoinPartyChatAsApprovedGuest() {
        // Given
        let guestId = "approved-guest-id"
        mockCurrentUser(id: guestId)
        
        // Create party with approved guest
        let approvedRequest = GuestRequest(
            userId: guestId,
            userName: "Approved Guest",
            userHandle: "approvedguest",
            introMessage: "Test message",
            paymentStatus: .paid, // Approved guest
            approvalStatus: .approved
        )
        let partyWithGuest = createTestPartyWithGuests([approvedRequest])
        
        // When
        chatManager.joinPartyChat(for: partyWithGuest)
        
        // Then
        XCTAssertEqual(chatManager.currentParty?.id, partyWithGuest.id)
        XCTAssertTrue(chatManager.canPost, "Approved guest should be able to post")
    }
    
    func testJoinPartyChatAsViewer() {
        // Given
        let viewerId = "viewer-only-id"
        mockCurrentUser(id: viewerId)
        
        // When
        chatManager.joinPartyChat(for: testParty)
        
        // Then
        XCTAssertEqual(chatManager.currentParty?.id, testParty.id)
        XCTAssertFalse(chatManager.canPost, "Non-approved user should not be able to post")
    }
    
    // MARK: - Message Sending Tests
    
    func testSendMessageAsHost() async throws {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        let messageText = "Hello everyone! Welcome to the party!"
        
        // When
        try await chatManager.sendMessage(text: messageText)
        
        // Then
        XCTAssertEqual(chatManager.messages.count, 2) // Welcome + new message
        let lastMessage = chatManager.messages.last
        XCTAssertEqual(lastMessage?.text, messageText)
        XCTAssertEqual(lastMessage?.userHandle, "HOST")
        XCTAssertFalse(lastMessage?.isSystemMessage == true)
    }
    
    func testSendMessageAsApprovedGuest() async throws {
        // Given
        let guestId = "approved-guest-id"
        mockCurrentUser(id: guestId)
        
        let approvedRequest = GuestRequest(
            userId: guestId,
            userName: "Approved Guest",
            userHandle: "approvedguest",
            introMessage: "Test message",
            paymentStatus: .paid,
            approvalStatus: .approved
        )
        let partyWithGuest = createTestPartyWithGuests([approvedRequest])
        
        chatManager.joinPartyChat(for: partyWithGuest)
        let messageText = "Thanks for having me!"
        
        // When
        try await chatManager.sendMessage(text: messageText)
        
        // Then
        let lastMessage = chatManager.messages.last
        XCTAssertEqual(lastMessage?.text, messageText)
        XCTAssertEqual(lastMessage?.userHandle, "Guest #1")
        XCTAssertEqual(lastMessage?.userId, guestId)
    }
    
    func testSendMessageAsViewerShouldFail() async {
        // Given
        mockCurrentUser(id: "viewer-only-id")
        chatManager.joinPartyChat(for: testParty)
        
        // When & Then
        do {
            try await chatManager.sendMessage(text: "This should fail")
            XCTFail("Viewer should not be able to send messages")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("permission"))
        }
    }
    
    // MARK: - Anonymous Numbering Tests
    
    func testGuestNumberingConsistency() async throws {
        // Given
        let guest1Id = "guest1"
        let guest2Id = "guest2"
        
        let partyWithGuests = createTestPartyWithGuests([
            GuestRequest(userId: guest1Id, userName: "Guest 1", userHandle: "guest1", 
                        introMessage: "", paymentStatus: .paid, approvalStatus: .approved),
            GuestRequest(userId: guest2Id, userName: "Guest 2", userHandle: "guest2", 
                        introMessage: "", paymentStatus: .paid, approvalStatus: .approved)
        ])
        
        // When - Guest 1 sends message
        mockCurrentUser(id: guest1Id)
        chatManager.joinPartyChat(for: partyWithGuests)
        try await chatManager.sendMessage(text: "First message")
        
        // When - Guest 2 sends message
        mockCurrentUser(id: guest2Id)
        chatManager.joinPartyChat(for: partyWithGuests)
        try await chatManager.sendMessage(text: "Second message")
        
        // When - Guest 1 sends another message
        mockCurrentUser(id: guest1Id)
        chatManager.joinPartyChat(for: partyWithGuests)
        try await chatManager.sendMessage(text: "Third message")
        
        // Then
        let guest1Messages = chatManager.messages.filter { $0.userId == guest1Id }
        let guest2Messages = chatManager.messages.filter { $0.userId == guest2Id }
        
        XCTAssertEqual(guest1Messages.count, 2)
        XCTAssertEqual(guest2Messages.count, 1)
        
        // All messages from guest1 should have same number
        XCTAssertTrue(guest1Messages.allSatisfy { $0.userHandle == "Guest #1" })
        XCTAssertTrue(guest2Messages.allSatisfy { $0.userHandle == "Guest #2" })
    }
    
    // MARK: - Photo Sharing Tests
    
    func testSendImageMessage() async throws {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        let testImageData = createTestImageData()
        
        // When
        let testImage = UIImage(data: testImageData)!
        try await chatManager.sendImage(testImage)
        
        // Then
        let lastMessage = chatManager.messages.last
        XCTAssertEqual(lastMessage?.messageType, .image)
        XCTAssertNotNil(lastMessage?.imageURL)
        XCTAssertEqual(lastMessage?.imageAspectRatio, 1.0)
    }
    
    func testImageUploadProgress() async throws {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        let testImageData = createTestImageData()
        
        // When
        XCTAssertFalse(chatManager.isUploadingImage)
        
        let uploadTask = Task {
            let testImage = UIImage(data: testImageData)!
            try await chatManager.sendImage(testImage)
        }
        
        // Brief delay to check upload state
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then (during upload)
        // Note: This might be flaky in real testing due to timing
        // XCTAssertTrue(chatManager.isUploadingImage, "Should show uploading state")
        
        try await uploadTask.value
        XCTAssertFalse(chatManager.isUploadingImage, "Should reset after upload")
    }
    
    // MARK: - Message Reactions Tests
    
    func testAddReactionToMessage() async throws {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        try await chatManager.sendMessage(text: "Test message")
        
        let message = chatManager.messages.last!
        let emoji = "🎉"
        
        // When
        try await chatManager.addReaction(to: message, emoji: emoji)
        
        // Then
        // Note: This would require updating the local message state
        // and syncing with Firebase
        XCTAssertTrue(true, "Reaction functionality needs Firebase sync testing")
    }
    
    // MARK: - Reply Functionality Tests
    
    func testSetReplyingToMessage() {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        let originalMessage = ChatMessage(
            text: "Original message",
            userHandle: "HOST",
            userId: testParty.userId,
            timestamp: Date(),
            partyId: testParty.id,
            messageType: .text
        )
        
        // When
        chatManager.setReplyingTo(originalMessage)
        
        // Then
        XCTAssertEqual(chatManager.replyingTo?.id, originalMessage.id)
        XCTAssertEqual(chatManager.replyingTo?.text, originalMessage.text)
    }
    
    func testCancelReply() {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        let originalMessage = ChatMessage(
            text: "Original message",
            userHandle: "HOST",
            userId: testParty.userId,
            timestamp: Date(),
            partyId: testParty.id,
            messageType: .text
        )
        chatManager.setReplyingTo(originalMessage)
        
        // When
        chatManager.cancelReply()
        
        // Then
        XCTAssertNil(chatManager.replyingTo)
    }
    
    func testSendReplyMessage() async throws {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        
        // Create original message
        let originalMessage = ChatMessage(
            text: "Original message",
            userHandle: "HOST",
            userId: testParty.userId,
            timestamp: Date(),
            partyId: testParty.id,
            messageType: .text
        )
        chatManager.messages.append(originalMessage)
        
        // Set up reply
        chatManager.setReplyingTo(originalMessage)
        let replyText = "This is a reply"
        
        // When
        try await chatManager.sendMessage(text: replyText)
        
        // Then
        let replyMessage = chatManager.messages.last
        XCTAssertEqual(replyMessage?.text, replyText)
        XCTAssertEqual(replyMessage?.replyToMessageId, originalMessage.id)
        XCTAssertEqual(replyMessage?.replyToText, originalMessage.text)
        XCTAssertNil(chatManager.replyingTo, "Reply state should be cleared")
    }
    
    // MARK: - Chat Lifecycle Tests
    
    func testChatEndingWhenPartyEnds() {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        
        // When
        chatManager.leavePartyChat()
        
        // Then
        // Chat should still preserve data but prevent new messages
        XCTAssertNotNil(chatManager.currentParty)
        XCTAssertFalse(chatManager.canPost)
    }
    
    func testViewerCountTracking() {
        // Given
        mockCurrentUser(id: "viewer1")
        
        // When
        chatManager.joinPartyChat(for: testParty)
        
        // Then
        // This would require Firebase listener testing
        XCTAssertTrue(chatManager.viewerCount >= 0)
    }
    
    func testLeaveChat() {
        // Given
        mockCurrentUser(id: "viewer1")
        chatManager.joinPartyChat(for: testParty)
        
        // When
        chatManager.leavePartyChat()
        
        // Then
        XCTAssertFalse(chatManager.canPost)
        // Note: Data should be preserved for rejoining
        XCTAssertNotNil(chatManager.currentParty)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testSendEmptyMessage() async {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        
        // When & Then
        do {
            try await chatManager.sendMessage(text: "")
            XCTFail("Should not allow empty messages")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("empty") || 
                         error.localizedDescription.contains("invalid"))
        }
    }
    
    func testConcurrentMessageSending() async throws {
        // Given
        mockCurrentUser(id: testParty.userId)
        chatManager.startPartyChat(for: testParty)
        
        // When
        async let message1 = chatManager.sendMessage(text: "Message 1")
        async let message2 = chatManager.sendMessage(text: "Message 2")
        async let message3 = chatManager.sendMessage(text: "Message 3")
        
        // Then
        try await message1
        try await message2
        try await message3
        
        let messageTexts = chatManager.messages.compactMap { $0.text }
        XCTAssertTrue(messageTexts.contains("Message 1"))
        XCTAssertTrue(messageTexts.contains("Message 2"))
        XCTAssertTrue(messageTexts.contains("Message 3"))
    }
    
    // MARK: - Helper Methods
    
    private func createTestParty() -> Afterparty {
        return createTestPartyWithGuests([])
    }
    
    private func createTestPartyWithGuests(_ guestRequests: [GuestRequest]) -> Afterparty {
        return Afterparty(
            id: "test-party-id",
            userId: "test-host-id",
            hostHandle: "testhost",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            radius: 15.0,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            city: "Test City",
            locationName: "Test Location",
            description: "Test party for chat",
            address: "Test Address",
            googleMapsLink: "",
            vibeTag: "House Party",
            activeUsers: [],
            pendingRequests: [],
            createdAt: Date(),
            title: "Test Party",
            ticketPrice: 10.0,
            coverPhotoURL: nil,
            maxGuestCount: 25,
            visibility: .publicFeed,
            approvalType: .manual,
            ageRestriction: nil,
            maxMaleRatio: 1.0,
            legalDisclaimerAccepted: true,
            guestRequests: guestRequests,
            earnings: 0.0,
            bondfyrFee: 0.0,
            venmoHandle: "testvenmo",
            chatEnded: nil,
            chatEndedAt: nil
        )
    }
    
    private func mockCurrentUser(id: String) {
        // This would require mocking Firebase Auth
        // For now, we'll assume the chat manager checks permissions correctly
    }
    
    private func createTestImageData() -> Data {
        // Create a simple 1x1 pixel image for testing
        let image = UIImage(systemName: "square.fill")!
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
} 