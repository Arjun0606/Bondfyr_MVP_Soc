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

// OPTIMIZED: Direct checkout with loading overlay and faster redirect
(async () => {
  const params = new URLSearchParams(window.location.search);
  const idToken = params.get('idToken');
  const partyId = params.get('partyId');
  
  if (idToken && partyId) {
    // Hide entire page and show loading overlay for instant feedback
    document.body.innerHTML = `
      <div style="
        position: fixed; top: 0; left: 0; width: 100%; height: 100%; 
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        display: flex; flex-direction: column; align-items: center; justify-content: center;
        color: white; font-family: -apple-system, BlinkMacSystemFont, sans-serif; z-index: 9999;
      ">
        <img src="bondfyr-logo.png" alt="Bondfyr" style="
          width: 120px; height: 120px; margin-bottom: 2rem; border-radius: 20px;
          box-shadow: 0 8px 32px rgba(0,0,0,0.3); animation: pulse 2s ease-in-out infinite;
        ">
        <h2 style="margin: 0 0 1rem 0; font-weight: 600; font-size: 1.5rem;">Processing Payment...</h2>
        <p style="margin: 0; opacity: 0.8; font-size: 1rem;">Redirecting to secure payment...</p>
        <div style="margin-top: 2rem; width: 200px; height: 4px; background: rgba(255,255,255,0.3); border-radius: 2px; overflow: hidden;">
          <div style="width: 100%; height: 100%; background: white; border-radius: 2px; animation: slide 1.5s ease-in-out infinite;"></div>
        </div>
      </div>
      <style>
        @keyframes slide { 0%, 100% { transform: translateX(-100%); } 50% { transform: translateX(100%); } }
        @keyframes pulse { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.05); } }
      </style>
    `;
    
    console.log('🚀 Express checkout with idToken...');
    
    try {
      // Start timer for UX tracking
      const startTime = Date.now();
      
      const resp = await fetch('https://us-central1-bondfyr-da123.cloudfunctions.net/createListingCheckoutHTTP', {
        method: 'POST', 
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken, partyId })
      });
      
      const processingTime = Date.now() - startTime;
      console.log(`⚡ Payment setup completed in ${processingTime}ms`);
      
      if (!resp.ok) {
        const errorText = await resp.text();
        console.error('Payment setup failed:', resp.status, errorText);
        document.body.innerHTML = `
          <div style="padding: 2rem; text-align: center; color: #e74c3c; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">
            <img src="bondfyr-logo.png" alt="Bondfyr" style="width: 80px; height: 80px; border-radius: 16px; margin-bottom: 1rem;">
            <h3 style="color: white; margin: 0 0 1rem 0;">Payment Setup Failed</h3>
            <p style="color: rgba(255,255,255,0.8); margin: 0 0 2rem 0;">Error ${resp.status}: Please try again</p>
            <button onclick="window.close()" style="margin-top: 1rem; padding: 0.75rem 1.5rem; background: #3498db; color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 1rem;">Close</button>
          </div>
        `;
        return;
      }
      
      const data = await resp.json();
      console.log('✅ Payment URL ready:', data.url ? 'Success' : 'Failed');
      
      if (data.url) {
        // Add brief delay for smooth transition, then redirect
        setTimeout(() => {
          console.log('🎯 Redirecting to Dodo payment...');
          window.location.href = data.url;
        }, 500);
      } else {
        throw new Error('No payment URL received from server');
      }
    } catch (e) {
      console.error('❌ Express checkout failed:', e);
      document.body.innerHTML = `
        <div style="padding: 2rem; text-align: center; color: #e74c3c; display: flex; flex-direction: column; align-items: center; justify-content: center; min-height: 100vh; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">
          <img src="bondfyr-logo.png" alt="Bondfyr" style="width: 80px; height: 80px; border-radius: 16px; margin-bottom: 1rem;">
          <h3 style="color: white; margin: 0 0 1rem 0;">Connection Error</h3>
          <p style="color: rgba(255,255,255,0.8); margin: 0 0 2rem 0;">${e.message}</p>
          <button onclick="window.location.reload()" style="margin-top: 1rem; padding: 0.75rem 1.5rem; background: #3498db; color: white; border: none; border-radius: 8px; cursor: pointer; font-size: 1rem;">Retry</button>
        </div>
      `;
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


