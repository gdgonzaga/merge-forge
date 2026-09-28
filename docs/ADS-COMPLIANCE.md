# Ads and Store Compliance

Last checked: 2026-09-28. Policies change often, so re-check the linked sources before each release. **This is a checklist, not legal or tax advice.**

**Scope:** MergeForge v1.0 on Google Play.
- Monetized with **AdMob interstitial ads only**. There are no banners, no rewarded ads, and no in-app purchases (paid ad removal is in `docs/TODO.md`).
- For the in-game rules on where ads appear, see `docs/GDD.md`, "Submodule — Ads".
- iOS gets a short section at the end, for later.

---

## 1. The order to do things in

Several steps wait on others: AdMob needs a store listing, the listing needs a website, and production access needs a 14-day test. Start the long ones early.

| # | Step | Where | Blocks |
|---|---|---|---|
| 1 | Get a domain and put up a simple developer website with a privacy policy page | Your host | 4, 7, 9 |
| 2 | Create a Google Play developer account and complete identity verification | Play Console | 3, 4 |
| 3 | Create the AdMob account and add the app as "not yet published" | AdMob | 6 |
| 4 | Create the Play app, fill in every App content declaration (section 4) and the store listing, with the website URL in the contact details | Play Console | 5 |
| 5 | Closed test: **12+ testers opted in for 14 consecutive days**, using **test ads** | Play Console | 8 |
| 6 | Set up the consent messages, the interstitial ad unit and blocking controls | AdMob | 8 |
| 7 | Tax info and payment profile | AdMob | Payouts only |
| 8 | Apply for production access, then publish | Play Console | 9 |
| 9 | Link the AdMob app to the live Play listing, publish `app-ads.txt`, and wait for AdMob's app review | AdMob + website | Full ad serving |

---

## 2. Accounts

### Google Play Console
- **Account type.** A one-time registration fee applies. Choose **personal** or **organization**:
  - An organization account needs a D-U-N-S number.
  - Personal accounts created after 13 November 2023 must run a **closed test with at least 12 opted-in testers for 14 consecutive days** before applying for production access. Google now also checks that testers really used the app.
  - "Opted in" means the tester accepted the invite **and installed** the app.
- **Plan for the test.** Recruit testers early, from friends, a community or a tester exchange, and ask them to open the game several times over the two weeks.
- **Identity verification.** Complete it, and keep your legal name, address and payments profile consistent with AdMob.

### AdMob
- **Account.** Sign up with the same Google account as Play Console, to keep linking simple. One AdMob account per person.
- **Payee name.** It must match your bank account.
- **Verification.** Identity and address verification is required from $0 in earnings.
- **Thresholds:** you choose a payment method at $10, and payouts happen monthly once the balance reaches **$100** (these are the USD figures).
- **Tax info deadline:** tax info must be in **before the 20th of the month** for that month's payment.

---

## 3. Outside the app: website, privacy policy, app-ads.txt

### Developer website (required)
- A domain you control, such as `mergeforge.example`. GitHub Pages or any static host with a custom domain works.
- It must be the **exact** domain entered as the website in the Play listing's contact details. AdMob uses it to confirm you own the app.

### `app-ads.txt` (required for new AdMob apps)
- A text file at the **root** of that domain: `https://<domain>/app-ads.txt`. Not in a subfolder, and not on a different subdomain than the one in the listing.
- The content is one line AdMob gives you (Apps > app-ads.txt): `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`, using your own publisher id.
- AdMob crawls it within about 24 hours of the listing change or the file going live. Without it, ad serving is limited.

### Privacy policy (required: the app shows ads and uses the advertising ID)
- Host it on the website, and link it both in Play Console (App content > Privacy policy) and **inside the game** (main menu, next to "Privacy choices").
- It must cover:
  - Who you are, and a contact email.
  - **The game itself collects nothing.** Progress is saved locally on the device (`user://save_data.json`), and there are no accounts and no analytics. Update this if analytics are ever added.
  - **Advertising through Google AdMob.** The SDK collects device identifiers (the Android advertising ID and app set ID), IP address (used for approximate location), interactions with ads and the app, and diagnostics. It uses them for advertising, analytics and fraud prevention. Link to Google's "How Google uses information from sites or apps that use our services".
  - Consent: the in-game "Privacy choices" option, how to reset the advertising ID in Android settings, and how to opt out of personalized ads.
  - Children: the game isn't directed at children under 13 (see section 4).
  - The legal rights for EEA, UK and Swiss users (GDPR) and for US state privacy laws (such as California's CCPA and CPRA). If you're based in the Philippines, also mention the Data Privacy Act of 2012 (RA 10173).
  - Data retention and deletion: game data is deleted by uninstalling, and ad data is handled under Google's policies.
- A template generator is fine as a starting point, but check it against the list above.

---

## 4. Play Console: App content declarations

| Declaration | What to answer for MergeForge |
|---|---|
| **Ads** | "Yes, my app contains ads". The store shows a "Contains ads" label. |
| **Privacy policy** | The URL from section 3. |
| **App access** | All functionality is available without special access (no login). |
| **Target audience and content** | Choose **18 and over**, or **13+** at the youngest; the GDD audience is ages 20-40. **Don't pick any under-13 age group.** That puts the app under the **Families Policy**: child-directed ad treatment, only G-rated ads, restrictions on the advertising ID, and only Families-certified ad SDKs. Answer "Could your app unintentionally appeal to children?" honestly. Cute pixel-art fantasy can draw that question, and a misdeclaration can get the app removed. |
| **Content rating (IARC questionnaire)** | Answer for fantasy combat (cartoon violence against fantasy creatures). There's no gambling, and no user-generated content or chat. Being ad-supported doesn't change the rating, but the ad content setting in AdMob (section 5) should be consistent with it. |
| **Data safety** | See the table below. |
| **Advertising ID** | "Yes, my app uses advertising ID", for **Advertising or marketing**, **Analytics** and **Fraud prevention, security and compliance**. Android 13+ needs the `com.google.android.gms.permission.AD_ID` permission, which the Google Mobile Ads SDK adds through manifest merging. Check it's in the exported manifest. |
| **Government, financial, health, news** | Not applicable. |

### Data safety answers (from Google's disclosure for the Mobile Ads SDK)

| Data type | Collected | Shared | Purposes |
|---|---|---|---|
| Location: approximate (from IP address) | Yes | Yes | Advertising, analytics, fraud prevention |
| App activity: app interactions | Yes | Yes | Advertising, analytics, fraud prevention |
| App info and performance: diagnostics | Yes | Yes | Analytics, fraud prevention |
| Device or other IDs (advertising ID, app set ID) | Yes | Yes | Advertising, analytics, fraud prevention |

- Data is encrypted in transit: **yes** (TLS).
- Users can't request deletion inside the app, because there's no account. Say that data is handled by Google, and point to the ad ID reset.
- Game progress stays on the device and is never sent anywhere, so it's **not** "collected" in Play's definition.
- Re-check Google's disclosure page whenever the SDK version changes.

---

## 5. AdMob console setup

1. **Add the app.** Android, "not listed on a supported app store yet". Link it to the Play listing once the app is live.
   - AdMob then reviews the app (app readiness). Until that review passes, ad serving is limited.
2. **Ad units.** Create **one interstitial ad unit**, for example `interstitial_break`. Keep its id out of source control if you prefer; either way, debug and closed-test builds use **Google's test ad unit id** (section 6).
3. **Privacy and messaging.** In AdMob's Privacy & messaging section, set up:
   - **European regulations (GDPR) message.** Required: Google needs a **Google-certified CMP integrated with IAB TCF** to serve personalized ads in the EEA and UK (since 16 January 2024) and in Switzerland (since 31 July 2024). Google's UMP SDK, through the plugin, is such a CMP.
   - **US state regulations message.** Recommended: it handles the opt-out ("do not sell or share") requirements.
   - Publish both messages, and set the privacy policy URL in them.
4. **Blocking controls.**
   - Set the **maximum ad content rating** to match your IARC rating and taste: **T** or **PG**. PG gives safer ads at some revenue cost.
   - Review the sensitive categories, such as gambling and dating, and block any that clash with the game's tone.
5. **Child-directed and age tagging.** Leave the app **not** child-directed. The old "tag for child-directed treatment" is deprecated in favor of **Tag for age treatment (TFAT)**. Don't set it unless the target audience changes to include children.
6. **Test devices.** Register every development and tester device under Settings > Test devices, or only ever use test ad units in those builds.
7. **Payments.** Add the tax info and payment method (section 7).

---

## 6. What the app itself must do (developer checklist)

These are in-repo requirements. They're listed here because failing them is a policy violation, not only a bug.

- **Ask for consent before loading ads.** Call the UMP consent check on every launch, show the form if needed, and only request ads once the SDK says ads can be requested. Never block the game on consent: if the form fails, carry on without ads.
- **Privacy choices entry point.** When UMP reports that privacy options are required, show a "Privacy choices" button, for example in the main menu, that reopens the consent form. Put the privacy policy link beside it.
- **Test ads in every non-production build.** Use Google's test interstitial unit, or registered test devices, in debug and closed-test builds.
  - **Never tap your own live ads**, and don't ask friends to. That's invalid traffic and can get the AdMob account suspended.
  - Switch to the real unit id only for production builds.
- **Placement** (Google's interstitial guidance plus the GDD rules):
  - Only at natural breaks (session and dungeon summary transitions).
  - Never on app launch or exit, and never mid-session or mid-dungeon.
  - Never as a surprise, and never so often that it obstructs play.
  - Pause audio while an ad is shown, and resume it afterwards.
  - If an ad fails to load, skip it silently; the game flow must never wait on an ad.
- **No incentives or tricks.** Nothing may reward or push the player to click an ad, and no UI may sit where a tap could land on an ad as it opens.
- **Export settings that must change** (`export_presets.cfg`):
  - `permissions/internet` must be `true` (currently `false`).
  - `gradle_build/target_sdk` must be **36**: Play requires API 36 for new apps and updates from 31 August 2026 (an extension to 1 November 2026 can be requested). It's currently `33`.
  - `gradle_build/use_gradle_build=true` is already set, which Android plugins need.
- **Save on pause.** The existing `NOTIFICATION_APPLICATION_PAUSED` save must run when an interstitial takes over the screen, since some ad clicks leave the app.

---

## 7. Money and tax

- **US tax info (all AdMob publishers).** AdMob's tax interview asks for US tax information even from non-US publishers. The correct form depends on whether you're an individual or a business and on your country's tax treaty with the US, which can reduce withholding.
  - Google's help pages don't settle the W-8BEN versus other-form question for individuals in every case. **Ask a tax adviser before submitting.**
- **Non-US tax info.** Some countries also need local tax details in AdMob. Submit these if AdMob asks.
- **Local income tax.** Ad revenue is taxable income where you live. If you're in the Philippines, that usually means registering with the BIR (as self-employed or a business) and declaring AdMob and Play income. Confirm this with a local accountant.
- **Bank.** AdMob pays by wire or EFT to the bank account whose name matches the payee name.

---

## 8. Things to watch after launch

- **Policy center (AdMob and Play Console).** Check it weekly at first. Violations such as ad placement or invalid traffic come with deadlines.
- **Invalid-traffic warnings.** Act on them immediately, and never try to hide them.
- **Target API.** Google raises the requirement every August, so plan an update each year.
- **SDK updates.** Google deprecates old Mobile Ads SDK versions. Update the plugin at least once a year, and re-check the data safety answers when you do.
- **`app-ads.txt` status** in AdMob (Apps > app-ads.txt) after any website change.

---

## 9. iOS (later)

Only needed if the iOS build ships:
- **App Tracking Transparency.** Show the ATT prompt (with an explainer message, which AdMob's Privacy & messaging can provide) before requesting the IDFA.
- **Info.plist.** Add `NSUserTrackingUsageDescription` and Google's **SKAdNetwork identifiers** to `Info.plist`.
- **App Store listing.** Fill in the **App Privacy** labels (similar to Data safety) and the App Store privacy policy URL, and list `app-ads.txt` against the App Store listing's marketing URL domain.
- **Account.** Apple Developer Program membership (paid yearly).

---

## Sources

- [Play Console: App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Play Console: Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en) and [Meet Google Play's target API level requirement](https://developer.android.com/google/play/requirements/target-sdk)
- [AdMob: Google consent management requirements for the EEA, UK and Switzerland](https://support.google.com/admob/answer/13554116?hl=en)
- [AdMob: Set up an app-ads.txt file](https://support.google.com/admob/answer/9363762?hl=en) and [app-ads.txt FAQ](https://support.google.com/admob/answer/9675354?hl=en)
- [Google Mobile Ads SDK: Play data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure)
- [AdMob: Comply with Google Play's Families Policy](https://support.google.com/admob/answer/6223431?hl=en), [Tag for age treatment](https://support.google.com/admob/answer/6219315?hl=en), [Maximum ad content rating](https://support.google.com/admob/answer/7562142?hl=en)
- [AdMob: Interstitial ad guidance](https://support.google.com/admob/answer/6066980?hl=en) and [Recommended interstitial implementations](https://support.google.com/admob/answer/6201350?hl=en)
- [AdMob: Payment thresholds](https://support.google.com/admob/answer/2772208?hl=en), [Submit your US tax info](https://support.google.com/admob/answer/2772513?hl=en), [Submit your non-US tax info](https://support.google.com/admob/answer/14135099?hl=en)
