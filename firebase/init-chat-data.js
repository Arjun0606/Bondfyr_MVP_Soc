const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize the app
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Initial city data
const cities = [
  { id: 'mumbai', name: 'mumbai', displayName: 'Mumbai', memberCount: 0 },
  { id: 'delhi', name: 'delhi', displayName: 'Delhi', memberCount: 0 },
  { id: 'bangalore', name: 'bangalore', displayName: 'Bangalore', memberCount: 0 },
  { id: 'pune', name: 'pune', displayName: 'Pune', memberCount: 0 },
  { id: 'hyderabad', name: 'hyderabad', displayName: 'Hyderabad', memberCount: 0 },
  { id: 'chennai', name: 'chennai', displayName: 'Chennai', memberCount: 0 },
  { id: 'kolkata', name: 'kolkata', displayName: 'Kolkata', memberCount: 0 },
  { id: 'ahmedabad', name: 'ahmedabad', displayName: 'Ahmedabad', memberCount: 0 },
  { id: 'jaipur', name: 'jaipur', displayName: 'Jaipur', memberCount: 0 },
  { id: 'surat', name: 'surat', displayName: 'Surat', memberCount: 0 }
];

// System messages for each city
const systemMessages = [
  {
    text: 'Welcome to the city chat! Connect with others attending events in this city.',
    isSystemMessage: true
  },
  {
    text: 'Please be respectful and follow our community guidelines.',
    isSystemMessage: true
  },
  {
    text: 'Use this chat to find event buddies or discuss upcoming events!',
    isSystemMessage: true
  }
];

// Function to initialize city data
async function initializeCityData() {
  const batch = db.batch();
  
  // Add cities
  cities.forEach(city => {
    const cityRef = db.collection('chat_cities').doc(city.id);
    city.lastActiveTimestamp = admin.firestore.Timestamp.now();
    batch.set(cityRef, city);
    
    // Add system messages for each city
    systemMessages.forEach(message => {
      const messageRef = db.collection('chat_messages').doc();
      const timestamp = admin.firestore.Timestamp.now();
      batch.set(messageRef, {
        id: messageRef.id,
        cityId: city.id,
        userId: 'system',
        displayName: 'System',
        text: message.text,
        timestamp: timestamp,
        isSystemMessage: message.isSystemMessage,
        eventId: null
      });
    });
  });
  
  // Commit the batch
  await batch.commit();
  console.log('City data and system messages initialized successfully!');
}

// Initialize event chat data for existing events
async function initializeEventChatData() {
  try {
    // Get all events
    const eventsSnapshot = await db.collection('events').get();
    
    if (eventsSnapshot.empty) {
      console.log('No events found to initialize event chats.');
      return;
    }
    
    const batch = db.batch();
    
    eventsSnapshot.forEach(doc => {
      const eventData = doc.data();
      const eventId = doc.id;
      
      // Create event chat document
      const eventChatRef = db.collection('event_chats').doc(eventId);
      batch.set(eventChatRef, {
        id: eventId,
        eventId: eventId,
        name: eventData.name || 'Event Chat',
        memberCount: 0,
        lastActiveTimestamp: admin.firestore.Timestamp.now()
      });
      
      // Add welcome system message for the event
      const messageRef = db.collection('chat_messages').doc();
      batch.set(messageRef, {
        id: messageRef.id,
        cityId: '',
        userId: 'system',
        displayName: 'System',
        text: `Welcome to the ${eventData.name || 'event'} chat! Connect with others attending this event.`,
        timestamp: admin.firestore.Timestamp.now(),
        isSystemMessage: true,
        eventId: eventId
      });
    });
    
    // Commit the batch
    await batch.commit();
    console.log('Event chat data initialized successfully!');
  } catch (error) {
    console.error('Error initializing event chat data:', error);
  }
}

// Run initialization
Promise.all([
  initializeCityData(),
  initializeEventChatData()
])
.then(() => {
  console.log('Chat data initialization complete!');
  process.exit(0);
})
.catch(error => {
  console.error('Error during initialization:', error);
  process.exit(1);
}); 