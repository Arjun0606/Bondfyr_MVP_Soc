import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js';
import { getAuth, GoogleAuthProvider, signInWithRedirect, getRedirectResult, onAuthStateChanged, signOut, setPersistence, browserLocalPersistence, signInWithCustomToken } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js';
import { getFirestore, collection, query, where, onSnapshot } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import { getFunctions, httpsCallable } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-functions.js';

// TODO: replace with your actual web config
const firebaseConfig = {
  apiKey: 'AIzaSyAMuqB-EaCUmQYQdjs4PIwtZlWGcEKhtVU',
  authDomain: 'bondfyr-da123.firebaseapp.com',
  projectId: 'bondfyr-da123',
  storageBucket: 'bondfyr-da123.appspot.com',
  messagingSenderId: '210827083189',
  appId: '1:210827083189:web:0de75db527269e06922dfc'
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);
const functions = getFunctions(app);

const signInBtn = document.getElementById('signInBtn');
const signOutBtn = document.getElementById('signOutBtn');
const userInfo = document.getElementById('userInfo');
const userName = document.getElementById('userName');
const userAvatar = document.getElementById('userAvatar');
const pendingList = document.getElementById('pendingList');
const emptyState = document.getElementById('emptyState');
const errorState = document.getElementById('errorState');

function showError(message) {
  if (!errorState) return alert(message);
  errorState.style.display = 'block';
  errorState.textContent = message;
}

signInBtn.onclick = async () => {
  try {
    const provider = new GoogleAuthProvider();
    // Keep user signed in across tabs and redirects
    await setPersistence(auth, browserLocalPersistence);
    // Preserve query string (partyId, uid) across redirect
    sessionStorage.setItem('bf_return_query', window.location.search || '');
    // Always use redirect on iOS Safari; popups are often blocked
    await signInWithRedirect(auth, provider);
  } catch (e) {
    showError(e.message || 'Sign-in failed');
  }
};

signOutBtn.onclick = () => signOut(auth);

// Handle redirect result early to restore query params if needed
getRedirectResult(auth)
  .then((result) => {
    const saved = sessionStorage.getItem('bf_return_query');
    if (saved && !window.location.search) {
      history.replaceState(null, '', saved);
    }
    if (result && result.user) {
      console.log('Redirect sign-in success');
    }
  })
  .catch((err) => {
    console.error('Redirect sign-in error', err);
    showError(err.message || 'Sign-in failed');
  });

// Check for direct HTTP checkout BEFORE auth state changes
(async () => {
  const params = new URLSearchParams(window.location.search);
  const idToken = params.get('idToken');
  const partyId = params.get('partyId');
  
  if (idToken && partyId) {
    // Show immediate visual feedback
    document.title = '🚀 Processing Payment...';
    console.log('🚀 Direct checkout with idToken...');
    try {
      const resp = await fetch('https://us-central1-bondfyr-da123.cloudfunctions.net/createListingCheckoutHTTP', {
        method: 'POST', 
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken, partyId })
      });
      
      if (!resp.ok) {
        const errorText = await resp.text();
        console.error('HTTP checkout failed:', resp.status, errorText);
        showError(`Payment setup failed: ${resp.status}`);
        return;
      }
      
      const data = await resp.json();
      console.log('✅ HTTP checkout response:', data);
      
      if (data.url) {
        console.log('🎯 Redirecting to Dodo:', data.url);
        document.title = '💳 Redirecting to Payment...';
        window.location.href = data.url;
        return;
      } else {
        showError('No payment URL received');
      }
    } catch (e) {
      console.error('❌ Direct HTTP checkout failed:', e);
      showError(`Payment error: ${e.message}`);
    }
  } else {
    // Debug: show what parameters we received
    console.log('📋 URL Parameters:', {
      idToken: idToken ? 'Present (' + idToken.substring(0, 20) + '...)' : 'Missing',
      partyId: partyId || 'Missing', 
      uid: params.get('uid') || 'Missing',
      full_url: window.location.href
    });
  }
})();

onAuthStateChanged(auth, (user) => {
  if (!user) {
    userInfo.classList.add('hidden');
    signInBtn.classList.remove('hidden');
    pendingList.innerHTML = '';
    emptyState.classList.remove('hidden');
    // Auto-start Google sign-in if we came from the app with params (no idToken)
    (async () => {
      const params = new URLSearchParams(window.location.search);
      const hasAppParams = params.get('partyId') && params.get('uid');
      const hasIdToken = params.get('idToken');
      
      if (!hasAppParams || hasIdToken) return; // Skip if no params or if idToken already handled above
      
      try {
        const provider = new GoogleAuthProvider();
        await setPersistence(auth, browserLocalPersistence);
        sessionStorage.setItem('bf_return_query', window.location.search || '');
        await signInWithRedirect(auth, provider);
      } catch (e) { console.warn('Auto sign-in redirect failed', e); }
    })();
    return;
  }
  userName.textContent = user.displayName || user.email;
  if (user.photoURL) userAvatar.src = user.photoURL;
  signInBtn.classList.add('hidden');
  userInfo.classList.remove('hidden');
  
  // Get URL parameters once
  const params = new URLSearchParams(window.location.search);
  const partyIdFromURL = params.get('partyId');
  const uidFromURL = params.get('uid');
  
  // Cleanup old pending parties
  (async () => {
    try {
      if (partyIdFromURL) {
        const clearExcept = httpsCallable(functions, 'clearAllExceptPending');
        const result = await clearExcept({ partyId: partyIdFromURL });
        console.log(`🧹 Auto-cleared others (${result.data.deleted}) keeping ${partyIdFromURL}`);
      } else {
        const clearOld = httpsCallable(functions, 'clearOldPendingParties');
        const result = await clearOld();
        console.log(`🧹 Auto-cleared ${result.data.deleted} stale pending parties (>24h)`);
      }
    } catch (e) {
      console.warn('Auto-cleanup failed:', e);
    }
    
    // Always start with fresh pending list after cleanup
    subscribePending(user.uid);
    
    // If app passed query params (partyId) after submission, open checkout immediately
    if (partyIdFromURL && uidFromURL === user.uid) {
      console.log('🚀 Auto-triggering payment for party:', partyIdFromURL);
      payToPublish(partyIdFromURL);
    }
  })();

  // Make cleanup function available globally for manual use
  window.clearAll = async () => {
    try {
      const clear = httpsCallable(functions, 'clearAllPendingParties');
      const result = await clear();
      console.log(`🧹 Manually cleared ${result.data.deleted} pending parties`);
      window.location.reload();
    } catch (e) {
      console.error('Manual cleanup failed:', e);
    }
  };
});

// As a final fallback for environments blocking Google OAuth screens, allow passing an ID token
// e.g., bondfyr-da123.web.app?partyId=...&uid=...&idToken=...
// If present, exchange ID token for a custom token then sign in silently
(async () => {
  const params = new URLSearchParams(window.location.search);
  const idToken = params.get('idToken');
  if (!idToken) return;
  try {
    const resp = await fetch('https://us-central1-bondfyr-da123.cloudfunctions.net/exchangeIdToken', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: idToken })
    });
    const data = await resp.json();
    if (data.customToken) {
      // Firebase v10 uses signInWithCustomToken via modular import; use dynamic import
      const { signInWithCustomToken } = await import('https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js');
      await signInWithCustomToken(auth, data.customToken);
      // After silent sign-in, auto-open checkout if query has partyId and matches uid
      const partyId = params.get('partyId');
      const uid = params.get('uid');
      if (partyId && auth.currentUser && auth.currentUser.uid === uid) {
        payToPublish(partyId);
      }
    }
  } catch (e) {
    console.warn('Silent custom-token sign-in failed', e);
  }
})();

function subscribePending(uid) {
  const q = query(collection(db, 'pendingParties'), where('hostId', '==', uid));
  onSnapshot(q, (snap) => {
    pendingList.innerHTML = '';
    if (snap.empty) {
      emptyState.classList.remove('hidden');
      return;
    }
    emptyState.classList.add('hidden');
    snap.forEach((doc) => renderRow(doc.id, doc.data()));
  });
}

function renderRow(id, p) {
  const el = document.createElement('div');
  el.className = 'row';
  const fee = computeFee(p.maxGuestCount, p.ticketPrice);
  el.innerHTML = `
    <div>
      <div class="title">${escapeHtml(p.title || 'Untitled')}</div>
      <div class="meta">${new Date(p.selectedDate?.seconds ? p.selectedDate.seconds*1000 : Date.now()).toLocaleString()} • $${Number(p.ticketPrice || 0).toFixed(2)} / guest • Capacity ${p.maxGuestCount}</div>
    </div>
    <div class="actions">
      <span class="badge">Listing fee $${fee.toFixed(2)}</span>
      <button class="btn success" data-id="${id}">Pay to Publish</button>
    </div>`;
  el.querySelector('button').onclick = () => payToPublish(id);
  pendingList.appendChild(el);
}

function computeFee(maxGuests, ticketPrice) {
  const half = Number(maxGuests || 0) / 2.0;
  const total = half * Number(ticketPrice || 0);
  return total * 0.20; // same formula
}

async function payToPublish(partyId) {
  try {
    const call = httpsCallable(functions, 'createListingCheckout');
    const res = await call({ partyId });
    const url = res.data?.url;
    if (!url) throw new Error('Payment URL not returned');
    window.location.href = url;
  } catch (e) {
    alert(e.message || 'Failed to create checkout');
  }
}

function escapeHtml(str) {
  return String(str).replace(/[&<>"]+/g, (c) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
}


