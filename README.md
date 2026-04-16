# coupleapp_v1

A new Flutter project.

## Social Login Setup

This app now supports Google, Apple, and KakaoTalk login with Supabase.

### App callback URL

- App redirect URL: `com.coupleduty.app://login-callback`
- Add this value to Supabase Auth > URL Configuration > Additional Redirect URLs.

### Supabase Auth provider setup

Enable these providers in Supabase Auth:

- Google
- Apple
- Kakao

#### Apple provider fields in Supabase

Use these values in `Authentication -> Providers -> Apple`:

- Enabled: `On`
- Client ID / Client IDs:
	- `com.coupleduty.app` for native iOS/macOS Apple login
	- `com.coupleduty.app.login` for Apple OAuth / Services ID
- Secret Key (for OAuth): paste the generated JWT from `scripts/generate_apple_client_secret.js`

If the Supabase dashboard only shows a single `Client ID` field, enter `com.coupleduty.app` first for native iOS testing.
If it supports multiple client IDs, register both values above.

For each provider, the OAuth callback URL you register in the provider console should be:

- `https://kjjrpmnnyxrdeikvcjkv.supabase.co/auth/v1/callback`

### Provider notes

- Google:
	- On iOS, this app now uses native Google sign-in with `google_sign_in` and then exchanges the Google ID token with Supabase.
	- On Android and other platforms, Google still uses Supabase OAuth.
	- In Google Cloud, create an OAuth client of type `Web application`.
	- For iOS native login, also create an iOS OAuth client for bundle ID `com.coupleduty.app`.
	- Add Authorized redirect URI: `https://kjjrpmnnyxrdeikvcjkv.supabase.co/auth/v1/callback`
	- In Supabase `Authentication -> Providers -> Google`, use that Web application's `Client ID` and `Client Secret`.
	- If Supabase supports multiple Google client IDs, keep the Web client first, then add the iOS client ID.
	- If Supabase Google native login fails with audience errors, verify the iOS client ID is also registered in Supabase.
- Apple:
	- For native iOS/macOS login with `signInWithIdToken`, Supabase must accept the Apple token audience for the app's App ID / bundle ID: `com.coupleduty.app`.
	- For web or browser OAuth, use the Apple Services ID `com.coupleduty.app.login` and generated secret key.
	- If Supabase returns `Unacceptable audience in id_token: [com.coupleduty.app]`, the Apple provider is still configured for the Services ID only.
- Kakao:
	- In Kakao Developers, use the app `REST API key` as the `Client ID`.
	- Use `Kakao Login Client Secret` as the `Client Secret`.
	- Add Redirect URI: `https://kjjrpmnnyxrdeikvcjkv.supabase.co/auth/v1/callback`
	- Turn on `Kakao Login` and enable consent items you need such as `profile_nickname`, `profile_image`, and optionally `account_email`.
	- If you do not request `account_email`, enable `Allow users without an email` in the Supabase Kakao provider.

#### Google provider fields in Supabase

Use these values in `Authentication -> Providers -> Google`:

- Enabled: `On`
- Client ID: your Google Cloud `Web application` OAuth Client ID
- Client Secret: your Google Cloud `Web application` OAuth Client Secret
- Additional client IDs if supported: add the iOS OAuth Client ID for `com.coupleduty.app`

Google Cloud setup summary:

- Google Auth Platform -> Branding: set app name and support email
- Google Auth Platform -> Audience: choose `External`
- Google Auth Platform -> Data Access / Scopes: add `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile`
- Google Auth Platform -> Clients: create `Web application`
- Authorized redirect URIs:
	- `https://kjjrpmnnyxrdeikvcjkv.supabase.co/auth/v1/callback`

#### Kakao provider fields in Supabase

Use these values in `Authentication -> Providers -> Kakao`:

- Enabled: `On`
- Client ID: Kakao `REST API key`
- Client Secret: Kakao Login `Client Secret`
- Allow users without an email: `On` only if you are not requesting `account_email`

Kakao Developers setup summary:

- App Settings -> App: create app and fill basic info
- Product Settings -> Kakao Login -> General: set Kakao Login `ON`
- Product Settings -> Kakao Login -> Redirect URI:
	- `https://kjjrpmnnyxrdeikvcjkv.supabase.co/auth/v1/callback`
- Product Settings -> Kakao Login -> Consent Items:
	- `profile_nickname`
	- `profile_image`
	- `account_email` if you want email login identity

### Generate Apple client secret locally

You can generate the Apple client secret JWT locally with:

```bash
node scripts/generate_apple_client_secret.js \
	--team-id YOUR_TEAM_ID \
	--key-id YOUR_KEY_ID \
	--client-id com.coupleduty.app.login \
	--key-file /absolute/path/to/AuthKey_XXXXXXXXXX.p8
```

Notes:

- `team-id`: your Apple Developer Team ID
- `key-id`: the Key ID of your Sign in with Apple key
- `client-id`: your Apple Services ID, for this app `com.coupleduty.app.login`
- `key-file`: the downloaded `.p8` file path
- Output JWT goes into Supabase Apple provider `Secret Key (for OAuth)`
- Apple OAuth secrets expire, so regenerate before 180 days

### Current login behavior

- Google and Kakao buttons are shown on all platforms.
- Apple button is shown on web, iOS, and macOS.
- Email/password login remains available.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
