# Update notifications: activation and sending

The integration is on PR #13, `codex/update-notifications`, stacked on the dismissible
What's New banner in PR #12. Apple and Firebase configuration has now been inspected and
updated, and a signed development build is installed on the designated iPhone. Real remote
delivery and opt-out verification are still pending; configuration and enrollment are not
delivery proof. Production signing is verified on the locally exported App Store IPA;
production delivery remains unverified. No test notification or customer campaign has been
sent at this checkpoint, and no archive or IPA has been uploaded.

## Configuration

| Item | Value |
| --- | --- |
| Existing Firebase project | `numpad-24848` |
| Main app bundle ID | `com.morevoltage.NumPad` |
| Verified Apple team | `NNRNHY2N8B` — James Pikover / MoreVoltage |
| Verified Apple app identifier record | `LX8Y7Z644G`, `com.morevoltage.NumPad`; Push Notifications was already enabled |
| Existing APNs key | `7PDR3KSBUF`, created July 26, 2026; team-scoped, all topics, Sandbox & Production |
| Firebase development APNs credential | Existing key `7PDR3KSBUF`, team `NNRNHY2N8B`; added September 8, 2026 |
| Firebase production APNs credential | Existing key `7PDR3KSBUF`, team `NNRNHY2N8B`; preserved |
| Firebase Cloud Messaging HTTP v1 API | Enabled |
| App Store audience | `numpad_updates_v1` |
| Debug / TestFlight audience | `numpad_updates_test_v1` |
| Default notification destination | `https://apps.apple.com/app/id1072547160` |
| Messaging SDK | `FirebaseMessaging 11.15.0`, matching the existing Firebase version |

Messaging is linked only into the main app. It does not add Firebase to the keyboard or require
Full Access. The existing Firebase project handles delivery; this change needs no custom server.

## Apple-to-Firebase configuration performed

On September 8, 2026, the signing account and explicit app identifier were verified against
the team above. Push Notifications was already enabled for the correct main app. The existing
NumPad APNs key was inspected before making changes; no new key was created or revoked.

The [Firebase project's](https://console.firebase.google.com/project/numpad-24848/overview)
**Project settings → Cloud Messaging → Apple app configuration** initially had the existing
key in the production slot only. Its existing private key was reused to populate the
development slot for `com.morevoltage.NumPad`. Both slots now reference `7PDR3KSBUF` and
`NNRNHY2N8B`. Other keys and Apple apps were left untouched. Key IDs identify credentials;
private key material and its storage location are intentionally absent from this record.
Firebase documents the environment configuration in its
[Apple setup guide](https://firebase.google.com/docs/cloud-messaging/ios/client).

The signed development main app has the expected team and `aps-environment = development`.
Its embedded Keyboard extension has no APNs entitlement. A local Release archive and App
Store export also succeeded after automatic provisioning refreshed the distribution profiles.
The archive uses development signing until export; the exported IPA is the verified
production signing artifact. Its main app's signature and embedded provisioning profile both
declare `aps-environment = production` and `get-task-allow = false`, with team `NNRNHY2N8B`.
The exported Keyboard extension has no APNs entitlement, has `get-task-allow = false`, and
uses the same team. Strict, deep code-signature verification passed on the exported app.

The refreshed main app profile is `df1fceac-210b-4a2d-aef5-4b210e76343a`, expiring June 19,
2027. The Keyboard profile is `66ac4dd5-49c5-442c-bc59-25b6b71b72d3`. These are profile
identifiers, not credentials. Nothing was uploaded or distributed by the local export.
Production signing and configured APNs credentials do not establish production delivery. See
[Apple's registration guide](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns).

Privacy and submission texts are prepared in the
[privacy and release draft](2026-09-08-update-notification-privacy-release-draft.md).
Before shipping, review the whole app's App Privacy answers and archive privacy report, then
publish the approved policy. The app's Device ID manifest addition does not replace that
review. Policy publication, public release, distribution to other testers, and customer
campaigns require separate approval.

## Actual run log — September 8, 2026, work in progress

The final code and test commit is `5c427dd67d67f4f96f14b2e29d20a4ee8f54eb33`.
The 11-test focused run, signed Debug build and installation, Release archive, and App Store
export correspond to this source. The earlier 64-test result belongs to base commit
`128488f0255e70f49660a1bd8f18c75999acabe8`. The new 55-test clean run exercised the earlier
notification fixes before the final URL-dispatch setter change; the later 11-test run covers
the affected route behavior. The two new runs overlap and are not 66 unique tests.

| Check | Actual result | Evidence or limit |
| --- | --- | --- |
| Locked dependencies | Passed | `pod install --deployment`; installed Manifest matches `Podfile.lock`; Firebase Messaging remains 11.15.0. |
| Signed development build | Final Debug build succeeded and was installed again in place | Main app signed by `NNRNHY2N8B`, development APNs entitlement present; Keyboard has no APNs entitlement. |
| Designated physical device | James's iPhone 17 — iPhone 17 Pro | iOS 27.0 (`24A5430a`). Installed in place; existing app data preserved and backed up privately outside Git. |
| Selected regression suite | 55 passed: 53 unit tests and 2 UI tests | Clean disposable simulator run; result bundle `NumPadNotificationCleanRegression.xcresult`. This is simulator evidence. |
| Final URL-dispatch regression | 11 focused tests passed | 2 new PendingDeepLinkDispatch, 4 UpdateNotificationLaunchRoute, and 5 WhatsNewNotification tests; result bundle `NumPadNotificationRouteRegression.xcresult`. Includes the final setter fix. |
| Earlier reused-simulator UI attempt | Failed due to persisted banner dismissal | The subsequent clean disposable simulator run passed. The earlier failure is not omitted or treated as device evidence. |
| App opening and Not now on the physical iPhone | No implicit opt-in observed | Notification preference remained default false through opening the app and choosing Not now. |
| Explicit notification choice on the physical iPhone | Turn on updates selected; currently opted in | No FCM token has been obtained. The current test code requires a physical tap on Copy notification test code; mirroring could not swipe to the settings action. No delivery is inferred from enrollment. |
| Dismissible keyboard banner on the physical iPhone | Not yet recorded | Simulator UI regression passes; physical dismissal remains a separate check. |
| Direct What's New URL on the physical iPhone | Cold and warm `numpad://whats-new` routes displayed the actual sheet | Direct URL tests only; neither is evidence of a notification tap. The warm route was verified after the final fix. |
| Development notification delivery and taps | Not yet sent or verified | Foreground, background, running-app tap, terminated-app tap, and both routes remain open. |
| Physical opt-out, re-enable, and interrupted-connectivity cleanup | Not yet verified | Require targeted sends and observable outcomes on the designated device. |
| Local Release archive and App Store export | Succeeded | `NumPadNotifications-verified.xcarchive` and exported `NumPad.ipa`; distribution profiles refreshed automatically. Archive remains development-signed until export. No upload. |
| Exported IPA production signing | Verified | Main app signature and embedded profile both have production APNs entitlement, `get-task-allow = false`, and the expected team; Keyboard has no APNs entitlement and uses the same team. Strict, deep signature validation passed. |
| TestFlight availability and production delivery | Blocked and unverified | App Store Connect sign-in awaits the user's login; the Chrome extension UI prevented continuing on the sign-in tab. No TestFlight build availability or delivery has been verified. |
| Firebase message | Draft and single-device test dialog ready | Recipient field remains empty; no FCM token obtained, no test send, topic broadcast, or customer campaign published. |

The current source fixes address update routes deferred during startup or modal presentation,
direct URL assignment failing to wake the active routing observer, and opt-out cleanup blocked
by an unfinished Firebase topic operation during connectivity loss. The selected regressions
and direct URL observations support those changes; they do not establish successful physical
notification delivery, notification taps, or cleanup. Further device results must be recorded
explicitly, including failures and remaining physical actions.

The next required physical action is to open **NumPad → Update Notifications** on the
designated iPhone and tap **Copy notification test code**. Transfer that code only into the
private single-device Firebase test flow, never into chat or this record. App Store Connect
also requires the user's sign-in before TestFlight availability can be checked. Public release,
uploads to additional testers, and topic sends remain outside this task's authorization.

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
4. Create a test with the title/body and custom data shown below. Send only to the designated
   test device. Check delivery while NumPad is in the background, then test tapping with
   the app already running and after terminating it. Confirm the App Store opens. Repeat
   with `deeplink = numpad://whats-new` to verify the in-app sheet.
5. While the app is foregrounded, confirm a marked update displays a banner. A fresh-install
   denial check requires a state in which iOS can show the initial prompt; do not erase the
   designated iPhone's data to create that state. Record that check as unrun if unavailable.
   Open the app after changing iOS notification permission and confirm it reports the new state.
6. Turn **App updates** off and confirm a later test is not delivered. Also test switching off
   while offline, then reconnecting/reopening; the app immediately unregisters APNs and
   retries failed messaging-token deletion. Previously delivered notifications may remain
   in Notification Center. Turn updates back on and copy the current token again.
7. If TestFlight is available on the designated iPhone, verify production-environment delivery
   with its current single-device token. Future App Store audience or campaign checks require
   separate approval; neither topic is an authorized send target in this task.

The automated suite covers consent policy, registration/subscription races, retryable opt-out
cleanup, token rotation, beta-to-production cleanup, allowed routes, the settings screen's
default-off state, and banner dismissal. Simulator tests do not establish real APNs delivery.

## Future campaign procedure — separate approval required

The current task authorizes visible test messages only to the designated iPhone's current
token, obtained through **Copy notification test code**. It does not authorize sending to
`numpad_updates_test_v1`, `numpad_updates_v1`, another tester, or all app users. The topic
instructions and example payload below are for a later approved campaign.

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
Enrollment also unsubscribes the opposite audience before subscribing, clearing any unfinished
topic operation that Firebase retained from a previous process.

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
