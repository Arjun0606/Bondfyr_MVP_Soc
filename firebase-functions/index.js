const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

const GOOGLE_PLACES_API_KEY = functions.config().google.places_key; // Set this in Firebase env

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