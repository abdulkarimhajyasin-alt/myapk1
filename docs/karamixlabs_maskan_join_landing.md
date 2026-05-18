# Karamix Labs Maskan Join Landing Page

Host a simple static page at:

```text
https://karamixlabs.com/maskan/join
```

The app uses this HTTPS URL in QR codes and share messages because Telegram,
WhatsApp, SMS, and email reliably detect HTTPS links. Maskan also supports the
custom app scheme `maskan://join/{networkId}`, but chat apps often leave custom
schemes as plain text.

Suggested page behavior:

- Read the `network` query parameter.
- Show the Maskan app name and Karamix Labs branding.
- Tell the user to install Maskan first.
- Tell the user to open the invite on a phone with Maskan installed.
- Show a copyable network code from the `network` query parameter.
- Do not ask for Supabase secrets or private credentials.

Minimal copy:

```text
Join a Maskan network

Install Maskan on your phone, then open this invite again.
If the app does not open automatically, copy this network code and use Scan
Invite or Join Network inside Maskan.

Network code: {network}

Powered by Karamix Labs
```

Android can dispatch this URL to the app through the existing intent filter.
Verified Android App Links with `assetlinks.json` can be added later; the app
does not require verified links for the current QR scanner flow.
