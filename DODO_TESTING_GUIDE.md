# Dodo Payments Testing Guide for Bondfyr

## ✅ Integration Complete!

Your Dodo Payments integration is now fully configured and ready for testing.

## 🎯 What's Been Set Up

### 1. **API Integration**
- ✅ Secret API Key configured
- ✅ Publishable Key configured
- ✅ Webhook Secret configured
- ✅ Test product ID: `pdt_mPFnouRlaQerAPmYz1gY`
- ✅ Payment creation endpoint: `/payments`
- ✅ Smart fallback to simulated payments if API fails

### 2. **Webhook Handler**
- ✅ Firebase Cloud Function deployed
- ✅ Webhook URL: `https://us-central1-bondfyr-da123.cloudfunctions.net/dodoWebhook`
- ✅ Handles events: `payment.succeeded`, `payment.failed`, `refund.succeeded`
- ✅ Updates Firestore with payment status
- ✅ Sends push notifications to users and hosts

### 3. **Payment Flow**
- ✅ 80/20 split configured (80% host, 20% platform)
- ✅ Automatic status updates on payment success
- ✅ Transaction records created for reporting

## 🧪 Testing Instructions

### Step 1: Create a Test Party
1. Open the app and sign in as a host
2. Create a new party with a $10 ticket price
3. Note the party ID for testing

### Step 2: Test Guest Flow
1. Sign in with a different account (guest)
2. Find the party and tap "Request to Join"
3. Wait for host approval

### Step 3: Test Host Approval
1. Switch back to host account
2. Go to Host Dashboard
3. Approve the guest request
4. Guest should receive notification

### Step 4: Test Payment Flow
1. Switch to guest account
2. You should see "Complete Payment ($10)" button
3. Tap the button to initiate payment
4. The app will create a Dodo payment link

### Step 5: Complete Test Payment
Use these test card details:
- **Card Number**: `4242 4242 4242 4242`
- **Expiry**: Any future date (e.g., 12/25)
- **CVV**: Any 3 digits (e.g., 123)
- **Name**: Test User
- **Email**: test@example.com

### Step 6: Verify Payment Success
1. After payment, webhook will fire
2. Check Firebase Functions logs:
   ```bash
   firebase functions:log --only dodoWebhook
   ```
3. Guest status should change to "Going"
4. Host should receive payment notification

## 📊 Monitoring & Debugging

### Check Firebase Logs
```bash
# View webhook logs
firebase functions:log --only dodoWebhook

# View last 50 entries
firebase functions:log --only dodoWebhook -n 50
```

### Check Firestore Updates
1. Go to Firebase Console
2. Navigate to Firestore Database
3. Check `afterparties` collection
4. Look for:
   - `guestRequests` array with `paymentStatus: 'paid'`
   - `activeUsers` array containing the guest's userId
5. Check `transactions` collection for payment records

### Debug Payment Issues
1. Check Xcode console for API responses
2. Look for logs starting with:
   - `🔵 DODO API:` - API requests
   - `🔴 DODO:` - Errors
   - `⚠️ DODO:` - Warnings

## 🚨 Common Issues & Solutions

### Issue: Payment fails with 404
**Solution**: Ensure the product ID exists in your Dodo dashboard

### Issue: Webhook not firing
**Solution**: 
1. Check webhook URL in Dodo dashboard matches Firebase function
2. Verify webhook secret is correct
3. Check Firebase function logs for errors

### Issue: User status not updating
**Solution**:
1. Check webhook is processing successfully
2. Verify metadata is being passed correctly
3. Check Firestore security rules allow updates

## 🎯 Test Scenarios

### ✅ Happy Path
1. Guest requests → Host approves → Payment succeeds → Status updates

### ❌ Payment Failure
1. Use test card: `4000 0000 0000 0002` (declined)
2. Verify failure is handled gracefully

### 💸 Refund Test
1. Process a successful payment
2. Issue refund from Dodo dashboard
3. Verify user status reverts and notifications sent

## 📱 Push Notifications

Notifications are sent for:
- Host: New guest request
- Guest: Request approved
- Guest: Payment required reminder
- Guest: Payment confirmed
- Host: Payment received with earnings

## 🚀 Going Live Checklist

- [ ] Create production products in Dodo dashboard
- [ ] Update `dodoEnvironment` to `.production`
- [ ] Test with small real payment
- [ ] Monitor first few live transactions
- [ ] Set up error alerting

## 📞 Support

- **Dodo Support**: Check their dashboard for support options
- **Firebase Issues**: Check Functions logs and Firestore rules
- **App Issues**: Check Xcode console and device logs

Happy testing! 🎉 