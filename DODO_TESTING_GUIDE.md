# Dodo Payments Testing & Integration Guide

## 🎯 Overview

This guide walks you through testing and integrating Dodo Payments with your Bondfyr app.

## 📋 Prerequisites

### 1. Dodo Account Setup
- [x] Signed up at [app.dodopayments.com](https://app.dodopayments.com)
- [x] Account verified and in Test Mode
- [x] Test product created (as seen in your dashboard)

### 2. API Keys (Required for Live Testing)
You'll need these from your Dodo dashboard:
- `DODO_TEST_API_KEY` - Your test environment API key
- `DODO_TEST_WEBHOOK_SECRET` - Your webhook signing secret

## 🧪 Running Tests

### Quick Test (Mock Tests Only)
```bash
cd Bondfyr
./test_dodo_integration.sh
```

### Full Integration Tests (With Real API Keys)
```bash
# Set your test API keys
export DODO_TEST_API_KEY="your_test_api_key_here"
export DODO_TEST_WEBHOOK_SECRET="your_webhook_secret_here"

cd Bondfyr
./test_dodo_integration.sh
```

### Individual Test Categories
```bash
# Test just commission calculations
xcodebuild test -only-testing BondfyrTests/DodoPaymentServiceTests/testBondfyrFeeCalculation

# Test payment intent structure
xcodebuild test -only-testing BondfyrTests/DodoPaymentServiceTests/testPaymentIntentDataStructure

# Test error handling
xcodebuild test -only-testing BondfyrTests/DodoPaymentServiceTests/testPaymentErrorStateManagement
```

## 📊 Test Coverage

Our test suite covers:

### ✅ Commission Calculations (20%/80% Split)
- **Platform Fee**: 20% of ticket price
- **Host Earnings**: 80% of ticket price
- **Edge Cases**: $0, fractional prices, large amounts

### ✅ Payment Intent Structure
- Validates all required fields for Dodo API
- Tests metadata structure
- Verifies marketplace fee configuration

### ✅ Error Handling
- Payment processing state management
- Error message handling
- Configuration validation

### ✅ Integration Flow
- Guest request creation with payment IDs
- Payment status tracking
- Real-time updates

### ✅ Edge Cases
- Zero dollar tickets
- Large ticket prices ($1000+)
- Fractional pricing ($12.99)

## 🔧 Configuration

### Xcode Project Setup
1. **Info.plist Configuration** ✅
   - `DODO_API_KEY` placeholder added
   - `DODO_WEBHOOK_SECRET` placeholder added

2. **URL Schemes** ✅
   - `bondfyr://payment-success` for successful payments
   - `bondfyr://payment-cancelled` for cancelled payments

### Environment Configuration
The app is configured for **Dev Mode** by default:
- API Base URL: `https://api-dev.dodopayments.com`
- Safe for testing with test cards
- No real charges will be made

## 💳 Test Cards (Dodo Payments)

Use these test card numbers in Dodo's checkout:

| Card Number         | Result          | Description                    |
|--------------------|-----------------|---------------------------------|
| 4242 4242 4242 4242| Success         | Visa successful payment        |
| 4000 0000 0000 0002| Declined        | Card declined                  |
| 4000 0000 0000 9995| Insufficient    | Insufficient funds             |

**Note**: Use any future expiry date, any 3-digit CVC, and any zip code.

## 🔄 Integration Flow

### 1. User Journey
```
Guest finds party → Clicks "Pay & Join" → Dodo checkout → Payment success → Request submitted → Host approval
```

### 2. Technical Flow
```
RequestToJoinSheet → DodoPaymentService → Dodo API → Webhook → Firebase → Real-time updates
```

### 3. Data Flow
```
Payment Intent Created → User Pays → Webhook Confirms → GuestRequest Updated → Host Notified
```

## 🎯 Key Integration Points

### ✅ Already Integrated
1. **RequestToJoinSheet.swift** - Payment UI integrated
2. **DodoPaymentService.swift** - Complete service implementation
3. **AfterpartyModel.swift** - Payment tracking fields added
4. **Firebase Functions** - Webhook handlers ready

### 🚀 Production Deployment Steps

1. **Get Production API Keys**
   ```bash
   # From your Dodo dashboard production settings
   DODO_PRODUCTION_API_KEY="pk_live_..."
   DODO_PRODUCTION_WEBHOOK_SECRET="whsec_..."
   ```

2. **Update Environment**
   ```swift
   // In DodoPaymentService.swift
   private let dodoEnvironment: DodoEnvironment = .production
   ```

3. **Deploy Firebase Functions**
   ```bash
   cd firebase-functions
   firebase deploy --only functions
   ```

4. **Configure Webhooks**
   - Set webhook URL to your Firebase function endpoint
   - Configure events: `payment_intent.succeeded`, `payment_intent.payment_failed`

## 🐛 Troubleshooting

### Common Issues

**Tests Failing**
- Check that DodoPaymentService is included in test target
- Verify all model imports are available
- Ensure Firebase is configured for tests

**Payment Flow Issues**
- Verify API keys are correctly set
- Check that you're in Test/Dev mode
- Confirm webhook endpoints are accessible

**Commission Calculations Wrong**
- Should be exactly 20% platform / 80% host
- Check for rounding errors in fractional amounts

### Debug Commands
```bash
# Check test target configuration
xcodebuild -list -project Bondfyr.xcodeproj

# Run specific test with verbose output
xcodebuild test -only-testing BondfyrTests/DodoPaymentServiceTests/testBondfyrFeeCalculation -verbose

# Check scheme configuration
xcodebuild -showBuildSettings -project Bondfyr.xcodeproj -scheme "Bondfyr copy"
```

## 📈 Performance Benchmarks

Our tests include performance benchmarks:
- **Commission calculations**: < 0.1ms for 10,000 calculations
- **Payment intent creation**: Expected < 2s with network
- **Error handling**: Immediate response < 10ms

## 🔒 Security Notes

### Test Environment
- ✅ Using dev environment prevents real charges
- ✅ Test cards cannot be charged real money
- ✅ All test data is isolated

### Production Security
- API keys stored as environment variables
- Webhook signatures verified
- Payment data encrypted in transit
- PCI compliance through Dodo

## 📞 Support

### Dodo Payments
- Documentation: [docs.dodopayments.com](https://docs.dodopayments.com)
- Support: [support@dodopayments.com](mailto:support@dodopayments.com)

### Bondfyr Integration
- Check test output for specific error messages
- Review Firebase console for webhook logs
- Use Xcode Test Navigator for detailed test results

---

## 🚀 Quick Start Checklist

- [ ] Run `./test_dodo_integration.sh` to verify setup
- [ ] Get test API keys from Dodo dashboard
- [ ] Test payment flow with test cards
- [ ] Verify webhook integration
- [ ] Deploy to production environment

**Ready to test your integration? Run the test script and let's see how it goes!** 🎉 