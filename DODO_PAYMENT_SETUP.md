# 🚨 CRITICAL PAYMENT SETUP FIXES

## **1. 🍎 Fix Apple Pay Missing Issue**

### Problem: Apple Pay not showing on checkout page
### Solution: Enable in Dodo Dashboard

**Steps:**
1. Login to https://dashboard.dodopayments.com
2. Go to **Settings** → **Payment Methods**
3. Enable these payment methods:
   - ✅ **Apple Pay** (critical for US students)
   - ✅ **Google Pay** 
   - ✅ **Klarna** (buy now, pay later)
   - ✅ **CashApp** (popular with students)
   - ✅ **Cards** (Visa, Mastercard, Amex)

4. For **Apple Pay specifically**:
   - Go to **Apple Pay** settings
   - Add your domain: `test.checkout.dodopayments.com`
   - Verify domain (Dodo handles this automatically)

**Expected Result:** All payment methods show on checkout

---

## **2. 🏦 Fix Host Bank Details Missing**

### Problem: Hosts can't add bank details for payouts
### Solution: Integrate Dodo merchant onboarding

**Current Issue:** Dodo handles payouts but hosts need to complete merchant onboarding

**Immediate Fix:**
1. **Host Onboarding Flow** - Add to app:
```swift
// In HostDashboardView.swift - add bank setup button
Button("Setup Bank Account") {
    // Open Dodo merchant onboarding
    openDodoMerchantOnboarding()
}

private func openDodoMerchantOnboarding() {
    // Open Dodo's hosted onboarding flow
    let url = URL(string: "https://dashboard.dodopayments.com/onboarding")!
    UIApplication.shared.open(url)
}
```

2. **Payout Information** - Show in dashboard:
```swift
// Display payout status and bank info
Text("Bank Account: \(host.bankStatus)")
Text("Next Payout: 15th of next month")
Text("Pending Earnings: $\(host.pendingEarnings)")
```

**Long-term Solution:** Integrate Dodo's onboarding API into the app flow

---

## **3. 🔔 Fix Push Notifications (Not Local)**

### Problem: Notifications showing on wrong devices
### Solution: Firebase Cloud Messages (FCM)

**What's Wrong:**
- Currently using local notifications (only show on current device)
- Need server-side push notifications via Firebase

**Fix Steps:**

1. **Create Firebase Cloud Function:**
```javascript
// firebase-functions/sendNotification.js
exports.sendNotification = functions.https.onCall(async (data, context) => {
  const { targetUserId, title, body, notificationData } = data;
  
  // Get user's FCM token from Firestore
  const userDoc = await admin.firestore()
    .collection('users').doc(targetUserId).get();
  
  const fcmToken = userDoc.data()?.fcmToken;
  if (!fcmToken) return { success: false, error: 'No FCM token' };
  
  // Send push notification
  const message = {
    token: fcmToken,
    notification: { title, body },
    data: notificationData
  };
  
  await admin.messaging().send(message);
  return { success: true };
});
```

2. **Update iOS App for FCM:**
```swift
// In AppDelegate.swift or App.swift
import FirebaseMessaging

// Request FCM token and save to Firestore
Messaging.messaging().token { token, error in
  if let token = token {
    // Save to Firestore user document
    Firestore.firestore().collection("users").document(userId)
      .updateData(["fcmToken": token])
  }
}
```

3. **Update Notification Calls:**
```swift
// Replace local notifications with FCM calls
await sendFirebaseNotificationToUser(
  userId: hostId,
  title: "💰 Payment Received!",
  body: "\(guestName) paid $\(amount)"
)
```

---

## **4. 📱 Complete Payment Method Integration**

### Current Status:
- ✅ **Cards**: Working
- ❌ **Apple Pay**: Needs dashboard config  
- ❌ **Klarna**: Needs dashboard config
- ❌ **CashApp**: Needs dashboard config
- ✅ **Safari Checkout**: Working (shows all enabled methods)

### Action Items:
1. **Enable all payment methods in Dodo dashboard**
2. **Test each payment method with $1 transactions**
3. **Verify US student payment flow works**

---

## **5. 🧪 Testing Checklist**

### Before Going Live:
- [ ] Apple Pay shows on checkout page
- [ ] Klarna "Pay in 4" option appears
- [ ] CashApp button visible
- [ ] Host receives push notification on payment
- [ ] Guest receives confirmation push notification
- [ ] Host can setup bank account for payouts
- [ ] Test refunds work correctly
- [ ] Verify 80/20 split is correct

### Test Cards (Use in Dodo sandbox):
- **Success**: `4242 4242 4242 4242`
- **Decline**: `4000 0000 0000 0002`
- **Apple Pay Test**: Use test cards in iOS Simulator

---

## **6. 🚀 Production Checklist**

### When Ready for Launch:
1. Switch `dodoEnvironment` to `.production`
2. Update to live Dodo API keys
3. Enable live payment methods
4. Deploy Firebase Cloud Functions
5. Test with real $1 payment
6. Monitor first transactions carefully

---

## **Priority Order:**
1. **🔴 URGENT**: Enable Apple Pay in Dodo dashboard
2. **🔴 URGENT**: Fix push notifications (FCM)
3. **🟡 MEDIUM**: Add host bank setup flow
4. **🟢 LOW**: Test all payment methods

**Your payment infrastructure will be bulletproof once these are fixed!** 🎯 