# Google Play release guide

Everything needed to publish Parenting Helper (`com.byteforgedstudios.parentinghelper`) on Google Play. Items marked **[Console]** are done in Google Play Console; nothing in the code needs to change for them.

## 1. Privacy policy (required)

1. Run `python tool/build_privacy_html.py` after any change to `assets/legal/privacy_policy.md`. It writes `docs/privacy.html`.
2. Publish `docs/privacy.html` as `privacy.html` in the `byteforgedstudios.github.io` GitHub Pages repo, so it's live at <https://byteforgedstudios.github.io/privacy.html>. That URL is set in `lib/state/app_info.dart`.
3. **[Console]** App content → Privacy policy → paste the URL.
4. If the policy changes, bump `kPrivacyPolicyVersion` in `lib/state/app_info.dart`. Parents are asked to agree again on next launch.

The same policy is bundled in the app (Settings → Privacy policy), so it works offline.

## 2. Subscriptions and the 7-day free trial [Console]

Monetize → Products → Subscriptions:

| Product ID | Base plan | Price | Offer |
|---|---|---|---|
| `premium_monthly` | Auto-renewing, 1 month | $2.99 USD | none |
| `premium_yearly` | Auto-renewing, 1 year | $19.99 USD | **Free trial**: 7 days (P7D) |

For the yearly free-trial offer:

- Phase: Free trial, 7 days.
- Eligibility: *New customer acquisition*, i.e. users who have never had this subscription.
- Status: Active.

The app reads the offers from Google Play at runtime. When the user is eligible, the yearly plan shows "7 days free, then $19.99 / year" and a "Start 7-day free trial" button, with the cancellation terms under it. Ineligible users see the normal price. The IDs above must match `lib/services/premium_service.dart` exactly.

Recommended: turn on a **grace period** (e.g. 7 days) and **account hold**, so a failed card payment doesn't immediately lock a family out.

## 3. Test purchases

1. **[Console]** Setup → License testing → add your Google account.
2. Build and upload an app bundle to the **Internal testing** track (see section 7), then install it from the Play testing link. Purchases only work in builds installed from Play.
3. Test purchases renew quickly (a "year" lasts about 30 minutes) and are never charged.

The debug-only **Settings → Developer → Simulate Premium** switch tests Premium features without Play. It never appears in release builds.

## 4. Data safety form [Console]

App content → Data safety. These answers are based on Google's definition that data processed only on the device is *not* collected. The app has no server, no analytics and no ads.

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not applicable (nothing is transmitted) |
| Do you provide a way for users to request that their data is deleted? | **Yes**: in-app (Kids → Delete, Settings → Delete all data) and by uninstalling |

Before submitting, check the **Google Play Billing Library** entry in the [Google Play SDK Index](https://play.google.com/sdks). If it lists data your app must declare (for example *Purchase history*), declare that type as: collected, not shared, processed ephemerally = no, required, purpose *App functionality*.

**Update this form before shipping** any of: cloud sync or Firebase, server-side purchase verification (then purchase history *is* collected), crash reporting or analytics.

## 5. Target audience, content and families policy [Console]

- **Target audience and content:** select **18 and over** only. The app is for parents; children use it only under a parent's supervision on the parent's device. The onboarding screen asks the user to confirm they are a parent or guardian aged 18+.
- **Appeals to children:** the design is playful, so Google may ask whether the app unintentionally appeals to children. Answer honestly. The parental PIN on purchases, rewards and settings plus the adult-only onboarding support the 18+ declaration. If Google classifies it as appealing to children, the Families Policy applies. The app already meets its main points: no ads, no data collection, and purchases behind a parental gate.
- **Content rating (IARC):** answer No to violence, sexuality, language, drugs, gambling, user interaction and location sharing. Expected rating: Everyone / PEGI 3.
- **Ads:** No ads.
- **App access:** all features are available without special access; no account is needed. Reviewers create their own parent PIN during onboarding.
- **Financial features, health, news, government:** None.

## 6. Store listing [Console]

Main store listing. This lists only features that exist today. Family sync, advanced reminders, themes, seasonal reward packs and priority support are deliberately left out and can be added in a later update once built.

**App name** (30 max): `Parenting Helper: Kid Routines`

**Short description** (80 max):
`Build kids' routines, tick off tasks and reward progress with stars.`

**Full description:**

```
Make daily routines fun for the whole family.

Parenting Helper turns everyday tasks like brushing teeth, packing the school bag or tidying up into a simple checklist your kids love to complete. Every finished task earns a star, and stars can be swapped for rewards you choose together.

ROUTINES THAT RUN THEMSELVES
• Set tasks to repeat every day, on weekdays or on the days you pick
• Plan ahead with the calendar, or copy tasks to other days
• Each day starts with a fresh checklist

STARS AND REWARDS
• Kids earn a star for every task they finish
• Create your own rewards, from ice cream to extra screen time
• Keep a history of every reward redeemed

MADE FOR PARENTS
• A parent PIN protects rewards, purchases and settings
• Works offline, with no account needed
• Your family's information stays on your device: no ads, no tracking

PREMIUM
Free includes 1 child, 5 tasks per day and 3 rewards. Premium unlocks:
• Unlimited children, tasks and rewards
• All avatars and reward icons
• Weekly and monthly progress reports with streaks

Premium is $2.99/month or $19.99/year, with a 7-day free trial on the yearly plan for new subscribers. Subscriptions renew automatically until cancelled in Google Play.
```

**Category:** Parenting. **Tags:** Parenting, Family, Productivity.

**Graphics:** 512×512 app icon, 1024×500 feature graphic, and at least 2 phone screenshots (Home, a child's tasks, Rewards, Reports).

**Contact details:** ByteForgedStudios@gmail.com

## 7. Signing and building

1. Create an upload key once and keep it safe; losing it means contacting Google to reset it:
   ```
   keytool -genkey -v -keystore %USERPROFILE%\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (git-ignored, never commit it):
   ```
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=C:\\Users\\<you>\\upload-keystore.jks
   ```
3. `flutter build appbundle`, then upload `build/app/outputs/bundle/release/app-release.aab`.
4. **[Console]** Use **Play App Signing** (the default). Google holds the app signing key; you keep the upload key.
5. Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`) for every upload; the number after `+` must always increase.

## 8. Before launch

- [ ] Privacy policy live at the URL, and linked in Console
- [ ] Subscriptions and yearly trial offer active; test purchase done on the internal track
- [ ] Server-side purchase verification (see the TODO in `premium_service.dart`)
- [ ] Data safety, target audience, content rating and app access forms complete
- [ ] Store listing, graphics and screenshots uploaded
- [ ] Release signed with the upload key
