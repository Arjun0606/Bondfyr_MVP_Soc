const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const stripe = require('stripe')(functions.config().stripe?.secret_key);

admin.initializeApp();

const GOOGLE_PLACES_API_KEY = functions.config().google.places_key; // Set this in Firebase env
const USER_THRESHOLD = 5000; // Switch to Stripe after this many users

// Track user count and determine payment method
exports.getUserCount = functions.https.onCall(async (data, context) => {
  try {
    const usersSnapshot = await admin.firestore().collection('users').get();
    const userCount = usersSnapshot.size;
    
    // Store current user count in a system collection for quick access
    await admin.firestore().collection('system').doc('metrics').set({
      totalUsers: userCount,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      paymentMethod: userCount >= USER_THRESHOLD ? 'stripe' : 'free'
    }, { merge: true });
    
    return {
      userCount,
      paymentMethod: userCount >= USER_THRESHOLD ? 'stripe' : 'free',
      threshold: USER_THRESHOLD
    };
  } catch (error) {
    console.error('Error getting user count:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get user count');
  }
});

// Process payment based on current user count
exports.processPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { ticketData, paymentMethod } = data;
  
  try {
    // Get current payment method
    const metricsDoc = await admin.firestore().collection('system').doc('metrics').get();
    const currentPaymentMethod = metricsDoc.exists ? metricsDoc.data().paymentMethod : 'free';
    
    if (currentPaymentMethod === 'free') {
      // Free payment - just create the ticket
      const ticketRef = await admin.firestore().collection('tickets').add({
        ...ticketData,
        userId: context.auth.uid,
        paymentMethod: 'free',
        paymentStatus: 'completed',
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return {
        success: true,
        ticketId: ticketRef.id,
        paymentMethod: 'free'
      };
    } else {
      // Stripe payment
      if (!paymentMethod || !paymentMethod.stripePaymentIntentId) {
        throw new functions.https.HttpsError('invalid-argument', 'Stripe payment intent required');
      }
      
      // Verify payment intent with Stripe
      const paymentIntent = await stripe.paymentIntents.retrieve(paymentMethod.stripePaymentIntentId);
      
      if (paymentIntent.status !== 'succeeded') {
        throw new functions.https.HttpsError('failed-precondition', 'Payment not completed');
      }
      
      // Create ticket with Stripe payment info
      const ticketRef = await admin.firestore().collection('tickets').add({
        ...ticketData,
        userId: context.auth.uid,
        paymentMethod: 'stripe',
        paymentStatus: 'completed',
        stripePaymentIntentId: paymentIntent.id,
        amount: paymentIntent.amount,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return {
        success: true,
        ticketId: ticketRef.id,
        paymentMethod: 'stripe',
        stripePaymentIntentId: paymentIntent.id
      };
    }
  } catch (error) {
    console.error('Payment processing error:', error);
    throw new functions.https.HttpsError('internal', 'Payment processing failed');
  }
});

// Create Stripe Payment Intent
exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { amount, currency = 'usd' } = data;
  
  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // Amount in cents
      currency: currency,
      metadata: {
        userId: context.auth.uid
      }
    });
    
    return {
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id
    };
  } catch (error) {
    console.error('Stripe payment intent creation error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create payment intent');
  }
});

// Update user count when new user signs up
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
  try {
    // Update user count in system metrics
    await admin.firestore().collection('system').doc('metrics').update({
      totalUsers: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Update payment method if we've crossed the threshold
    const metricsDoc = await admin.firestore().collection('system').doc('metrics').get();
    if (metricsDoc.exists) {
      const currentCount = metricsDoc.data().totalUsers;
      if (currentCount >= USER_THRESHOLD) {
        await admin.firestore().collection('system').doc('metrics').update({
          paymentMethod: 'stripe'
        });
      }
    }
  } catch (error) {
    console.error('Error updating user count:', error);
  }
});

exports.scrapeVenuesForCity = functions.https.onCall(async (data, context) => {
  const city = data.city;
  if (!city) {
    throw new functions.https.HttpsError('invalid-argument', 'City is required');
  }

  const types = ['night_club', 'bar'];
  let venues = [];
  let nextPageToken = null;
  let page = 0;

  do {
    let url = `https://maps.googleapis.com/maps/api/place/textsearch/json?query=${encodeURIComponent(types.join(' OR ') + ' in ' + city)}&key=${GOOGLE_PLACES_API_KEY}`;
    if (nextPageToken) url += `&pagetoken=${nextPageToken}`;

    const res = await axios.get(url);
    if (res.data.status !== 'OK' && res.data.status !== 'ZERO_RESULTS') {
      throw new functions.https.HttpsError('internal', `Google Places error: ${res.data.status}`);
    }
    venues = venues.concat(res.data.results);

    nextPageToken = res.data.next_page_token;
    page++;
    if (nextPageToken) await new Promise(r => setTimeout(r, 2000)); // Google API requires delay
  } while (nextPageToken && page < 3);

  // Filter and map results
  const venueDocs = venues
    .filter(v => v.types.includes('night_club') || v.types.includes('bar'))
    .map(v => ({
      venueId: v.place_id,
      venueName: v.name,
      address: v.formatted_address,
      placeId: v.place_id,
      totalReviews: v.user_ratings_total || 0,
      averageRating: v.rating || 0,
      photoUrl: v.photos && v.photos[0] ? `https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${v.photos[0].photo_reference}&key=${GOOGLE_PLACES_API_KEY}` : null,
      location: v.geometry && v.geometry.location ? v.geometry.location : null,
      types: v.types
    }));

  // Write to Firestore
  const batch = admin.firestore().batch();
  const cityKey = city.toLowerCase().replace(/[^a-z0-9]/g, '_');
  const venuesRef = admin.firestore().collection('venues').doc(cityKey).collection('venueList');
  venueDocs.forEach(venue => {
    batch.set(venuesRef.doc(venue.venueId), venue, { merge: true });
  });
  await batch.commit();

  return { count: venueDocs.length, city: cityKey };
});