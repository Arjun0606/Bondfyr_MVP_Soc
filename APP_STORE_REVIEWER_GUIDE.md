# App Store Reviewer Guide - Bondfyr

## Overview
Bondfyr is a social party discovery app that connects people through local events and gatherings.

## Authentication Options
The app provides three sign-in methods to comply with App Store Guidelines 4.8:

### 1. 🍎 Sign in with Apple (Primary - Guideline 4.8 Compliant)
- **Privacy First**: Limits data collection to name and email
- **Email Protection**: Allows users to hide email address using Apple's private relay
- **No Tracking**: Does not collect interactions for advertising without consent
- **Location**: Prominent button at the top of sign-in screen

### 2. 🔍 Sign in with Google (Alternative)
- Traditional OAuth flow
- Collects name and email for profile creation

### 3. 🎭 Demo Mode (For App Review)
- **Toggle**: "Demo Mode (App Review)" toggle at top of sign-in screen
- **Purpose**: Provides full app functionality without real accounts
- **Button**: "Continue as Demo User" (orange button when demo mode enabled)
- **Features**: 
  - Pre-populated demo parties
  - Full host and guest functionality
  - No real payments or external dependencies

## How to Test the App

### For Reviewers - Recommended Flow:
1. **Launch app** → Will show sign-in screen (forced clean state)
2. **Enable Demo Mode** → Toggle "Demo Mode (App Review)" to ON
3. **Tap "Continue as Demo User"** → Creates anonymous account with demo data
4. **Complete profile** → Fill in demo user information
5. **Explore app** → See demo parties, hosting features, guest features

### Full Authentication Test:
1. **Sign in with Apple** → Test privacy-compliant authentication
2. **Complete profile** → Add username, gender, location
3. **Create party** → Test host functionality (uses web portal for listing fees)
4. **Join party** → Test guest functionality

## Key Features to Review:

### 🎉 Party Discovery
- Browse local parties and events
- Filter by date, location, and preferences
- Real-time updates and availability

### 🏠 Host Features
- Create and manage parties
- Set guest limits and approval requirements
- Handle payments through external web portal (bypasses IAP)
- Guest management and communication

### 👥 Guest Features  
- Request to join parties
- P2P payments (Venmo, PayPal, Cash App, Apple Pay)
- Event check-in and photo sharing
- Rating and review system

### 🛡️ Safety Features
- Age verification (18+ required)
- Report functionality
- Host verification system
- Location-based matching

## Monetization (App Store Compliant)
- **Listing Fees**: Hosts pay via external web portal (not IAP)
- **P2P Payments**: Direct between users (Venmo, PayPal, etc.)
- **No In-App Purchases**: Avoids Apple's IAP requirements

## Privacy & Data Protection
- Minimal data collection
- Location used only for party discovery
- Photos remain private until user chooses to share
- Apple Sign-In offers maximum privacy protection

## Technical Notes
- **Anonymous Auth**: Enabled for demo mode
- **Firestore**: Backend database
- **Firebase Auth**: User authentication
- **Push Notifications**: Party updates and notifications
- **Deep Linking**: Web portal to app redirection

## Contact for Issues
- **Developer**: Arjun Varma
- **Email**: karjunvarma2001@gmail.com
- **Support**: Built-in help section with FAQ and bug reporting

---

**For App Store Reviewers**: Use Demo Mode for the fastest and most comprehensive review experience. All features are fully functional without requiring real accounts or payments.
