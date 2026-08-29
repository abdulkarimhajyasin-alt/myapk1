# Maskan External Account Deletion Contract

Required public URL:
https://karamixlabs.com/maskan/delete-account

Status on 2026-08-26: website implementation is required outside this
repository. Do not place a service-role key in browser code.

## User flow

1. Explain what is deleted, what shared financial history is anonymized and
   retained, and the owner rules.
2. Ask for network name, member name, and member password.
3. Use the existing public maskan-password verify_member flow to verify the
   member and synchronize the technical Supabase Auth identity.
4. Sign in through Supabase Auth with the resulting member identity, then
   complete the existing one-use maskan_claim_member binding.
5. Invoke maskan-delete-account with the authenticated user's JWT, the member
   password, and confirmNetworkDeletion=true only after an explicit
   sole-member network warning.
6. On success, clear the browser Supabase session and show a completion
   receipt. Do not claim success on timeout or an ambiguous response.

## Backend contract

Endpoint: Supabase Edge Function maskan-delete-account

Method: POST

Headers:

- Authorization: Bearer authenticated-user-JWT
- Supabase public anon apikey
- Content-Type: application/json

Body:

    {
      "memberPassword": "user-entered password",
      "confirmNetworkDeletion": false
    }

The website must never send memberId, networkId, or authUserId as deletion
authority. The backend derives the account from the JWT and the database
destructive RPC derives it again from auth.uid().

Success:

    { "ok": true }

Expected safe error codes:

- authentication_required
- invalid_credentials
- reauthentication_required
- rate_limited
- owner_transfer_required
- network_confirmation_required
- operation_failed

## Security requirements

- Keep SUPABASE_SERVICE_ROLE_KEY only in Supabase Edge secrets.
- Never log passwords, claim/deletion tokens, JWTs, user IDs, avatar paths, or
  backend bodies.
- Use HTTPS, CSRF-safe same-origin form handling, strict CSP, and no third-party
  analytics on the deletion form unless separately disclosed/consented.
- Do not store the entered password or deletion body in browser persistence.
- Treat operation_failed and network timeouts as unconfirmed; allow a safe
  retry.
