import XCTest
import Firebase
import CoreLocation
@testable import Bondfyr

class DodoPaymentServiceTests: XCTestCase {
    
    func testCalculateBondfyrFee() {
        let service = DodoPaymentService.shared
        
        // Test 20% fee calculation
        XCTAssertEqual(service.calculateBondfyrFee(from: 10.0), 2.0, accuracy: 0.01)
        XCTAssertEqual(service.calculateBondfyrFee(from: 25.0), 5.0, accuracy: 0.01)
        XCTAssertEqual(service.calculateBondfyrFee(from: 100.0), 20.0, accuracy: 0.01)
    }
    
    func testCalculateHostEarnings() {
        let service = DodoPaymentService.shared
        
        // Test 80% host earnings calculation
        XCTAssertEqual(service.calculateHostEarnings(from: 10.0), 8.0, accuracy: 0.01)
        XCTAssertEqual(service.calculateHostEarnings(from: 25.0), 20.0, accuracy: 0.01)
        XCTAssertEqual(service.calculateHostEarnings(from: 100.0), 80.0, accuracy: 0.01)
    }
    
    func testPaymentStructure() {
        // Test that payment intent structure exists
        let intent = DodoPaymentIntent(url: "https://test.url", paymentId: "test123")
        XCTAssertEqual(intent.url, "https://test.url")
        XCTAssertEqual(intent.paymentId, "test123")
    }
    
    func testConfigurationValidation() {
        let service = DodoPaymentService.shared
        
        // Test configuration detection
        // Note: This will return true since we have test keys configured
        XCTAssertTrue(service.isConfigured)
    }
} 