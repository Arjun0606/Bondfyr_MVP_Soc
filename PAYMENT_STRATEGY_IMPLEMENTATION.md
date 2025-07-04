# Payment Strategy Implementation Guide

## Overview
This guide implements a payment strategy for Bondfyr that transitions from free tickets to Stripe payments once the app reaches 5000 users.

## Current Implementation Status

### ✅ Completed
- **Backend Firebase Functions**: User count tracking, conditional payment processing
- **iOS PaymentManager**: Handles both free and Stripe payment flows
- **UI Updates**: PaymentProcessingView now uses real payment processing
- **User Count Tracking**: Automatic user count updates when users sign up

### 🔄 Next Steps Required

## 1. Firebase Configuration

### A. Install Stripe Package
```bash
cd firebase-functions
npm install stripe@14.0.0
```

### B. Set Firebase Environment Variables
```bash
firebase functions:config:set stripe.secret_key="sk_test_YOUR_STRIPE_SECRET_KEY"
firebase functions:config:set stripe.publishable_key="pk_test_YOUR_STRIPE_PUBLISHABLE_KEY"
```

### C. Deploy Firebase Functions
```bash
firebase deploy --only functions
```

## 2. iOS Configuration

### A. Add Stripe iOS SDK
Add to your `Podfile`:
```ruby
pod 'Stripe', '~> 23.0'
```

Then run:
```bash
cd Bondfyr
pod install
```

### B. Initialize Stripe in AppDelegate
```swift
import Stripe

// In AppDelegate.swift or App.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Set your Stripe publishable key
    StripeAPI.defaultPublishableKey = "pk_test_YOUR_STRIPE_PUBLISHABLE_KEY"
    return true
}
```

## 3. Payment Flow Architecture

### Free Payment Mode (< 5000 users)
```mermaid
graph TD
    A[User clicks "Get Tickets"] --> B[PaymentManager.processPayment]
    B --> C[Check user count via Firebase]
    C --> D{User count < 5000?}
    D -->|Yes| E[Process as free ticket]
    E --> F[Save ticket to Firestore]
    F --> G[Show success message]
```

### Stripe Payment Mode (≥ 5000 users)
```mermaid
graph TD
    A[User clicks "Get Tickets"] --> B[PaymentManager.processPayment]
    B --> C[Check user count via Firebase]
    C --> D{User count >= 5000?}
    D -->|Yes| E[Create Stripe Payment Intent]
    E --> F[Show Stripe payment UI]
    F --> G[Process payment with Stripe]
    G --> H[Verify payment on backend]
    H --> I[Save ticket to Firestore]
    I --> J[Show success message]
```

## 4. Key Features

### Automatic User Count Tracking
- **Firebase Auth Trigger**: Automatically updates user count when users sign up
- **Real-time Switching**: Payment method switches automatically at 5000 users
- **System Metrics**: Stored in Firestore `system/metrics` document

### Conditional Payment Processing
- **Free Mode**: Direct ticket creation, no payment processing
- **Stripe Mode**: Full payment processing with transaction fees
- **Seamless Transition**: Users don't notice the change in payment method

### Error Handling
- **Network Errors**: Graceful fallback and retry mechanisms
- **Payment Failures**: Clear error messages and retry options
- **User Experience**: Consistent UI regardless of payment method

## 5. Firebase Functions API

### `getUserCount`
```javascript
// Returns current user count and payment method
{
  userCount: 4500,
  paymentMethod: "free", // or "stripe"
  threshold: 5000
}
```

### `processPayment`
```javascript
// Handles both free and Stripe payments
{
  ticketData: {...},
  paymentMethod: null | {stripePaymentIntentId: "pi_xxx"}
}
```

### `createPaymentIntent`
```javascript
// Creates Stripe payment intent for paid tickets
{
  amount: 2500, // cents
  currency: "usd"
}
```

## 6. Monitoring and Analytics

### User Count Monitoring
- Track when approaching 5000 users
- Monitor payment method transition
- Alert on threshold reached

### Revenue Tracking
- Free ticket count (before 5000 users)
- Paid ticket revenue (after 5000 users)
- Stripe transaction fees

### Firebase Analytics Events
- `ticket_purchase_initiated`
- `ticket_purchased`
- `payment_method_switched`

## 7. Testing Strategy

### Development Testing
1. **Manually set user count** in Firebase to test both payment modes
2. **Use Stripe test mode** for payment processing
3. **Test error scenarios** (network failures, payment failures)

### Production Readiness
1. **Switch to Stripe live keys** before production
2. **Test with small amounts** initially
3. **Monitor logs** for payment processing issues

## 8. Cost Considerations

### Free Mode (< 5000 users)
- **Firebase costs**: Minimal (few database writes)
- **User acquisition**: No payment friction
- **Revenue**: $0 per transaction

### Stripe Mode (≥ 5000 users)
- **Stripe fees**: 2.9% + 30¢ per transaction
- **Revenue per ticket**: $15-30 (example pricing)
- **Net revenue**: ~$14.12-$29.12 per ticket after fees

## 9. Migration Path

### Current State
- Simulated payments (always succeed)
- No real payment processing
- Direct ticket creation

### New State
- Conditional payment processing
- Real Stripe integration
- User count-based switching

### Migration Steps
1. Deploy Firebase functions
2. Update iOS app with PaymentManager
3. Test both payment modes
4. Deploy to production
5. Monitor user count approaching 5000

## 10. Future Enhancements

### Additional Payment Methods
- Apple Pay integration
- Google Pay support
- Venmo direct integration (instead of free mode)

### Advanced Features
- Subscription tickets
- Group discounts
- Dynamic pricing based on demand

### Business Intelligence
- Revenue forecasting
- User behavior analysis
- Payment method preferences

## 11. Security Considerations

### API Security
- All payment processing server-side
- Secure webhook handling
- Input validation and sanitization

### Data Protection
- PCI compliance through Stripe
- Minimal payment data storage
- Secure key management

### Fraud Prevention
- Stripe's built-in fraud detection
- Rate limiting on payment endpoints
- User verification requirements

## 12. Support and Troubleshooting

### Common Issues
1. **Payment failures**: Check Stripe dashboard
2. **User count discrepancies**: Verify Firebase functions
3. **UI not updating**: Check PaymentManager state

### Debugging
- Enable Firebase Functions logging
- Monitor Stripe webhook events
- Check iOS PaymentManager logs

---

## Implementation Checklist

- [ ] Set up Stripe account and get API keys
- [ ] Configure Firebase environment variables
- [ ] Deploy Firebase functions
- [ ] Add Stripe iOS SDK to project
- [ ] Initialize Stripe in iOS app
- [ ] Test both payment modes
- [ ] Monitor user count approaching 5000
- [ ] Switch to live Stripe keys for production
- [ ] Set up monitoring and alerting
- [ ] Create documentation for support team

## Contact Information

For questions about this implementation:
- Firebase Functions: Check logs in Firebase Console
- Stripe Integration: Stripe Dashboard and Documentation
- iOS Implementation: PaymentManager class and PaymentProcessingView