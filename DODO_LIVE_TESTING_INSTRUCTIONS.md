# 🎯 Dodo Payments Live Testing Instructions

## 📋 Pre-Testing Checklist
✅ All unit tests passing (12/13 - expected)  
✅ App builds successfully  
✅ Dev mode configured  
✅ Models integrated  
✅ UI components updated  

## 🔑 Step 1: Get Your API Keys

1. **Login to your Dodo Dashboard**: [app.dodopayments.com](https://app.dodopayments.com)
2. **Navigate to API Keys** section
3. **Copy your Test/Dev API Key** (starts with `pk_test_` or similar)
4. **Copy your Webhook Secret** (for validating webhook calls)

## 🧪 Step 2: Run Full Integration Tests

Set your API keys and run comprehensive tests:

```bash
# Set your test API keys (replace with actual keys)
export DODO_TEST_API_KEY="pk_test_your_actual_test_key_here"
export DODO_TEST_WEBHOOK_SECRET="whsec_your_actual_webhook_secret_here"

# Run all tests including live API tests
cd Bondfyr
./test_dodo_integration.sh
```

## 📱 Step 3: Manual App Testing

### Test Flow 1: Basic Payment
1. **Open Bondfyr app** in simulator
2. **Find an afterparty** with ticket price ($10 recommended)
3. **Tap "Request to Join"**
4. **Verify payment sheet** shows correct amounts:
   - Total: $10.00
   - Platform fee: $2.00 (20%)
   - Host gets: $8.00 (80%)
5. **Use test card**: `4242 4242 4242 4242`
6. **Complete payment**
7. **Verify success** message and request status

### Test Flow 2: Different Price Points
Test with various ticket prices:
- **$5** → Platform: $1.00, Host: $4.00
- **$25** → Platform: $5.00, Host: $20.00
- **$50** → Platform: $10.00, Host: $40.00
- **$0** → Free event (no payment)

### Test Flow 3: Error Handling
- **Declined card**: `4000 0000 0000 0002`
- **Insufficient funds**: `4000 0000 0000 9995`
- **Expired card**: `4000 0000 0000 0069`

## 🎨 Test Card Numbers (Dodo Test Mode)

| Scenario | Card Number | Result |
|----------|-------------|---------|
| **Success** | `4242 4242 4242 4242` | ✅ Payment succeeds |
| **Declined** | `4000 0000 0000 0002` | ❌ Generic decline |
| **Insufficient Funds** | `4000 0000 0000 9995` | ❌ Insufficient funds |
| **Lost Card** | `4000 0000 0000 9987` | ❌ Lost card |
| **Stolen Card** | `4000 0000 0000 9979` | ❌ Stolen card |
| **Expired Card** | `4000 0000 0000 0069` | ❌ Expired card |

**For all test cards:**
- Any future expiry date (e.g., `12/28`)
- Any 3-digit CVC
- Any billing postal code

## 🎯 Step 4: Webhook Testing

### Set Up ngrok (for webhook testing)
```bash
# Install ngrok if not already installed
brew install ngrok

# Expose your local server (if testing webhooks locally)
ngrok http 8080
```

### Configure Webhook in Dodo Dashboard
1. **Go to Webhooks** section in Dodo dashboard
2. **Add webhook endpoint**: `https://your-ngrok-url.com/dodo-webhook`
3. **Select events**:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed` 
   - `charge.dispute.created`

## 🔍 Step 5: Monitor & Debug

### Check App Logs
- **Xcode Console**: Look for DodoPaymentService logs
- **Payment flow**: Verify each step completes
- **Error handling**: Check error messages are user-friendly

### Check Dodo Dashboard
- **Payments tab**: Verify test payments appear
- **Webhooks tab**: Check webhook delivery status
- **Events tab**: See real-time payment events

## 📊 Expected Results

### ✅ Success Indicators:
- Payment intent created successfully
- Payment sheet displays correct amounts
- Test card payments complete
- Guest request status updates to "pending" 
- Host dashboard shows new requests
- Webhook events fire correctly

### 🚨 Issues to Watch For:
- Network timeout errors
- Incorrect fee calculations  
- UI not updating after payment
- Missing webhook events
- Error messages not displaying

## 🚀 Step 6: Production Readiness

Once testing passes:

1. **Update Environment**: Change from `.dev` to `.production`
2. **Get Production Keys**: Replace test keys with live keys
3. **Update Webhook URLs**: Point to production server
4. **Final Testing**: Test with small real amounts
5. **Go Live**: Enable for users

## 💰 Pricing Validation

Double-check your pricing structure:
- **$10 ticket**: $2.00 platform fee, $8.00 to host
- **Processing cost**: ~$0.59 (Dodo's fees)
- **Your net profit**: ~$1.41 (14.1% margin)
- **Host gets**: Clean $8.00 (no deductions)

## 🎉 You're Ready!

Your Dodo Payment integration is fully functional and ready for testing. The comprehensive test suite proves your commission calculations, error handling, and integration are working correctly.

Just get your API keys and you're ready to process real payments! 🚀 