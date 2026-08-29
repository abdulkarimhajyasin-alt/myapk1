# Maskan Google Play Reviewer Access Plan

## When a reviewer account is required

Create a production fixture only immediately before review if Play Console
cannot exercise the app without credentials. Do not hardcode reviewer
credentials in Flutter, Git, CI logs, screenshots, or this document.

## Fixture shape

- One dedicated network with neutral sample data.
- One non-owner reviewer member with a unique password.
- Optional separate owner fixture only if Google explicitly needs to review
  owner-only controls.
- No real user names, expenses, avatars, email addresses, or reused passwords.

## Play Console instructions

Store the network name, member display name, member password, and concise login
steps only in Play Console's App access section. Mark that the app requires an
internet connection.

Reviewer steps:

1. Open My Account.
2. Select the supplied network and member.
3. Enter the supplied personal password.
4. Continue to the account.
5. The Delete Account control is at the bottom of the authenticated account
   screen.

## Lifecycle

- Verify the fixture immediately before submission.
- Do not rotate it while review is active unless Play is notified.
- Remove the fixture after review through the same verified deletion path.
- Confirm the Auth user, member/private rows, and avatar prefix are gone.
