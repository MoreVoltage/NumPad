# Update notifications: activation and sending

The app integration is prepared on `codex/update-notifications`, stacked on the dismissible
What's New banner in PR #12. Remote delivery is not active until the Apple/Firebase account
configuration below is complete and a build containing this integration reaches devices.
No campaign has been sent by this change.

## Configuration

| Item | Value |
| --- | --- |
| Existing Firebase project | `numpad-24848` |
| Main app bundle ID | `com.morevoltage.NumPad` |
| Apple team in this Xcode project | `NNRNHY2N8B` — verify against the signing account |
| App Store audience | `numpad_updates_v1` |
| Debug / TestFlight audience | `numpad_updates_test_v1` |
| Default notification destination | `https://apps.apple.com/app/id1072547160` |
| Messaging SDK | `FirebaseMessaging 11.15.0`, matching the existing Firebase version |

Messaging is linked only into the main app. It does not add Firebase to the keyboard or require
Full Access. The existing Firebase project handles delivery; this change needs no custom server.

## Activate Apple-to-Firebase delivery

An account owner with Apple Developer and Firebase project access must complete these steps.
Those administration connections were not available during implementation.

1. In Apple Developer **Certificates, Identifiers & Profiles**, verify the team and enable
   **Push Notifications** for the explicit app identifier `com.morevoltage.NumPad`.
2. Create or select an APNs authentication key authorized for this app. Keep its `.p8` file in
   your credential storage. Record the Key ID and Team ID. Do not commit the key or paste it
   into a PR, issue, or chat.
3. Open the [existing Firebase project](https://console.firebase.google.com/project/numpad-24848/overview),
   then **Project settings → Cloud Messaging → Apple app configuration**. Upload the key
   directly for `com.morevoltage.NumPad`, with its Key ID and Team ID. Ensure credentials cover
   the development environment for development builds and production for TestFlight/App Store
   builds; use the appropriate upload slots for your key's scope. Firebase documents the key
   upload in its [Apple setup guide](https://firebase.google.com/docs/cloud-messaging/ios/client).
4. Build the main app with an updated provisioning profile containing the push entitlement.
   The project includes the Push Notifications capability and `aps-environment = development`;
   Xcode signing/export selects the entitlement appropriate to the distribution profile.
   Check the signed archive uses production for TestFlight/App Store. The keyboard target
   needs no push capability. See [Apple's registration guide](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns).
5. Publish the revised privacy policy and review App Store Connect's App Privacy answers before
   releasing. The app manifest now includes the installation identifier as Device ID, linked,
   for app functionality, without tracking. The implementation does not attach names, emails,
   or typed content. Review the complete app's existing Firebase collection as well when
   answering Apple's form; this manifest addition does not replace the submission form.

## Verify on an iPhone before release

1. Install a development or TestFlight build. In the main app, use **Turn on updates** on the
   What's New sheet, or **Update Notifications → App updates**. Accept the system prompt.
   Permission granted for the old local reminder alone does not subscribe existing users.
2. Wait for **On** in Update Notifications. This confirms the device token and topic
   subscription succeeded; it does not prove Firebase has valid APNs credentials.
3. In Debug/TestFlight, tap **Copy notification test code**. Paste it into the Firebase
   Notifications composer's single-device test field. The clipboard copy is local to the
   device and expires after five minutes; the token itself can last longer and can rotate.
   Do not put a real token in the repository or screenshots intended for publication.
4. Create a test with the title/body and custom data shown below. Send only to that test
   device first. Check delivery while NumPad is in the background, then test tapping with
   the app already running and after terminating it. Confirm the App Store opens. Repeat
   with `deeplink = numpad://whats-new` to verify the in-app sheet.
5. While the app is foregrounded, confirm a marked update displays a banner. Deny permission
   on a fresh installation and confirm nothing subscribes. Open the app after changing iOS
   notification permission and confirm it reports the new state.
6. Turn **App updates** off and confirm a later test is not delivered. Also test switching off
   while offline, then reconnecting/reopening; the app immediately unregisters APNs and
   retries failed messaging-token deletion. Previously delivered notifications may remain
   in Notification Center. Turn updates back on and copy the current token again.
7. Test the beta audience with an opted-in TestFlight device. Before a public campaign,
   repeat delivery against an opted-in App Store installation and the production topic.

The automated suite covers consent policy, registration/subscription races, retryable opt-out
cleanup, token rotation, beta-to-production cleanup, allowed routes, the settings screen's
default-off state, and banner dismissal. Simulator tests do not establish real APNs delivery.

## Send an update from Firebase

Use the Firebase console's Messaging / Notifications composer, following the
[console sending guide](https://firebase.google.com/docs/cloud-messaging/ios/send-with-console).
Draft the message, select **Topic** targeting, and use the test audience first. Topic
subscriptions are created by opted-in installations; the console may need time to show a
new topic. [Firebase's topic guide](https://firebase.google.com/docs/cloud-messaging/manage-topic-subscriptions)
describes this audience mechanism.

Example draft (replace the body with the actual benefit of the release):

| Field | Example |
| --- | --- |
| Title | NumPad has an update |
| Body | Explore the latest improvements to your keyboard. |
| Test topic | `numpad_updates_test_v1` |
| Custom data: `kind` | `numpad_update` |
| Custom data: `deeplink` | `numpad://app-store` |

Use a normal visible notification with a title and body, not a data-only/background message.
The app intentionally has no silent-push background mode. The `kind` marker is required for
foreground display and routing. The only accepted campaign routes are `numpad://app-store`
and `numpad://whats-new`; arbitrary websites, purchase/debug actions, and route parameters are
rejected. The What's New destination currently shows the notification explanation, not a
remotely editable release-notes page, so use the App Store route for release announcements.

Review the text, release availability, audience, and schedule before changing the target to
`numpad_updates_v1` and publishing a campaign. This change creates no automatic release
broadcast. Keep announcements occasional and focused on a useful improvement. Avoid targeting
all app users: the update topic records explicit opt-in to these messages. Debug/TestFlight
builds use a separate audience and remove the old registration when moving to production.

For a future authenticated FCM HTTP v1 sender, a test-audience payload is provided in
[`update-notification-payload.example.json`](update-notification-payload.example.json).
It is an example only; there is no sender, service-account credential, or scheduled task here.

## Behavior and limits

- Opening the app or dismissing the keyboard banner never prompts or opts someone in. The
  banner remains independently dismissible, including when Full Access is off.
- The user's choice is stored in the main app. Messaging auto-initialization stays disabled;
  token retrieval follows explicit consent, OS permission, and APNs registration.
- Switching updates off unregisters APNs, cancels pending local update/offer reminders, and
  deletes the FCM registration to remove its topic subscriptions. Pending cleanup persists
  across process restarts. Deleting the FCM token does not delete Firebase identifiers used
  by the app's existing analytics or diagnostic services.
- Existing installs cannot receive these campaigns until they install a supporting build,
  open the main app, and explicitly enable updates. The dismissible keyboard banner provides
  that route into the app. This integration cannot retroactively subscribe absent users.
- Delivery depends on APNs/FCM, connectivity, and iOS notification settings, Focus, and
  Scheduled Summary. The settings screen's **On** state is enrollment status, not a delivery
  receipt. No guaranteed delivery time or sales lift is claimed.
- Firebase delegate swizzling is disabled and APNs token mapping is explicit. Campaign-open
  analytics are not added by this change, so do not treat console open metrics as complete.
