# 💰 PayPal Business Setup Guide for Bondfyr

## 🚀 **Step 1: Create PayPal Business Account**

1. **Visit PayPal Business**: Go to [paypal.com/us/business](https://www.paypal.com/us/business)
2. **Create Account**: Click "Get Started" and select "Business Account"
3. **Provide Business Information**:
   - Business Name: "Bondfyr" (or your preferred name)
   - Business Type: "Individual/Sole Proprietorship" 
   - Business Category: "Technology/Software"
   - Business Subcategory: "Software/Web Development"
4. **Complete Verification**: Follow PayPal's verification process

## 🔧 **Step 2: PayPal Developer Setup**

1. **Access Developer Portal**: Go to [developer.paypal.com](https://developer.paypal.com)
2. **Log in** with your PayPal Business account
3. **Create New App**:
   - Click "Create App"
   - App Name: "Bondfyr Payments"
   - Merchant ID: (Your PayPal business account)
   - Features: Check "Accept payments"
   - Products: Select "Checkout"

## 🔑 **Step 3: Get API Credentials**

After creating your app, you'll see:

### Sandbox Credentials (for testing):
```
Client ID: [Copy this - starts with "AU..." or "AY..."]
Client Secret: [Copy this - long string]
```

### Live Credentials (for production):
```
Client ID: [Available after app review]
Client Secret: [Available after app review]
```

## 📱 **Step 4: Update iOS App**

1. **Update PaymentService.swift**:
```swift
// Replace these with your actual credentials
private let paypalClientID = "YOUR_SANDBOX_CLIENT_ID" // For testing
private let paypalClientSecret = "YOUR_SANDBOX_CLIENT_SECRET" // For testing

// For production, switch to .production
private let paypalEnvironment: PayPalEnvironment = .sandbox
```

2. **Add to Info.plist** (optional but recommended):
```xml
<key>PAYPAL_CLIENT_ID</key>
<string>YOUR_SANDBOX_CLIENT_ID</string>
<key>PAYPAL_CLIENT_SECRET</key>
<string>YOUR_SANDBOX_CLIENT_SECRET</string>
```

## 🔗 **Step 5: Configure Webhooks**

1. **In PayPal Developer Dashboard**:
   - Go to your app
   - Click "Add Webhook"
   - Webhook URL: `https://YOUR_PROJECT.cloudfunctions.net/paypalWebhook`
   
2. **Select Events**:
   - ✅ `PAYMENT.CAPTURE.COMPLETED`
   - ✅ `PAYMENT.CAPTURE.REFUNDED` 
   - ✅ `CHECKOUT.ORDER.APPROVED`

3. **Save Webhook** and copy the Webhook ID

## ☁️ **Step 6: Firebase Functions Setup**

1. **Set Environment Variables**:
```bash
cd firebase-functions
firebase functions:config:set \
  paypal.client_id="YOUR_SANDBOX_CLIENT_ID" \
  paypal.client_secret="YOUR_SANDBOX_CLIENT_SECRET" \
  paypal.webhook_id="YOUR_WEBHOOK_ID"
```

2. **Deploy Functions**:
```bash
npm install
firebase deploy --only functions
```

## 🧪 **Step 7: Testing**

1. **Create Test Accounts**:
   - In PayPal Developer dashboard, go to "Sandbox > Accounts"
   - Create a "Personal" account (buyer)
   - Create a "Business" account (seller)

2. **Test Payment Flow**:
   - Use sandbox credentials in your app
   - Test creating afterparties and purchasing tickets
   - Check webhook receives events in Firebase console

## 💸 **Step 8: Fee Structure**

PayPal Business fees for US transactions:
- **Domestic**: 2.9% + $0.30 per transaction
- **International**: 4.4% + fixed fee
- **Micropayments**: 5% + $0.05 (for transactions under $10)

**Your Revenue Calculation**:
```
Ticket Price: $25
PayPal Fee: $25 × 0.029 + $0.30 = $1.03
Net Amount: $25 - $1.03 = $23.97
Your Commission (12%): $25 × 0.12 = $3.00
Host Earnings: $25 - $3.00 = $22.00
Your Profit: $3.00 - $1.03 = $1.97 per ticket
```

## 🚀 **Step 9: Go Live**

When ready for production:

1. **Submit App for Review**:
   - In PayPal Developer dashboard
   - Click "Submit for Review"
   - Provide business documentation

2. **Switch to Live Credentials**:
```swift
// Update PaymentService.swift
private let paypalEnvironment: PayPalEnvironment = .production
private let paypalClientID = "YOUR_LIVE_CLIENT_ID"
private let paypalClientSecret = "YOUR_LIVE_CLIENT_SECRET"
```

3. **Update Firebase Config**:
```bash
firebase functions:config:set \
  paypal.client_id="YOUR_LIVE_CLIENT_ID" \
  paypal.client_secret="YOUR_LIVE_CLIENT_SECRET"
firebase deploy --only functions
```

## 🔒 **Security Best Practices**

1. **Never commit credentials** to version control
2. **Use environment variables** for sensitive data
3. **Validate webhooks** (implement signature verification)
4. **Monitor transactions** regularly
5. **Set up fraud protection** in PayPal dashboard

## 🆘 **Troubleshooting**

### Common Issues:

1. **"Authentication Failed"**
   - Check Client ID and Secret are correct
   - Ensure using sandbox credentials for testing

2. **"Webhook Not Received"**
   - Verify webhook URL is correct
   - Check Firebase Functions logs
   - Ensure webhook events are selected

3. **"Order Creation Failed"**
   - Check amount format (must be string with 2 decimals)
   - Verify currency code is "USD"
   - Check custom_id format

### Debug Commands:
```bash
# Check Firebase logs
firebase functions:log

# Test webhook locally
firebase emulators:start --only functions

# Check environment config
firebase functions:config:get
```

## 📞 **Support**

- **PayPal Developer Support**: [developer.paypal.com/support](https://developer.paypal.com/support)
- **PayPal Business Support**: Contact through your PayPal dashboard
- **Integration Issues**: Check Firebase Functions logs first

---

## ✅ **Quick Checklist**

- [ ] PayPal Business account created
- [ ] Developer app created
- [ ] Sandbox credentials obtained
- [ ] iOS app updated with credentials
- [ ] Firebase functions configured
- [ ] Webhooks configured
- [ ] Test transactions completed
- [ ] Ready for production review

**Estimated Setup Time**: 2-3 hours
**Time to Production**: 1-2 weeks (including PayPal review) 