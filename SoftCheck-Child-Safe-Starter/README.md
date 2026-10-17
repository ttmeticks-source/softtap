# SoftCheck Child-Safe Starter (v0.2)

A safer pre-launch foundation for a child-directed Android/iOS app using Expo React Native and Supabase.

## What this build does

- Parent/guardian account sign-up and sign-in foundation through Supabase Auth
- A parent-facing setup screen and privacy explainer
- Local-only mood check-in demo (does not upload the child's mood/note)
- Explicitly keeps child profiles, online friend discovery, messages, videos and push notifications disabled
- SQL schema for future guardian consent, child profiles, check-ins, friendships, messages, blocks and reports
- Intentionally denies direct client access to consent and child social tables until server-side rules are implemented

## This is NOT ready for public child accounts

The parent screen is not a verifiable-consent mechanism. It only creates a parent account. Before a child profile or any child data is collected, implement and review a consent workflow that verifies the adult, provides direct notice, records the precise consent scope, supports revocation, and lets parents review/delete child data. For a child-directed app, obtain qualified legal/privacy advice for every launch region.

The sample `socialEnabled` toggle is just a UI demo; it does not turn on backend social features. Do not remove the backend restrictions simply to make the buttons work.

## Setup

1. Install Node.js LTS: https://nodejs.org/
2. Create a Supabase project: https://supabase.com/dashboard
3. Open SQL Editor and run `supabase/schema.sql`.
4. Copy `.env.example` to `.env`, then add the Supabase Project URL and publishable/anon key.
5. Never use the Supabase `service_role` secret in the app or a public repo.
6. Run:
   ```bash
   npm install
   npx expo start
   ```
7. Use Expo Go on a test phone for development.

## Required before real children can use it

- **Verifiable parental consent:** implement with a vetted provider or legally reviewed server-side flow. Email verification alone may not be enough for the intended disclosures.
- **Parent dashboard:** parent can see, manage, export where required, and delete the child's data; revoke consent; and switch each social feature on/off.
- **Adult action for social features:** follow the relevant app-store rules before enabling chat, friend requests, user-generated media or information exchange.
- **Strict authorization:** every server operation must check verified consent, parent controls, accepted friendship, blocks and moderation state. Do not rely on hidden buttons or client-side checks.
- **Friend-only messages:** no random chat, anonymous chat, public child directory or strangers messaging children. Consider contact codes/parent-approved connections rather than discoverable profiles.
- **Video safety:** leave video uploads disabled initially. Images/video/audio can expose a child's identity and metadata. If later enabled, obtain the required consent, remove metadata, scan/moderate uploads before publication, restrict storage and provide takedown/reporting.
- **Trust & safety operations:** block/report, a staffed moderation process, escalation procedures, abuse rate limits, clear community rules, and a response path for safety concerns.
- **Data minimization:** no precise location, contact-book upload, targeted ads, unnecessary analytics or third-party SDKs. Define deletion and retention rules.
- **Legal and store readiness:** child-specific privacy policy, terms, community guidelines, support contact, data-safety disclosures, age-appropriate content ratings, and review against Apple Kids / Google Play Families policies.

## Current limitations

The consent server/verification, parent-child account provisioning, online check-ins, friend requests, real-time messages, video uploads, push notifications, account deletion, moderation dashboard and app-store submission are not implemented. The SQL schema is a starting design, not a certification of legal compliance or security.
