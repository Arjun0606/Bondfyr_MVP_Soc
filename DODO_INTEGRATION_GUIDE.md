# Dodo Payments Integration Guide for Bondfyr

## ✅ Current Status

Your Dodo Payments integration is now properly configured with the correct API structure based on their documentation.

### Credentials Configured:
- **API Key (Secret Key)**: `WwodcwFpKfwwrjg5.Or4_3_Zl8Sv3APNRllVNh35fUlyzxZYBV1nrE7W3Xzmfmo`
- **Publishable Key**: `pk_snd_00d98d270105488582b957a0c911dc79`
- **Webhook Secret**: `whsec_xKI9UUl00JcHyVasRJRuMKT0`
- **Webhook URL**: `https://us-central1-bondfyr-da123.cloudfunctions.net/dodoWebhook`

## 🎯 Next Steps to Complete Integration

### 1. Create Products in Dodo Dashboard

The current implementation expects products to be created in your Dodo dashboard. For each party type, you'll need to create a product:

1. Log into your Dodo Payments dashboard
2. Navigate to Products section
3. Create products with IDs like:
   - `prod_bondfyr_party_standard` - For standard party access
   - Or use dynamic product IDs: `prod_bondfyr_party_{afterpartyId}`

### 2. Alternative: Dynamic Product Creation

If you want to create products dynamically, you can modify the `createDodoPaymentIntent` method to first create a product via API:

```swift
// First create the product
let productData: [String: Any] = [
    "name": "Party Access: \(afterparty.title)",
    "price": Int(afterparty.ticketPrice * 100), // in cents
    "currency": "USD"
]

// POST to /products endpoint
// Then use the returned product_id in the payment creation
```

### 3. Test the Payment Flow

1. **In Test Mode**:
   - Use test card numbers from Dodo documentation
   - Card: `4242 4242 4242 4242` (successful payment)
   - Any future expiry date and CVV

2. **Payment Flow**:
   - Guest clicks "Complete Payment ($10)"
   - App creates payment via Dodo API
   - User is redirected to Dodo checkout
   - After payment, webhook updates party status

### 4. Implement Firebase Cloud Function for Webhook

Create a Firebase function to handle Dodo webhooks:

```javascript
// firebase-functions/dodoWebhook.js
exports.dodoWebhook = functions.https.onRequest(async (req, res) => {
  const signature = req.headers['webhook-signature'];
  const webhookSecret = 'whsec_xKI9UUl00JcHyVasRJRuMKT0';
  
  // Verify webhook signature
  // Process payment.succeeded event
  // Update Firestore with payment status
  
  res.status(200).send('OK');
});
```

### 5. Handle Different Payment Events

Update your webhook to handle:
- `payment.succeeded` - Mark user as paid
- `payment.failed` - Show error to user
- `refund.succeeded` - Update party status

## 🔧 Current Implementation Details

### Payment Creation Request Structure:
```json
{
  "payment_link": true,
  "billing": {
    "city": "Party Location",
    "country": "US",
    "state": "CA",
    "street": "Party Location",
    "zipcode": 0
  },
  "customer": {
    "email": "userhandle@bondfyr.com",
    "name": "User Name"
  },
  "product_cart": [{
    "product_id": "prod_bondfyr_party_PARTY_ID",
    "quantity": 1
  }],
  "return_url": "bondfyr://payment-success?afterpartyId=PARTY_ID",
  "metadata": {
    "afterpartyId": "PARTY_ID",
    "userId": "USER_ID",
    "platformFee": 2.0,
    "hostEarnings": 8.0
  }
}
```

### API Endpoints:
- **Test Mode**: `https://test.dodopayments.com/payments`
- **Live Mode**: `https://live.dodopayments.com/payments`

## 📱 Testing in the App

1. Create a party as a host
2. Join as a guest from another account
3. Get approved by the host
4. Click "Complete Payment"
5. Complete payment in Dodo checkout
6. Verify user status changes to "Going"

## 🚀 Going Live

1. Update `dodoEnvironment` in `DodoPaymentService.swift` from `.dev` to `.production`
2. Ensure all products are created in live mode
3. Update webhook URL if different for production
4. Test with real payment methods

## ⚠️ Important Notes

- Currently using temporary emails (`userhandle@bondfyr.com`) - update when you have real user emails
- The 80/20 split is configured (80% host, 20% platform)
- Fallback to simulated payments is enabled if API fails 