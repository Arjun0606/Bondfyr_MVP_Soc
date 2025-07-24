const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();

/**
 * AUTOMATED WEEKLY PAYOUTS
 * 
 * This Cloud Function runs every Friday at 6 PM PST to automatically
 * process payouts to hosts who have:
 * - Pending earnings >= $10
 * - Bank account setup completed
 * 
 * Schedule: Every Friday at 6 PM PST
 * Cron: 0 18 * * 5 (minute=0, hour=18, day=*, month=*, dayOfWeek=5)
 */
exports.processWeeklyPayouts = functions.pubsub
    .schedule('0 18 * * 5') // Every Friday at 6 PM PST
    .timeZone('America/Los_Angeles')
    .onRun(async (context) => {
        console.log('🤖 AUTOMATION: Starting weekly payout process...');
        
        try {
            // Get all hosts eligible for payout
            const hostsToPayOut = await getEligibleHosts();
            console.log(`🤖 AUTOMATION: Found ${hostsToPayOut.length} hosts ready for payout`);
            
            let successCount = 0;
            let failureCount = 0;
            const results = [];
            
            // Process each host payout
            for (const hostData of hostsToPayOut) {
                try {
                    const result = await processHostPayout(hostData);
                    results.push(result);
                    successCount++;
                    console.log(`✅ AUTOMATION: Processed payout for ${hostData.hostName}`);
                } catch (error) {
                    console.error(`🔴 AUTOMATION: Failed payout for ${hostData.hostName}:`, error);
                    failureCount++;
                    results.push({
                        hostId: hostData.hostId,
                        hostName: hostData.hostName,
                        success: false,
                        error: error.message
                    });
                }
            }
            
            console.log(`🤖 AUTOMATION: Weekly payouts completed! ✅ Success: ${successCount}, ❌ Failed: ${failureCount}`);
            
            // Send summary to admin
            await sendPayoutSummaryToAdmin(successCount, failureCount, results);
            
            return { success: true, processed: successCount, failed: failureCount };
            
        } catch (error) {
            console.error('🔴 AUTOMATION: Critical error in payout process:', error);
            
            // Send critical error alert to admin
            await sendCriticalErrorAlert(error);
            
            throw new functions.https.HttpsError('internal', 'Payout process failed');
        }
    });

/**
 * Get hosts eligible for payouts (pending earnings >= $10)
 */
async function getEligibleHosts() {
    const hostsSnapshot = await db.collection('hostEarnings')
        .where('pendingEarnings', '>=', 10.0) // Minimum $10 payout
        .get();
    
    const eligibleHosts = [];
    
    for (const doc of hostsSnapshot.docs) {
        const hostEarnings = doc.data();
        
        // CRITICAL: Only pay for non-refunded transactions
        console.log(`🔍 PAYOUT: Analyzing host ${hostEarnings.hostName} (${hostEarnings.hostId})`);
        console.log(`🔍 PAYOUT: Total transactions: ${hostEarnings.transactions?.length || 0}`);
        
        // Filter out refunded transactions
        const validTransactions = (hostEarnings.transactions || []).filter(transaction => {
            const isValid = transaction.status !== 'refunded';
            if (!isValid) {
                console.log(`❌ PAYOUT: Excluding refunded transaction: ${transaction.partyTitle} - Guest: ${transaction.guestName} - $${transaction.hostEarning}`);
            }
            return isValid;
        });
        
        // Calculate actual pending earnings from valid transactions only
        const actualPendingEarnings = validTransactions.reduce((total, transaction) => {
            return total + (transaction.hostEarning || 0);
        }, 0);
        
        console.log(`💰 PAYOUT: Host ${hostEarnings.hostName}:`);
        console.log(`   - Valid transactions: ${validTransactions.length}/${hostEarnings.transactions?.length || 0}`);
        console.log(`   - Database pending: $${hostEarnings.pendingEarnings}`);
        console.log(`   - Actual pending: $${actualPendingEarnings}`);
        
        // Only include if actual pending earnings meet minimum
        if (actualPendingEarnings >= 10.0) {
            // Update the host earnings with corrected pending amount
            const correctedHostEarnings = {
                ...hostEarnings,
                pendingEarnings: actualPendingEarnings,
                transactions: validTransactions
            };
            
            eligibleHosts.push(correctedHostEarnings);
            console.log(`✅ PAYOUT: Host ${hostEarnings.hostName} eligible for $${actualPendingEarnings} payout`);
        } else {
            console.log(`❌ PAYOUT: Host ${hostEarnings.hostName} below minimum after excluding refunds ($${actualPendingEarnings})`);
            
            // Update database to reflect corrected pending earnings
            await db.collection('hostEarnings').doc(hostEarnings.hostId).update({
                pendingEarnings: actualPendingEarnings,
                transactions: validTransactions,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
    }
    
    console.log(`🎯 PAYOUT: Found ${eligibleHosts.length} eligible hosts for payouts`);
    return eligibleHosts;
}

/**
 * Process payout to individual host using ACH transfer
 */
async function processHostPayout(hostEarnings) {
    console.log(`💸 PAYOUT: Processing payout for ${hostEarnings.hostName}: $${hostEarnings.pendingEarnings}`);
    
    try {
        // Get host's bank details from Firestore
        const hostBankDoc = await db.collection('hostBankInfo').doc(hostEarnings.hostId).get();
        
        if (!hostBankDoc.exists) {
            throw new Error(`No bank details found for host ${hostEarnings.hostId}`);
        }
        
        const bankInfo = hostBankDoc.data();
        
        // Process ACH transfer to US bank account
        return await processACHTransfer(hostEarnings, bankInfo);
        
    } catch (error) {
        console.error(`🔴 PAYOUT: Error processing payout for ${hostEarnings.hostName}:`, error);
        
        // Send error notification to admin
        await sendAdminErrorNotification(hostEarnings, error.message);
        
        return {
            id: `payout_${Date.now()}`,
            amount: hostEarnings.pendingEarnings,
            method: 'ach',
            status: 'failed',
            error: error.message,
            hostId: hostEarnings.hostId,
            hostName: hostEarnings.hostName
        };
    }
}

/**
 * Process ACH transfer to US bank account
 */
async function processACHTransfer(hostEarnings, bankInfo) {
    console.log(`🏦 ACH: Processing ACH transfer to ${bankInfo.bankName}`);
    console.log(`🏦 ACH: Account type: ${bankInfo.accountType}`);
    console.log(`🏦 ACH: Amount: $${hostEarnings.pendingEarnings}`);
    
    // TODO: Replace with actual ACH processor (Stripe, Dwolla, etc.)
    // For now, simulate the transfer for testing
    console.log(`🏦 ACH: Simulating $${hostEarnings.pendingEarnings} ACH transfer`);
    console.log(`🏦 ACH: Bank: ${bankInfo.bankName}`);
    console.log(`🏦 ACH: Account: ****${bankInfo.accountNumber?.slice(-4)}`);
    console.log(`🏦 ACH: Routing: ${bankInfo.routingNumber}`);
    
    // In production, this would use a service like:
    /*
    // Option 1: Stripe Connect (if approved for international business)
    const stripe = require('stripe')(functions.config().stripe.secret_key);
    const transfer = await stripe.transfers.create({
        amount: Math.round(hostEarnings.pendingEarnings * 100), // Convert to cents
        currency: 'usd',
        destination: bankInfo.stripeAccountId // Would need to create connected account
    });
    
    // Option 2: Dwolla ACH transfers
    const dwolla = require('dwolla-v2');
    const transfer = await dwolla.post('transfers', {
        _links: {
            source: { href: 'https://api.dwolla.com/funding-sources/YOUR_SOURCE' },
            destination: { href: bankInfo.dwollaFundingSourceUrl }
        },
        amount: {
            currency: 'USD',
            value: hostEarnings.pendingEarnings.toFixed(2)
        }
    });
    */
    
    // Simulate successful ACH transfer
    const payoutResult = {
        id: `ach_${Date.now()}`,
        amount: hostEarnings.pendingEarnings,
        method: 'ach',
        status: 'processing', // ACH transfers are initially processing
        transferId: `ach_${Date.now()}`,
        hostId: hostEarnings.hostId,
        hostName: hostEarnings.hostName,
        bankName: bankInfo.bankName,
        estimatedArrival: new Date(Date.now() + (3 * 24 * 60 * 60 * 1000)) // 3 days from now
    };
    
    // Send notification to host
    await sendPayoutNotification(hostEarnings, payoutResult);
    
    console.log(`✅ ACH: Transfer initiated to ${bankInfo.bankName} - $${hostEarnings.pendingEarnings}`);
    console.log(`✅ ACH: Expected arrival: 1-3 business days`);
    return payoutResult;
}

/**
 * Send payout notification to host
 */
async function sendPayoutNotification(hostEarnings, payoutResult) {
    console.log(`🔔 NOTIFICATION: Sending payout notification to ${hostEarnings.hostName}`);
    
    const message = `💰 Your $${payoutResult.amount} earnings have been sent to your ${payoutResult.bankName} account! It will arrive in 1-3 business days. Transfer ID: ${payoutResult.transferId}`;
    
    // TODO: Send actual push notification via FCM
    console.log(`📱 HOST NOTIFICATION: ${message}`);
    
    // For now, log the notification
    await db.collection('notifications').add({
        userId: hostEarnings.hostId,
        title: '💰 Payout Sent!',
        message: message,
        type: 'payout_sent',
        amount: payoutResult.amount,
        transferId: payoutResult.transferId,
        estimatedArrival: payoutResult.estimatedArrival,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false
    });
}

/**
 * Record successful payout in Firestore
 */
async function recordSuccessfulPayout(hostEarnings, payoutResult) {
    const payoutRecord = {
        id: payoutResult.id,
        amount: payoutResult.amount,
        payoutDate: admin.firestore.Timestamp.now(),
        payoutMethod: payoutResult.method,
        status: payoutResult.status,
        transactionIds: hostEarnings.transactions.map(t => t.id),
        notes: 'Automated weekly payout'
    };
    
    // Update host earnings
    const updatedEarnings = {
        ...hostEarnings,
        pendingEarnings: 0.0, // Reset to 0
        paidEarnings: hostEarnings.paidEarnings + hostEarnings.pendingEarnings,
        lastPayoutDate: admin.firestore.Timestamp.now(),
        payoutHistory: [...(hostEarnings.payoutHistory || []), payoutRecord]
    };
    
    await db.collection('hostEarnings').doc(hostEarnings.hostId).set(updatedEarnings);
    
    console.log(`✅ AUTOMATION: Updated earnings record for ${hostEarnings.hostName}`);
}

/**
 * Send payout confirmation to host via FCM
 */
async function sendPayoutConfirmationToHost(hostEarnings, payoutResult) {
    console.log(`📧 AUTOMATION: Sending payout confirmation to ${hostEarnings.hostName}`);
    
    try {
        // Get host's FCM token
        const userDoc = await db.collection('users').doc(hostEarnings.hostId).get();
        const fcmToken = userDoc.data()?.fcmToken;
        
        if (fcmToken) {
            // Customize notification based on payout method
            const isPayPal = payoutResult.method === 'paypal';
            const message = {
                token: fcmToken,
                notification: {
                    title: isPayPal ? '💰 PayPal Money Sent!' : '💰 Payout Processed!',
                    body: isPayPal ? 
                        `🎉 $${Math.round(payoutResult.amount)} just hit your PayPal! Thanks for being an awesome host! 🚀` :
                        `Your $${Math.round(payoutResult.amount)} payout is on the way! It should arrive within 2-3 business days.`
                },
                data: {
                    type: 'payout_processed',
                    amount: payoutResult.amount.toString(),
                    payoutId: payoutResult.id,
                    method: payoutResult.method,
                    estimatedArrival: payoutResult.estimatedArrival.toISOString(),
                    ...(isPayPal && { paypalEmail: payoutResult.recipientEmail })
                }
            };
            
            await admin.messaging().send(message);
            console.log(`✅ FCM: Payout notification sent to ${hostEarnings.hostName}`);
        } else {
            console.log(`⚠️ FCM: No token found for ${hostEarnings.hostName}`);
        }
    } catch (error) {
        console.error(`🔴 FCM: Failed to send notification to ${hostEarnings.hostName}:`, error);
    }
}

/**
 * Send payout summary to admin
 */
async function sendPayoutSummaryToAdmin(successCount, failureCount, results) {
    console.log(`📊 AUTOMATION: Sending admin summary - Success: ${successCount}, Failed: ${failureCount}`);
    
    // In production, you would send an email or Slack notification to admin
    const summary = {
        date: new Date().toISOString(),
        processed: successCount,
        failed: failureCount,
        totalAmount: results
            .filter(r => r.success)
            .reduce((sum, r) => sum + (r.amount || 0), 0),
        results: results
    };
    
    // Store summary for admin dashboard
    await db.collection('payoutSummaries').add(summary);
    
    // TODO: Send email/Slack notification to admin
}

/**
 * Send critical error alert to admin
 */
async function sendCriticalErrorAlert(error) {
    console.error('🚨 CRITICAL: Sending error alert to admin');
    
    const alert = {
        timestamp: admin.firestore.Timestamp.now(),
        error: error.message,
        stack: error.stack,
        function: 'processWeeklyPayouts',
        severity: 'critical'
    };
    
    await db.collection('errorAlerts').add(alert);
    
    // TODO: Send immediate alert to admin (email, Slack, SMS)
}

/**
 * Send admin error notification
 */
async function sendAdminErrorNotification(hostEarnings, errorMessage) {
    console.error(`🚨 ADMIN ERROR: ${errorMessage} for host ${hostEarnings.hostName}`);
    
    const adminAlert = {
        timestamp: admin.firestore.Timestamp.now(),
        error: errorMessage,
        hostId: hostEarnings.hostId,
        hostName: hostEarnings.hostName,
        severity: 'error',
        function: 'processWeeklyPayouts'
    };
    
    await db.collection('adminErrorAlerts').add(adminAlert);
    
    // TODO: Send immediate alert to admin (email, Slack, SMS)
}

/**
 * Generate random ID
 */
function generateId() {
    return Math.random().toString(36).substr(2, 9);
}

/**
 * MANUAL PAYOUT TRIGGER (for testing or manual runs)
 * 
 * This HTTP function allows admins to manually trigger payouts
 * Usage: POST to https://your-project.cloudfunctions.net/triggerManualPayout
 */
exports.triggerManualPayout = functions.https.onCall(async (data, context) => {
    // Verify admin authentication
    if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    
    console.log('🤖 MANUAL: Admin triggered manual payout process');
    
    try {
        // Use the same logic as the scheduled function
        const hostsToPayOut = await getEligibleHosts();
        console.log(`🤖 MANUAL: Found ${hostsToPayOut.length} hosts ready for payout`);
        
        let successCount = 0;
        let failureCount = 0;
        
        for (const hostData of hostsToPayOut) {
            try {
                await processHostPayout(hostData);
                successCount++;
            } catch (error) {
                console.error(`🔴 MANUAL: Failed payout for ${hostData.hostName}:`, error);
                failureCount++;
            }
        }
        
        console.log(`🤖 MANUAL: Manual payouts completed! ✅ Success: ${successCount}, ❌ Failed: ${failureCount}`);
        
        return { 
            success: true, 
            message: `Processed ${successCount} payouts successfully, ${failureCount} failed` 
        };
        
    } catch (error) {
        console.error('🔴 MANUAL: Error in manual payout process:', error);
        throw new functions.https.HttpsError('internal', 'Manual payout process failed');
    }
});

/**
 * GET PAYOUT STATUS (for admin dashboard)
 * 
 * Returns current payout statistics
 */
exports.getPayoutStatus = functions.https.onCall(async (data, context) => {
    // Verify admin authentication
    if (!context.auth || !context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }
    
    try {
        // Get hosts ready for payout
        const hostsReady = await getEligibleHosts();
        
        // Calculate total pending amount
        const totalPending = hostsReady.reduce((sum, host) => sum + host.pendingEarnings, 0);
        
        // Get recent payout summaries
        const recentSummaries = await db.collection('payoutSummaries')
            .orderBy('date', 'desc')
            .limit(5)
            .get();
        
        const summaries = recentSummaries.docs.map(doc => ({
            id: doc.id,
            ...doc.data()
        }));
        
        return {
            hostsReadyCount: hostsReady.length,
            totalPendingAmount: totalPending,
            recentPayouts: summaries,
            nextPayoutDate: getNextFriday()
        };
        
    } catch (error) {
        console.error('🔴 STATUS: Error getting payout status:', error);
        throw new functions.https.HttpsError('internal', 'Failed to get payout status');
    }
});

/**
 * Get next Friday date
 */
function getNextFriday() {
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0 = Sunday, 5 = Friday
    const daysUntilFriday = (5 + 7 - dayOfWeek) % 7 || 7; // Next Friday
    
    const nextFriday = new Date(now);
    nextFriday.setDate(now.getDate() + daysUntilFriday);
    nextFriday.setHours(18, 0, 0, 0); // 6 PM
    
    return nextFriday.toISOString();
} 