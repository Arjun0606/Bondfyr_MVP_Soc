# Dodo Payment Integration Setup

## Current Status: ✅ Test Mode Working

The app is currently running in **test mode** which simulates successful payments without real money transfer. This is perfect for development and testing.

## Test Mode Configuration

```swift
// In DodoPaymentService.swift
private let forceTestMode: Bool = true  // ✅ Currently enabled
```

When `forceTestMode = true`:
- No real money is charged
- Payment completion is simulated locally
- All UI updates work correctly
- Perfect for development/testing

## For Production: Dodo + Firebase Webhook Integration

When you're ready to process real payments, follow these steps:

### 1. Set up Dodo Webhook in Firebase Functions

Your webhook endpoint should be: `https://your-project.firebaseapp.com/dodoWebhook`

The webhook function (already exists in `firebase-functions/dodoWebhook.js`) handles:
- `payment.succeeded` events
- Updates Firestore with payment status
- Adds user to `activeUsers` array

### 2. Configure Dodo Dashboard

1. Go to your Dodo Payments dashboard
2. Add webhook URL: `https://your-project.firebaseapp.com/dodoWebhook`
3. Subscribe to `payment.succeeded` events
4. Copy the webhook secret

### 3. Enable Production Mode

```swift
// In DodoPaymentService.swift
private let forceTestMode: Bool = false  // Enable real payments
private let dodoEnvironment: DodoEnvironment = .production
```

### 4. Test Production Flow

1. User clicks "Complete Payment"
2. App creates real Dodo payment intent
3. Safari opens with Dodo checkout
4. User completes real payment
5. Dodo sends webhook to Firebase
6. Firebase updates Firestore
7. App UI refreshes automatically

## Current Working Flow (Test Mode)

✅ Guest requests to join
✅ Host approves request  
✅ Guest sees "Complete Payment" button
✅ Payment simulated successfully
✅ Guest shows "Going" status
✅ Host sees "✅ PAID - Attending!"
✅ All UI components update correctly

## Troubleshooting

If payments fail:
1. Check console logs for error details
2. Ensure `forceTestMode = true` for testing
3. Verify Firebase rules allow write access
4. Check Dodo API credentials are valid

## Security Notes

- Never expose API keys in client code
- Use Firebase Security Rules to protect payment data
- Validate all webhook signatures
- Log all payment events for audit trail 