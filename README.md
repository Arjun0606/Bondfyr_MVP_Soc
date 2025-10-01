# Bondfyr MVP

This is the MVP (Minimum Viable Product) version of Bondfyr, a social app for finding and hosting afterparties.

YOU CAN FIND US ON THE IOS APP STORE!!!

## Features

- **Event Discovery**: Browse nightlife events in your city
- **Afterparty Marketplace**: Host and discover paid afterparties
- **City Chat**: Connect with local partygoers
- **Photo Sharing**: Share UGC photos at events
- **Ticket Management**: Buy and manage event tickets
- **Social Authentication**: Sign in with Google/Snapchat/Instagram

## PayPal Business Payment Integration 💰

### Setup Instructions

#### 1. PayPal Business Account Setup
1. Create a [PayPal Business account](https://www.paypal.com/us/business)
2. Log into [PayPal Developer Dashboard](https://developer.paypal.com)
3. Create a new app for your project
4. Get your Client ID and Client Secret from the app settings
5. Configure webhooks in the PayPal dashboard

#### 2. iOS App Configuration
Update `PaymentService.swift` with your credentials:
```swift
private let paypalClientID = "YOUR_PAYPAL_CLIENT_ID" 
private let paypalClientSecret = "YOUR_PAYPAL_CLIENT_SECRET"
```

Or add to `Info.plist`:
```xml
<key>PAYPAL_CLIENT_ID</key>
<string>YOUR_PAYPAL_CLIENT_ID</string>
<key>PAYPAL_CLIENT_SECRET</key>
<string>YOUR_PAYPAL_CLIENT_SECRET</string>
```

#### 3. Firebase Cloud Functions Setup
1. Set environment variables:
```bash
firebase functions:config:set paypal.webhook_id="YOUR_WEBHOOK_ID"
firebase functions:config:set paypal.client_id="YOUR_CLIENT_ID"
firebase functions:config:set paypal.client_secret="YOUR_CLIENT_SECRET"
```

2. Deploy functions:
```bash
cd firebase-functions
npm install
firebase deploy --only functions
```

#### 4. PayPal Webhook Configuration
1. In your PayPal Developer dashboard, go to your app
2. Add webhook URL: `https://YOUR_PROJECT.cloudfunctions.net/paypalWebhook`
3. Select events: `PAYMENT.CAPTURE.COMPLETED`, `PAYMENT.CAPTURE.REFUNDED`, `CHECKOUT.ORDER.APPROVED`
4. Save webhook configuration

#### 5. URL Scheme Setup
Add to `Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>bondfyr-payments</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>bondfyr</string>
        </array>
    </dict>
</array>
```

### Payment Flow

1. **User Requests Access**: User taps "Request $X" on afterparty
2. **Create PayPal Order**: App creates PayPal order via API
3. **Payment Processing**: User completes payment in PayPal web interface
4. **Payment Capture**: PayPal captures payment automatically
5. **Webhook Processing**: PayPal sends webhook to Firebase
6. **Status Update**: Firebase updates payment status in Firestore
7. **Confirmation**: User receives confirmation and can access party

### Revenue Model
- **Host Earnings**: 80% of ticket price
- **Platform Fee**: 20% of ticket price
- **Automatic Payouts**: Processed weekly for completed events

## Tech Stack

- **iOS**: SwiftUI, Firebase SDK
- **Backend**: Firebase (Firestore, Auth, Functions, Storage)
- **Payments**: PayPal Business API
- **Real-time**: Firebase Firestore listeners
- **Push Notifications**: Firebase Cloud Messaging

## Project Structure

```
Bondfyr/
├── Bondfyr/
│   ├── Views/
│   │   ├── Afterparty/          # Paid party marketplace
│   │   ├── Auth/                # Authentication flows
│   │   ├── Chat/                # City & event chat
│   │   └── Profile/             # User profiles & settings
│   ├── Services/
│   │   ├── PaymentService.swift # PayPal integration
│   │   └── EventService.swift   # Event management
│   ├── Models/
│   │   ├── AfterpartyModel.swift # Party & payment models
│   │   └── AppUser.swift        # User models
│   └── Managers/               # Business logic managers
├── firebase-functions/         # Cloud Functions
└── BondfyrPhotos/             # Photo sharing package
```

## Development Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   cd firebase-functions && npm install
   ```
3. Set up Firebase project and configure
4. Set up LemonSqueezy integration (see above)
5. Run the iOS app in Xcode

## Environment Variables

Set these in Firebase Functions config:
```bash
firebase functions:config:set \
  google.places_key="YOUR_GOOGLE_PLACES_API_KEY" \
  paypal.client_id="YOUR_PAYPAL_CLIENT_ID" \
  paypal.client_secret="YOUR_PAYPAL_CLIENT_SECRET" \
  paypal.webhook_id="YOUR_WEBHOOK_ID"
```

## Testing Payments

### Test Mode
- Use PayPal Sandbox for development
- Test accounts: Create buyer/seller accounts in PayPal Developer dashboard
- All webhooks work in sandbox mode

### Production
- Switch to live mode in PayPal
- Update webhook URLs to production endpoints
- Test with real payment methods

## Security Considerations

- API keys stored securely in Firebase config
- Webhook signatures verified with HMAC
- User authentication required for all payments
- Payment status verified server-side

## Troubleshooting

### Common Issues
1. **Webhook not received**: Check URL and Firebase function logs
2. **Payment not updating**: Verify webhook signature and event types
3. **Checkout fails**: Check API key and store configuration

### Debug Commands
```bash
# Check Firebase function logs
firebase functions:log

# Test webhook locally
firebase emulators:start --only functions

# Check config
firebase functions:config:get
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test payment flows thoroughly
4. Submit a pull request

## License

Private - Bondfyr MVP

