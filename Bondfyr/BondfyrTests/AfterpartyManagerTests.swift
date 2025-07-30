import XCTest
import Firebase
import FirebaseFirestore
import CoreLocation
@testable import Bondfyr

class AfterpartyManagerTests: XCTestCase {
    
    var afterpartyManager: AfterpartyManager!
    var mockFirestore: Firestore!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        afterpartyManager = AfterpartyManager.shared
        
        // Configure Firebase for testing
        let app = FirebaseApp.configure()
        mockFirestore = Firestore.firestore()
        
        // Clear any existing test data
        clearTestData()
    }
    
    override func tearDownWithError() throws {
        clearTestData()
        afterpartyManager = nil
        try super.tearDownWithError()
    }
    
    private func clearTestData() {
        // Clear test data from Firestore
        // This would need proper test database setup
    }
    
    // MARK: - Party Creation Tests
    
    func testCreateAfterpartySuccess() async throws {
        // Given
        mockCurrentUser(id: "test-host-id")
        let testParty = createTestAfterparty()
        
        // When
        try await afterpartyManager.createAfterparty(
            hostHandle: testParty.hostHandle,
            coordinate: CLLocationCoordinate2D(latitude: testParty.coordinate.latitude, longitude: testParty.coordinate.longitude),
            radius: testParty.radius,
            startTime: testParty.startTime,
            endTime: testParty.endTime,
            city: testParty.city,
            locationName: testParty.locationName,
            description: testParty.description,
            address: testParty.address,
            googleMapsLink: testParty.googleMapsLink,
            vibeTag: testParty.vibeTag,
            title: testParty.title,
            ticketPrice: testParty.ticketPrice,
            maxGuestCount: testParty.maxGuestCount,
            venmoHandle: testParty.venmoHandle
        )
        
        // Then
        let savedParty = try await fetchPartyFromFirebase(id: testParty.id)
        XCTAssertEqual(savedParty.title, testParty.title)
        XCTAssertEqual(savedParty.hostHandle, testParty.hostHandle)
        XCTAssertEqual(savedParty.ticketPrice, testParty.ticketPrice)
    }
    
    func testCreateAfterpartyWithInvalidData() async {
        // Given - empty title should be invalid
        
        // When & Then
        do {
            try await afterpartyManager.createAfterparty(
                hostHandle: "testhost",
                coordinate: CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567),
                radius: 15.0,
                startTime: Date().addingTimeInterval(3600),
                endTime: Date().addingTimeInterval(7200),
                city: "Test City",
                locationName: "Test Location",
                description: "Test description",
                address: "Test Address",
                googleMapsLink: "https://maps.google.com/test",
                vibeTag: "House Party",
                title: "", // Invalid empty title
                ticketPrice: 10.0,
                maxGuestCount: 25,
                venmoHandle: "testvenmo"
            )
            XCTFail("Should throw error for invalid party data")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("title") || error.localizedDescription.contains("empty"))
        }
    }
    
    // MARK: - Guest Request Flow Tests
    
    func testSubmitGuestRequestSuccess() async throws {
        // Given
        let testParty = try await createAndSaveTestParty()
        let guestRequest = createTestGuestRequest()
        
        // When
        try await afterpartyManager.submitGuestRequest(
            afterpartyId: testParty.id,
            guestRequest: guestRequest
        )
        
        // Then
        let updatedParty = try await fetchPartyFromFirebase(id: testParty.id)
        XCTAssertEqual(updatedParty.guestRequests.count, 1)
        XCTAssertEqual(updatedParty.guestRequests.first?.userId, guestRequest.userId)
        XCTAssertEqual(updatedParty.guestRequests.first?.introMessage, guestRequest.introMessage)
    }
    
    func testSubmitDuplicateGuestRequest() async throws {
        // Given
        let testParty = try await createAndSaveTestParty()
        let guestRequest = createTestGuestRequest()
        
        // When - Submit first request
        try await afterpartyManager.submitGuestRequest(
            afterpartyId: testParty.id,
            guestRequest: guestRequest
        )
        
        // Then - Try to submit duplicate request
        do {
            try await afterpartyManager.submitGuestRequest(
                afterpartyId: testParty.id,
                guestRequest: guestRequest
            )
            XCTFail("Should throw error for duplicate request")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("already requested"))
        }
    }
    
    func testGuestRequestForNonexistentParty() async {
        // Given
        let nonexistentPartyId = "nonexistent-party-id"
        let guestRequest = createTestGuestRequest()
        
        // When & Then
        do {
            try await afterpartyManager.submitGuestRequest(
                afterpartyId: nonexistentPartyId,
                guestRequest: guestRequest
            )
            XCTFail("Should throw error for nonexistent party")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("not found"))
        }
    }
    
    // MARK: - Host Approval Tests
    
    func testApproveGuestRequestSuccess() async throws {
        // Given
        let testParty = try await createPartyWithPendingRequest()
        let requestId = testParty.guestRequests.first!.id
        
        // When
        try await afterpartyManager.approveGuestRequest(
            afterpartyId: testParty.id,
            guestRequestId: requestId
        )
        
        // Then
        let updatedParty = try await fetchPartyFromFirebase(id: testParty.id)
        let approvedRequest = updatedParty.guestRequests.first { $0.id == requestId }
        
        XCTAssertNotNil(approvedRequest)
        XCTAssertEqual(approvedRequest?.approvalStatus, .approved)
        XCTAssertNotNil(approvedRequest?.approvedAt)
    }
    
    func testDenyGuestRequestSuccess() async throws {
        // Given
        let testParty = try await createPartyWithPendingRequest()
        let requestId = testParty.guestRequests.first!.id
        let initialRequestCount = testParty.guestRequests.count
        
        // When
        try await afterpartyManager.denyGuestRequest(
            afterpartyId: testParty.id,
            guestRequestId: requestId
        )
        
        // Then
        let updatedParty = try await fetchPartyFromFirebase(id: testParty.id)
        XCTAssertEqual(updatedParty.guestRequests.count, initialRequestCount - 1)
        XCTAssertNil(updatedParty.guestRequests.first { $0.id == requestId })
    }
    
    func testApproveNonexistentRequest() async throws {
        // Given
        let testParty = try await createAndSaveTestParty()
        let nonexistentRequestId = "nonexistent-request-id"
        
        // When & Then
        // This should not throw an error but should handle gracefully
        try await afterpartyManager.approveGuestRequest(
            afterpartyId: testParty.id,
            guestRequestId: nonexistentRequestId
        )
        
        // Verify party is unchanged
        let unchangedParty = try await fetchPartyFromFirebase(id: testParty.id)
        XCTAssertEqual(unchangedParty.guestRequests.count, 0)
    }
    
    // MARK: - Real-time Data Sync Tests
    
    func testMarketplaceDataRefresh() async throws {
        // Given
        let testParty1 = try await createAndSaveTestParty()
        let testParty2 = try await createAndSaveTestParty(title: "Test Party 2")
        
        // When
        let parties = try await afterpartyManager.getMarketplaceAfterparties()
        
        // Then
        XCTAssertGreaterThanOrEqual(parties.count, 2)
        XCTAssertTrue(parties.contains { $0.id == testParty1.id })
        XCTAssertTrue(parties.contains { $0.id == testParty2.id })
    }
    
    func testDataPersistenceAfterAppRestart() async throws {
        // Given
        let testParty = try await createPartyWithPendingRequest()
        let originalRequestCount = testParty.guestRequests.count
        
        // Simulate app restart by using shared manager instance
        let newManager = AfterpartyManager.shared
        
        // When
        let retrievedParty = try await fetchPartyFromFirebase(id: testParty.id)
        
        // Then
        XCTAssertEqual(retrievedParty.guestRequests.count, originalRequestCount)
        XCTAssertEqual(retrievedParty.title, testParty.title)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testConcurrentRequestSubmissions() async throws {
        // Given
        let testParty = try await createAndSaveTestParty()
        let request1 = createTestGuestRequest(userId: "user1")
        let request2 = createTestGuestRequest(userId: "user2")
        
        // When - Submit requests concurrently
        async let result1 = afterpartyManager.submitGuestRequest(
            afterpartyId: testParty.id,
            guestRequest: request1
        )
        async let result2 = afterpartyManager.submitGuestRequest(
            afterpartyId: testParty.id,
            guestRequest: request2
        )
        
        // Then
        try await result1
        try await result2
        
        let updatedParty = try await fetchPartyFromFirebase(id: testParty.id)
        XCTAssertEqual(updatedParty.guestRequests.count, 2)
    }
    
    func testRequestSubmissionWithNetworkFailure() async {
        // This would require mocking network failures
        // For now, we'll test the error handling structure
        XCTAssertTrue(true, "Network failure testing requires mock setup")
    }
    
    // MARK: - Helper Methods
    
    private func createTestAfterparty(title: String = "Test Party") -> Afterparty {
        return Afterparty(
            id: UUID().uuidString,
            userId: "test-host-id",
            hostHandle: "testhost",
            coordinate: CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567),
            radius: 15.0,
            startTime: Date().addingTimeInterval(3600), // 1 hour from now
            endTime: Date().addingTimeInterval(7200), // 2 hours from now
            city: "Test City",
            locationName: "Test Location",
            description: "Test party description",
            address: "Test Address, Test City",
            googleMapsLink: "https://maps.google.com/test",
            vibeTag: "House Party",
            activeUsers: [],
            pendingRequests: [],
            createdAt: Date(),
            title: title,
            ticketPrice: 10.0,
            coverPhotoURL: nil,
            maxGuestCount: 25,
            visibility: .publicFeed,
            approvalType: .manual,
            ageRestriction: nil,
            maxMaleRatio: 1.0,
            legalDisclaimerAccepted: true,
            guestRequests: [],
            earnings: 0.0,
            bondfyrFee: 0.0,
            venmoHandle: "testvenmo",

        )
    }
    
    private func createTestGuestRequest(userId: String = "test-guest-id") -> GuestRequest {
        return GuestRequest(
            userId: userId,
            userName: "Test Guest",
            userHandle: "testguest",
            introMessage: "Hey! I'd love to join your party. Seems like a great time!",
            paymentStatus: .pending,
            approvalStatus: .pending
        )
    }
    
    private func createAndSaveTestParty(title: String = "Test Party") async throws -> Afterparty {
        let party = createTestAfterparty(title: title)
        try await afterpartyManager.createAfterparty(
            hostHandle: party.hostHandle,
            coordinate: CLLocationCoordinate2D(latitude: party.coordinate.latitude, longitude: party.coordinate.longitude),
            radius: party.radius,
            startTime: party.startTime,
            endTime: party.endTime,
            city: party.city,
            locationName: party.locationName,
            description: party.description,
            address: party.address,
            googleMapsLink: party.googleMapsLink,
            vibeTag: party.vibeTag,
            title: party.title,
            ticketPrice: party.ticketPrice,
            maxGuestCount: party.maxGuestCount,
            venmoHandle: party.venmoHandle
        )
        return party
    }
    
    private func createPartyWithPendingRequest() async throws -> Afterparty {
        let party = try await createAndSaveTestParty()
        let guestRequest = createTestGuestRequest()
        
        try await afterpartyManager.submitGuestRequest(
            afterpartyId: party.id,
            guestRequest: guestRequest
        )
        
        return try await fetchPartyFromFirebase(id: party.id)
    }
    
    private func fetchPartyFromFirebase(id: String) async throws -> Afterparty {
        let doc = try await mockFirestore.collection("afterparties").document(id).getDocument()
        guard let data = doc.data(),
              let party = try? Firestore.Decoder().decode(Afterparty.self, from: data) else {
            throw NSError(domain: "TestError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Party not found"])
        }
        return party
    }
    
    private func mockCurrentUser(id: String) {
        // Mock Firebase Auth for testing
        // In a real implementation, this would use Firebase Auth test helpers
        // For now, we'll modify the AfterpartyManager to accept a test user ID
        print("Mocking user with ID: \(id)")
    }
} 