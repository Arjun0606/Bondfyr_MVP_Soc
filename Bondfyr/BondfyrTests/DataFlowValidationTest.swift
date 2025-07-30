import XCTest
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
@testable import Bondfyr

// Simple test to validate the core data flow fixes
class DataFlowValidationTest: XCTestCase {
    var mockFirestore: Firestore!
    var afterpartyManager: AfterpartyManager!
    
    override func setUp() {
        super.setUp()
        mockFirestore = Firestore.firestore()
        afterpartyManager = AfterpartyManager.shared
    }
    
    func testApprovalFlowUpdatesActiveUsers() async throws {
        print("🚀 Testing core approval flow data synchronization...")
        
        // This test validates that when a host approves a guest request,
        // the guest is properly added to activeUsers array so they can:
        // 1. See correct party count (not 0/25)
        // 2. Access party chat
        // 3. Appear in party attendee lists
        
        let testPartyId = "test-party-validation-\(UUID().uuidString)"
        let hostUserId = "test-host-\(UUID().uuidString)"
        let guestUserId = "test-guest-\(UUID().uuidString)"
        
        // Step 1: Create a test party directly in Firestore
        let testParty = createValidTestParty(id: testPartyId, hostId: hostUserId)
        let partyData = try Firestore.Encoder().encode(testParty)
        try await mockFirestore.collection("afterparties").document(testPartyId).setData(partyData)
        print("✅ Created test party with ID: \(testPartyId)")
        
        // Step 2: Create a guest request
        let guestRequest = GuestRequest(
            userId: guestUserId,
            userName: "Test Guest",
            userHandle: "testguest",
            introMessage: "Hey, I'd love to join!",
            paymentStatus: .pending,
            approvalStatus: .pending
        )
        
        // Add guest request to party
        try await mockFirestore.collection("afterparties").document(testPartyId).updateData([
            "guestRequests": FieldValue.arrayUnion([try Firestore.Encoder().encode(guestRequest)])
        ])
        print("✅ Added guest request for user: \(guestUserId)")
        
        // Step 3: Verify party state before approval
        let partyBeforeApproval = try await fetchPartyFromFirebase(id: testPartyId)
        XCTAssertEqual(partyBeforeApproval.guestRequests.count, 1, "Should have 1 guest request")
        XCTAssertEqual(partyBeforeApproval.activeUsers.count, 0, "Should have 0 active users before approval")
        XCTAssertEqual(partyBeforeApproval.confirmedGuestsCount, 0, "Should show 0 confirmed guests")
        print("✅ Verified initial state: 0 active users, 1 pending request")
        
        // Step 4: Approve the guest request using the fixed method
        try await afterpartyManager.approveGuestRequest(
            afterpartyId: testPartyId,
            guestRequestId: guestRequest.id
        )
        print("✅ Approved guest request using AfterpartyManager")
        
        // Step 5: Verify party state after approval - THIS IS THE CRITICAL TEST
        let partyAfterApproval = try await fetchPartyFromFirebase(id: testPartyId)
        
        // Critical assertions that validate the bug fixes
        XCTAssertEqual(partyAfterApproval.activeUsers.count, 1, "CRITICAL: Should have 1 active user after approval")
        XCTAssertTrue(partyAfterApproval.activeUsers.contains(guestUserId), "CRITICAL: Guest should be in activeUsers array")
        XCTAssertEqual(partyAfterApproval.confirmedGuestsCount, 1, "CRITICAL: Should show 1 confirmed guest")
        
        // Verify the guest request was updated with approval status
        let approvedRequest = partyAfterApproval.guestRequests.first { $0.userId == guestUserId }
        XCTAssertNotNil(approvedRequest, "Guest request should still exist")
        XCTAssertEqual(approvedRequest?.approvalStatus, .approved, "Request should be marked as approved")
        XCTAssertNotNil(approvedRequest?.approvedAt, "Should have approval timestamp")
        
        print("✅ VALIDATION PASSED: Guest properly added to activeUsers")
        print("   - Active users count: \(partyAfterApproval.activeUsers.count)")
        print("   - Confirmed guests count: \(partyAfterApproval.confirmedGuestsCount)")
        print("   - Guest in activeUsers: \(partyAfterApproval.activeUsers.contains(guestUserId))")
        
        // Step 6: Test denial flow as well
        let secondGuestId = "test-guest-2-\(UUID().uuidString)"
        let secondRequest = GuestRequest(
            userId: secondGuestId,
            userName: "Second Guest",
            userHandle: "secondguest",
            introMessage: "Can I join too?",
            paymentStatus: .pending,
            approvalStatus: .pending
        )
        
        // Add second guest request
        try await mockFirestore.collection("afterparties").document(testPartyId).updateData([
            "guestRequests": FieldValue.arrayUnion([try Firestore.Encoder().encode(secondRequest)])
        ])
        
        // Approve second guest
        try await afterpartyManager.approveGuestRequest(
            afterpartyId: testPartyId,
            guestRequestId: secondRequest.id
        )
        
        // Verify both guests are active
        let partyWithTwoGuests = try await fetchPartyFromFirebase(id: testPartyId)
        XCTAssertEqual(partyWithTwoGuests.activeUsers.count, 2, "Should have 2 active users")
        XCTAssertEqual(partyWithTwoGuests.confirmedGuestsCount, 2, "Should show 2 confirmed guests")
        
        // Now deny the second guest
        try await afterpartyManager.denyGuestRequest(
            afterpartyId: testPartyId,
            guestRequestId: secondRequest.id
        )
        
        // Verify second guest was removed from activeUsers
        let partyAfterDenial = try await fetchPartyFromFirebase(id: testPartyId)
        XCTAssertEqual(partyAfterDenial.activeUsers.count, 1, "Should have 1 active user after denial")
        XCTAssertFalse(partyAfterDenial.activeUsers.contains(secondGuestId), "Denied guest should not be in activeUsers")
        XCTAssertTrue(partyAfterDenial.activeUsers.contains(guestUserId), "Original guest should still be active")
        
        print("✅ VALIDATION PASSED: Denial properly removes from activeUsers")
        
        // Cleanup
        try await mockFirestore.collection("afterparties").document(testPartyId).delete()
        print("✅ Cleaned up test data")
        
        print("🎉 ALL DATA FLOW VALIDATIONS PASSED!")
        print("   The core bugs have been fixed:")
        print("   - ✅ Guest approval adds to activeUsers")
        print("   - ✅ Party count shows correct numbers")
        print("   - ✅ Guest denial removes from activeUsers")
        print("   - ✅ Data stays synchronized")
    }
    
    // Helper method to create a valid test party
    private func createValidTestParty(id: String, hostId: String) -> Afterparty {
        return Afterparty(
            id: id,
            userId: hostId,
            hostHandle: "testhost",
            coordinate: CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567),
            radius: 15.0,
            startTime: Date().addingTimeInterval(3600),
            endTime: Date().addingTimeInterval(7200),
            city: "Test City",
            locationName: "Test Location",
            description: "Test party for validation",
            address: "Test Address",
            googleMapsLink: "https://maps.google.com/test",
            vibeTag: "House Party",
            activeUsers: [],
            pendingRequests: [],
            createdAt: Date(),
            title: "Validation Test Party",
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
    
    private func fetchPartyFromFirebase(id: String) async throws -> Afterparty {
        let doc = try await mockFirestore.collection("afterparties").document(id).getDocument()
        guard let data = doc.data() else {
            throw NSError(domain: "TestError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Party not found"])
        }
        
        var docData = data
        docData["id"] = doc.documentID
        
        return try Firestore.Decoder().decode(Afterparty.self, from: docData)
    }
} 