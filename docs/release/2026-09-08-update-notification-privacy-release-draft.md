# Update notifications: privacy and release drafts

Prepared September 8, 2026 from implementation commit
`5c427dd67d67f4f96f14b2e29d20a4ee8f54eb33` and the locked Firebase Messaging 11.15.0
dependency. These are prepared texts and submission review notes. They have not been
published or entered into App Store Connect.
They do not establish successful device
delivery. Record configuration, builds, and actual device results in
[the notification release record](2026-09-08-update-notifications.md).

At the current checkpoint, the Apple team and app identifier are verified, Firebase has the
existing APNs key configured in both environment slots, and a signed development build is
installed in place on the designated iPhone. App opening and Not now left notification opt-in
false; Turn on updates has now been explicitly selected. The locally exported App Store IPA
has verified production signing and APNs entitlement; its preceding archive uses development
signing until export. Direct cold and warm What's New URLs displayed the sheet on the iPhone.
Actual notification delivery, notification taps, physical opt-out, and TestFlight verification
are still pending. The selected 55-test simulator pass and later 11-test focused pass overlap
and do not establish those physical outcomes. No build has been uploaded and no test push sent;
the test flow awaits USB reconnection and a fresh private clipboard copy after the device
became unavailable. App Store Connect access succeeded on retry; its latest build 2.1.0 (14)
predates this integration and its metadata has no APNs entitlement. Production delivery
therefore still requires a suitable TestFlight build.

## Privacy policy addition, ready for publication after review

Replace the **Optional update notifications** section in both
[`docs/PrivacyPolicy.md`](../PrivacyPolicy.md) and
[`docs/PrivacyPolicy`](../PrivacyPolicy) with the following text. Publish the reviewed
policy at the existing in-app destination, `https://morevoltage.com/numpad/privacy`,
when the release owner approves publication. Set the policy's last-updated date to
the actual publication date.

### Optional update notifications

You can choose to receive occasional notifications about NumPad features and app
updates. Notifications are off until you turn them on in the main NumPad app and
allow notifications in iPhone Settings. Opening NumPad, dismissing the keyboard
banner, or previously allowing a local reminder does not enroll you in remote
update notifications. Your keyboard works with notifications off, and notification
delivery does not require the keyboard's Full Access permission.

When you enable updates, Apple Push Notification service and Google Firebase Cloud
Messaging process push registration tokens and an app-installation identifier to
route messages to this installation. Firebase also processes device model,
language, time zone, operating system version, and app identifiers and version
information needed to manage delivery subscriptions. We do not include typed
content, clipboard contents, your name, or your email in notification registration
or notification messages. The keyboard extension does not contain Firebase
Messaging. These notification identifiers are not used for cross-app tracking.

To stop updates, open **NumPad → Update Notifications** and turn **App updates** off.
NumPad unregisters remote notifications on the device, cancels pending local
update and offer reminders, and requests deletion of its Firebase messaging
registration. If connectivity interrupts deletion, NumPad retains the cleanup
request and retries while active and when you reopen the app. Notifications already
shown in Notification Center may remain until you clear them.

You can also control notification presentation in **iPhone Settings → Notifications
→ NumPad**. Turning off notifications there preserves your in-app preference;
turn **App updates** off in NumPad to withdraw that preference. Turning off updates
does not delete the separate Firebase installation identifier or data used by
NumPad's existing analytics and diagnostic services. To ask about deletion of that
data, contact [support@morevoltage.com](mailto:support@morevoltage.com).

Editorial basis: [Firebase's Apple data disclosure guide](https://firebase.google.com/docs/ios/app-store-data-collection#firebasemessaging)
describes messaging tokens and subscription metadata. The withdrawal/retry wording
follows `UpdateNotifications.swift`; it deliberately makes no promise of immediate
server-side erasure during an outage. [Firebase's Messaging API reference](https://firebase.google.com/docs/reference/swift/firebasemessaging/api/reference/Classes/Messaging)
distinguishes messaging-token deletion from installation deletion.

## Related policy edits to review before publishing

The existing policy's whole-app statements about anonymous analytics, identity
linkage, IP retention, and an iOS analytics opt-out are not established by this
notification review. Do not treat the notification paragraph as verification of
those statements. The existing in-app privacy screen also uses “anonymous.”

Prepared narrower replacements for the policy are:

- Replace “None of it is linked to your identity or used to track you” with:
  **“These services process app-instance identifiers and technical information to
  provide analytics, crash reporting, performance monitoring, and remote
  configuration. The optional notification service is described below.”**
- Replace the sentence claiming an iOS analytics opt-out with:
  **“You can turn update notifications and clipboard history off in NumPad. For
  questions about analytics or diagnostic data and deletion requests, contact
  support@morevoltage.com.”**
- Replace the blanket IP-address retention statement with service-specific wording
  after reviewing the configured Analytics and Performance products. Firebase's
  published Performance retention is different from a blanket immediate-discard
  claim. [Firebase privacy and retention details](https://firebase.google.com/support/privacy)
  also explain that stopping messaging does not itself delete the installation ID.

These replacements avoid certifying the existing services' linkage, advertising
settings, or deletion workflow. Confirm the current support process and complete
that whole-app review before the release policy is approved.

## App Store Connect App Privacy review deltas

This is a delta worksheet, not a completed whole-app privacy questionnaire. Preserve
the current answers until they have been compared with the actual release archive
and Firebase project settings. Apple's form includes collection by third-party
SDKs. Optional enrollment alone does not exempt ongoing collection. Device-based
linkage can count as linkage to the user without a name or email.
[Apple App Privacy details](https://developer.apple.com/app-store/app-privacy-details/)

| Item | Prepared answer or review action | Evidence and remaining decision |
| --- | --- | --- |
| Identifiers → Device ID | Collected; linked; App Functionality; not used for tracking for the notification integration | Main app manifest already declares this. Push identifiers address an installation. Do not downgrade to unlinked merely because no account exists. |
| Developer's Advertising or Marketing | Review for addition alongside App Functionality before feature/update announcement campaigns | Recommendation: include this purpose when identifiers deliver communications promoting NumPad improvements. Confirm the intended message use with the release owner and align the app manifest if selected. No campaign is authorized by this worksheet. |
| Other Data Types | Include in archive privacy-report review | Locked FirebaseMessaging manifest declares Analytics purpose, unlinked, no tracking. Establish how the release configuration uses the SDK's collected metadata before transferring the declaration to the form. |
| Other Diagnostic Data | Include in archive privacy-report review | Locked FirebaseMessaging manifest declares App Functionality; FirebaseInstallations declares Analytics. Both SDK manifests mark these rows unlinked and not tracking. Review these alongside the existing app diagnostics. |
| Product Interaction / notification opens | Retain existing app Analytics review; do not claim added campaign-open measurement | `FirebaseAppDelegateProxyEnabled = false`; no `appDidReceiveMessage` forwarding exists in app sources. This integration does not add Firebase campaign-open logging. Re-review if that changes. |
| Typed content and clipboard content | No notification-related collection added | Registration and routing do not read those values. Do not infer whole-app data declarations solely from this row. |
| Tracking | No new notification tracking use identified | Check actual Analytics/Ads links and project data-sharing settings before certifying the whole app's answer. |
| Privacy Policy URL | Verify the published policy at the URL used by the app, and match the App Store Connect field | In-app URL is `https://morevoltage.com/numpad/privacy`; publication and current portal field have not been verified here. |

Apple includes direct first-party marketing messages in **Developer's Advertising
or Marketing**. Using identifiers for delivery does not automatically make that
their only purpose. The purpose recommendation above is an inference from the
proposed announcement use, not an owner-approved campaign policy.
[Apple's purpose definitions](https://developer.apple.com/app-store/app-privacy-details/#data-use)

The locked SDK manifests are under
`Pods/FirebaseMessaging/FirebaseMessaging/Sources/Resources/PrivacyInfo.xcprivacy`
and
`Pods/FirebaseInstallations/FirebaseInstallations/Source/Library/Resources/PrivacyInfo.xcprivacy`.
Use the privacy report from the final signed archive to reconcile app and SDK
declarations. Do not edit vendored Pods manifests to make that report narrower.

## App Store What's New text — draft

Choose whether to hear about new NumPad features and app updates. Turn on updates
in the app and switch them off whenever you like. The keyboard's What's New banner
is dismissible, and your keyboard keeps working with notifications off.

## App Review notes — draft

Update notifications are optional. In the main NumPad app, open **Update
Notifications**, then enable **App updates** to request iOS notification permission.
The What's New sheet also offers **Turn on updates** and **Not now**. Opening the
app or dismissing the keyboard banner does not request permission or enroll an
installation. Existing local-reminder permission does not automatically enroll
existing users.

The **App updates** switch is also the in-app opt-out. **Notification settings**
opens the system controls. The keyboard works without notification permission and
without Full Access; Firebase Messaging and push registration exist only in the
main app. Notification taps can open NumPad's App Store page or its in-app What's
New sheet. Notifications do not unlock purchases or carry typed content.

This release uses visible remote notifications for opted-in updates. **On** means
registration and enrollment succeeded; it is not a receipt for a particular
notification. No public notification campaign is required to review the settings
or keyboard. Attach the final build's device-verification record when submitting.

The explicit choice and in-app off switch support the consent requirements in
[App Review Guideline 4.5.4](https://developer.apple.com/app-store/review/guidelines/#apple-sites-and-services).
This note is not a claim of App Review approval.

## Designated-device test notes — draft, not completed results

Only **James's iPhone 17 — iPhone 17 Pro** is authorized for notification sends in
this work. Do not send to either topic, another device, a tester group, or a public
campaign. Debug/TestFlight uses `numpad_updates_test_v1`; App Store uses
`numpad_updates_v1`. Topic separation is not permission to broadcast.

1. Preserve existing installation data. Record signed build version, build number,
   SHA, iOS version, and whether the signed app uses development or production APNs.
2. Verify the banner can be dismissed and opening the app does not trigger a new
   permission prompt or enrollment before the explicit opt-in. Do not reset the
   designated iPhone's data to manufacture a fresh-consent test. Mark a fresh
   denial scenario separately if the device cannot exercise it without a reset.
3. Enable **App updates**, accept the system prompt if shown, and wait for **On**.
   In Debug/TestFlight, tap **Copy notification test code**. Transfer the current
   code only through the private single-device testing path. The app copies it
   locally with a five-minute clipboard expiration; it is not a five-minute token.
4. Send a visible single-token test with `kind = numpad_update` and
   `deeplink = numpad://app-store`. Record observable foreground and background
   delivery and taps with the app running and terminated. Repeat with
   `deeplink = numpad://whats-new`; this opens the existing notification-explanation
   sheet, not a remotely authored changelog.
5. Turn updates off, verify deletion completes, and test the old token privately.
   Record the sender result and absence of a new device notification. Do not infer
   success from the switch alone. Re-enable and obtain the current token again.
6. Interrupt connectivity during opt-out, then reconnect/reopen. Record whether
   cleanup resumes and whether the old token can still receive; distinguish a
   queued earlier notification from a fresh post-cleanup send.
7. Verify the same flow in an available TestFlight build to establish production
   APNs delivery. A distribution signature or archive production entitlement
   alone is not delivery proof. If unavailable, retain this as an unrun release
   check without distributing to additional testers.

Record only timestamps, build identities, observable outcomes, and sanitized
delivery errors. Exclude real tokens, private keys, clipboard contents, and
credential-bearing payloads from Git, PR text, screenshots, and logs.

## Release owner facts still needed

- Whether future update/feature notices are promotional communications, to finalize
  notification identifier purposes and any matching manifest change.
- Current full-app App Privacy answers, Analytics/Ads integrations, data-sharing
  settings, and the support deletion process; this document does not certify them.
- Approved policy publication and release dates, final version/build, and final
  device results. Development delivery and production delivery require separate
  evidence in the release record.

Public release, policy publication, distribution to other testers, and customer
notification campaigns remain separate approval steps.
