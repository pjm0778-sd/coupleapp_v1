# couple-profile-setup Analysis Report

> **Analysis Type**: Gap Analysis (Design vs Implementation)
>
> **Project**: coupleapp_v1
> **Version**: 1.0.0+1
> **Analyst**: Claude (gap-detector)
> **Date**: 2026-03-18
> **Design Doc**: [couple-profile-setup.design.md](../02-design/features/couple-profile-setup.design.md)
> **Previous Analysis**: v0.1 (2026-03-18) -- 72% match rate
> **This Analysis**: v0.2 -- Re-analysis after GAP-FIX iterations

---

## 1. Analysis Overview

### 1.1 Analysis Purpose

Re-run Check phase gap analysis after GAP-FIX iterations. The previous analysis (v0.1) identified 15 missing items, 10 added items, and 8 changed items at 72% match rate. Several fixes have been applied since.

### 1.2 Analysis Scope

- **Design Document**: `docs/02-design/features/couple-profile-setup.design.md`
- **Implementation Path**: `lib/features/onboarding/`, `lib/features/profile/`, `lib/features/couple/`, `lib/core/services/`, `lib/features/settings/`
- **Files Analyzed**: 16 files
- **Analysis Date**: 2026-03-18

---

## 2. Overall Scores

| Category | Score | Status | Delta from v0.1 |
|----------|:-----:|:------:|:---:|
| Design Match | 79% | ⚠️ | +7% |
| Architecture Compliance | 80% | ⚠️ | +2% |
| Convention Compliance | 92% | ✅ | +2% |
| **Overall** | **82%** | **⚠️** | **+6%** |

---

## 3. Gap Analysis (Design vs Implementation)

### 3.1 Data Model -- CoupleProfile

| Field / Item | Design | Implementation | Status | v0.1 |
|---|---|---|---|---|
| `id` | `final String id` | `final String? id` (nullable) | ⚠️ Nullable | was ❌ |
| `userId` | `final String userId` | `final String? userId` (nullable) | ⚠️ Nullable | was ❌ |
| `coupleId` | `final String? coupleId` | `final String? coupleId` | ✅ | was ❌ |
| `nickname` | `final String nickname` | `final String? nickname` (nullable) | ⚠️ Nullable | was ⚠️ |
| `coupleStartDate` | `final DateTime coupleStartDate` | `final DateTime? coupleStartDate` (nullable) | ⚠️ Nullable | was ⚠️ |
| `distanceType` | enum `DistanceType` | `String` | ⚠️ No enum | same |
| `myCity` | `String?` | `String?` | ✅ | same |
| `myStation` | `String?` | `String?` | ✅ | same |
| `partnerCity` | `String?` | `String?` | ✅ | same |
| `partnerStation` | `String?` | `String?` | ✅ | same |
| `workPattern` | enum `WorkPatternType` | `String` | ⚠️ No enum | same |
| `shiftTimes` | `List<ShiftTime>` (typed) | `List<ShiftTime>` (typed) | ✅ | was ⚠️ Map |
| `notifyMinutesBefore` | `int` (default 30) | `int` (default 30) | ✅ | same |
| `hasCar` | `bool` | `bool` (default false) | ✅ | same |
| `onboardingCompleted` | DB schema only | `bool` field in model | ✅ | same |
| `createdAt` | `DateTime` | Missing | ❌ | same |
| `updatedAt` | `DateTime` | Missing | ❌ | same |
| computed `isConnected` | `coupleId != null` | `coupleId != null` | ✅ | was ❌ |
| computed `hasShiftWork` | getter | getter (matches) | ✅ | same |
| computed `isLongDistance` | getter | getter (matches) | ✅ | same |
| computed `hasTransportInfo` | getter | getter (matches) | ✅ | same |
| computed `hasNightShift` | getter | getter (matches) | ✅ | same |
| `fromMap()` / `toMap()` | Not specified | Implemented | ✅ Added |
| `copyWith()` | Not specified | Implemented | ✅ Added |

**Data Model Score**: 73% (16/22 match or close; 2 missing, 4 nullable deviation)

### 3.2 Data Model -- ShiftTime

| Field | Design | Implementation | Status | v0.1 |
|---|---|---|---|---|
| `shiftType` | `String` | `String` | ✅ | was ❌ (no class) |
| `label` | `String` | `String` | ✅ | was ❌ |
| `startTime` | `TimeOfDay` (direct) | `int startHour/startMinute` + `TimeOfDay get startTime` | ⚠️ Equivalent | was ❌ |
| `endTime` | `TimeOfDay` (direct) | `int endHour/endMinute` + `TimeOfDay get endTime` | ⚠️ Equivalent | was ❌ |
| `isNextDay` | `bool` | `bool` | ✅ | was ❌ |
| `endDateTime()` | Method | Method (matches logic) | ✅ | was ❌ |

**JSONB serialization key deviation**:

| Design Key | Implementation Key | Status |
|---|---|---|
| `start_hour` | `start_h` | ⚠️ Abbreviated |
| `start_minute` | `start_m` | ⚠️ Abbreviated |
| `end_hour` | `end_h` | ⚠️ Abbreviated |
| `end_minute` | `end_m` | ⚠️ Abbreviated |

### 3.3 Database Schema

| Design | Implementation | Status |
|--------|----------------|--------|
| Separate `couple_profiles` table | Columns on existing `profiles` table | ⚠️ Intentional deviation |
| Separate `invite_codes` table | `couples` table with `invite_code` column | ⚠️ Intentional deviation |
| `couple_start_date` in couple_profiles | `started_at` in `couples` table | ⚠️ Different location |
| CHECK constraint on `distance_type` | VARCHAR(20), no CHECK in migration | ⚠️ Missing constraint |
| CHECK constraint on `work_pattern` | VARCHAR(20), no CHECK in migration | ⚠️ Missing constraint |

### 3.4 Service Layer

| Design Method | Implementation | Status | v0.1 |
|---|---|---|---|
| `saveProfile(CoupleProfile)` | `saveProfile(CoupleProfile)` | ✅ | same |
| `loadMyProfile()` | `loadMyProfile()` | ✅ | same |
| `loadPartnerProfile()` (no args) | `loadPartnerProfile(String partnerId)` | ⚠️ Signature | was ❌ |
| `generateInviteCode()` | `CoupleService.getOrCreateMyCode()` | ⚠️ Different class | same |
| `connectWithCode(String)` | `CoupleService.connectWithCode(String)` | ⚠️ Different class | same |
| `watchPartnerProfile()` Stream | Not implemented | ❌ Missing | same |
| N/A | `saveNickname(String)` | ⚠️ Added | same |
| N/A | `saveCoupleStartDate(DateTime)` | ⚠️ Added | same |
| N/A | `isOnboardingCompleted()` | ⚠️ Added | same |

**Service Score**: 58% (3/6 design methods present in some form; 1 fully missing)

### 3.5 FeatureFlag System

| Flag | Design | Implementation | Status | v0.1 |
|---|---|---|---|---|
| `isDdayEnabled` | `coupleStartDate != null` | `true` (always) | ⚠️ Changed | same |
| `isTransportEnabled` | `hasTransportInfo == true` | Same | ✅ | same |
| `isOcrAutoTimeEnabled` | `hasShiftWork && shiftTimes.isNotEmpty` | Same | ✅ | same |
| `isCommuteAlertEnabled` | `shiftTimes.isNotEmpty` | Same | ✅ | same |
| `isNightShiftDndEnabled` | `hasNightShift == true` | Same | ✅ | same |
| `isPartnerStatusEnabled` | `isConnected && hasShiftWork` | `isConnected && hasShiftWork` | ✅ | was ⚠️ |
| Pattern | `ChangeNotifier` (Provider) | Singleton service | ⚠️ Changed | same |
| N/A | -- | `isVisitTrackingEnabled` | ⚠️ Added | same |
| N/A | -- | `isCarOptionEnabled` | ⚠️ Added | same |
| N/A | -- | `getShiftTime()` helper | ⚠️ Added | same |

**FeatureFlag Score**: 83% (5/6 core flags match; 1 changed)

### 3.6 Component / UI Structure

| Design Component | Design Location | Implementation | Status |
|---|---|---|---|
| `OnboardingStep1Screen` | `onboarding/screens/` | `onboarding/screens/onboarding_step1_screen.dart` | ✅ |
| `OnboardingStep2Screen` | `onboarding/screens/` | `onboarding/screens/onboarding_step2_screen.dart` | ✅ |
| `OnboardingStep3Screen` | `onboarding/screens/` | `onboarding/screens/onboarding_step3_screen.dart` | ✅ |
| `OnboardingStep4Screen` | `onboarding/screens/` | `onboarding/screens/onboarding_step4_screen.dart` | ✅ |
| `ShiftTimeEditor` | `onboarding/widgets/` | `onboarding/widgets/shift_time_editor.dart` | ✅ |
| `CitySelectorWidget` | `onboarding/widgets/` | `onboarding/widgets/city_selector_widget.dart` | ✅ |
| `InviteCodeWidget` | `onboarding/widgets/` | Missing (inline in Step2) | ❌ |
| `ProfileSettingsScreen` | `profile/screens/` | `settings/screens/settings_screen.dart` | ⚠️ Renamed/relocated |
| `OnboardingFlow` | `onboarding/` | `onboarding/onboarding_flow.dart` | ✅ |
| N/A | -- | `OnboardingProgress` | ⚠️ Added |
| N/A | -- | `CoupleConnectScreen` | ⚠️ Added |

**Component Score**: 82% (7/9 present; 1 missing widget, 1 relocated)

### 3.7 Onboarding Flow Behavior

| Design Behavior | Implementation | Status |
|---|---|---|
| 4-step PageView (Step1-4 -> Home) | PageView with 4 steps, navigates to '/' | ✅ |
| Step 1: Nickname + coupleStartDate | Nickname only (date deferred to settings) | ⚠️ Changed |
| Step 2: Code generate + input + skip | 6-char code, connect, skip | ✅ |
| Step 2: Code format `AB12-CD34` (8 chars) | 6-char uppercase, no dash | ⚠️ Changed |
| Step 2: KakaoTalk share button | Not implemented | ❌ |
| Step 3: 3 distance options | 3 matching options with icons | ✅ |
| Step 3: Long distance -> my + partner city/station | My city/station only (partner deferred) | ⚠️ Changed |
| Step 4: 4 work patterns | 4 matching patterns | ✅ |
| Step 4: ShiftTimeEditor (shift_3/shift_2) | Conditional editor shown | ✅ |
| Step 4: notifyMinutesBefore dropdown | Dropdown [10, 20, 30, 60] | ✅ |
| Step 4: hasCar toggle | Not in onboarding | ❌ |
| Draft saved locally before submit | `_draft` in OnboardingFlow | ✅ |
| FeatureFlag refreshed on completion | `FeatureFlagService().refresh()` | ✅ |
| Onboarding completion check at app start | `isOnboardingCompleted()` check | ✅ |

**Flow Score**: 79% (11/14 match)

### 3.8 Error Handling

| Design Error Case | Implementation | Status |
|---|---|---|
| Invite code expired (7 days) | Server-side via `connect_couple` RPC | ⚠️ Not verifiable client-side |
| Already used code | `invalid_code` catch -> snackbar | ✅ |
| Own code entered | `own_code` catch -> snackbar | ✅ |
| Network error: local temp save + retry | `try/catch` + `debugPrint` (no user feedback) | ⚠️ Minimal |
| Realtime resubscribe + manual refresh | Not implemented (no realtime) | ❌ |

**Error Handling Score**: 50%

### 3.9 Static Data

| Item | Design | Implementation | Status |
|---|---|---|---|
| Cities count | 11 + custom | 30+ + custom | ✅ Exceeds |
| Shift defaults (3-shift) | D 06-15, E 13-22, N 20-08 | Matches | ✅ |
| Shift defaults (2-shift) | day 07-19, night 19-07 | Matches | ✅ |
| Office default | 09-18 | Matches | ✅ |

**Static Data Score**: 95%

---

## 4. Match Rate Summary

```
+-----------------------------------------------+
|  Overall Match Rate: 79%                       |
+-----------------------------------------------+
|  Data Model:          73%  (was 60%)   +13%    |
|  Service Layer:       58%  (was 50%)   +8%     |
|  FeatureFlag:         83%  (was 75%)   +8%     |
|  Components/UI:       82%  (was 80%)   +2%     |
|  Onboarding Flow:     79%  (was 85%)   -6%*    |
|  Static Data:         95%  (was 90%)   +5%     |
|  Error Handling:      50%  (was 50%)    0%     |
|  Architecture:        80%  (was 78%)   +2%     |
|  Convention:          92%  (was 90%)   +2%     |
+-----------------------------------------------+
|  Missing features:     9 items  (was 15)       |
|  Added features:      11 items  (was 10)       |
|  Changed features:     9 items  (was  8)       |
+-----------------------------------------------+
* Flow score recalculated with finer granularity
```

---

## 5. Resolved Items (since v0.1)

Items from v0.1 that have been fixed:

| # | Item | Fix Applied |
|---|------|-------------|
| 1 | `ShiftTime` typed class | Created `shift_time.dart` with full typed model |
| 2 | `id`, `userId`, `coupleId` fields | Added as nullable fields to `CoupleProfile` |
| 3 | `nickname`, `coupleStartDate` fields | Added as nullable fields to `CoupleProfile` |
| 4 | `isConnected` computed property | Now works via `coupleId != null` |
| 5 | `isPartnerStatusEnabled` missing `isConnected` check | Fixed: now checks both `isConnected && hasShiftWork` |
| 6 | `loadPartnerProfile()` missing | Added to `ProfileService` (with partnerId param) |
| 7 | `shift_time.dart` file missing | Created with full implementation |
| 8 | `shiftTimes` as `List<Map>` | Now `List<ShiftTime>` with typed serialization |

---

## 6. Remaining Missing Features (Design O, Implementation X)

| # | Item | Design Reference | Impact | Priority |
|---|------|-----------------|--------|----------|
| 1 | `CoupleProfileProvider` (ChangeNotifier) | Design 2.1 | High -- no reactive state | Low (singleton pattern works) |
| 2 | `watchPartnerProfile()` realtime stream | Design 4.3 | High -- core feature | High |
| 3 | KakaoTalk share button (Step 2) | Design 5.2 | Low | Low |
| 4 | `InviteCodeWidget` as separate widget | Design 5.5 | Low -- functionally present inline | Low |
| 5 | `DistanceType` / `WorkPatternType` enums | Design 3.1 | Medium -- type safety | Medium |
| 6 | `createdAt` / `updatedAt` in model | Design 3.1 | Low | Low |
| 7 | `hasCar` toggle in onboarding Step 4 | Design 5.2 | Low | Low |
| 8 | Network error user feedback in onboarding | Design 8 | Medium | Medium |
| 9 | DB CHECK constraints on distance_type/work_pattern | Design 3.3 | Low | Low |

## 7. Added Features (Design X, Implementation O)

| # | Item | Location | Description |
|---|------|---------|-------------|
| 1 | `CoupleConnectScreen` | `couple/screens/` | Standalone connect screen (post-onboarding) |
| 2 | `OnboardingProgress` | `onboarding/` | Visual step progress bar |
| 3 | `isVisitTrackingEnabled` | `feature_flag_service.dart` | Long-distance visit tracking |
| 4 | `isCarOptionEnabled` | `feature_flag_service.dart` | Car transport option |
| 5 | `getShiftTime()` helper | `feature_flag_service.dart` | Shift lookup by type |
| 6 | `saveCoupleStartDate()` | `profile_service.dart` | Separate date save |
| 7 | `saveNickname()` | `profile_service.dart` | Separate nickname save |
| 8 | `isOnboardingCompleted()` | `profile_service.dart` | Standalone check |
| 9 | Expanded city data (30+ cities) | `city_station_data.dart` | Far exceeds design |
| 10 | Couple disconnect flow | `settings_screen.dart` | Two-step breakup confirmation |
| 11 | `fromMap()` / `toMap()` / `copyWith()` | `couple_profile.dart` | Serialization utilities |

## 8. Changed Features (Design != Implementation)

| # | Item | Design | Implementation | Impact |
|---|------|--------|----------------|--------|
| 1 | DB table | Separate `couple_profiles` | Columns on `profiles` | Medium (intentional) |
| 2 | Invite code storage | Separate `invite_codes` table | `couples.invite_code` | Medium (intentional) |
| 3 | State management | ChangeNotifier providers | Singleton service | Medium |
| 4 | Step 1 content | Nickname + coupleStartDate | Nickname only | Medium |
| 5 | Step 3 scope | My + partner city/station | My only (partner in settings) | Medium |
| 6 | Invite code format | `AB12-CD34` (8 chars, dash) | 6-char alphanumeric | Low |
| 7 | `isDdayEnabled` | Conditional on date | Always true | Low |
| 8 | JSONB keys | `start_hour` / `start_minute` | `start_h` / `start_m` | Low |
| 9 | ProfileSettingsScreen | `profile/screens/` | `settings/screens/settings_screen.dart` | Low |

---

## 9. Architecture Compliance

### 9.1 Layer Structure

| Expected | Actual | Status |
|---|---|---|
| Presentation (screens) | `features/onboarding/screens/` | ✅ |
| Presentation (widgets) | `features/onboarding/widgets/` | ✅ |
| Domain (models) | `features/profile/models/` | ✅ |
| Application (services) | `features/profile/services/`, `couple/services/` | ✅ |
| Infrastructure (data) | `features/profile/data/` | ✅ |
| Core (services) | `core/services/` | ✅ |

### 9.2 Dependency Violations

| File | Issue | Severity |
|---|---|---|
| `settings_screen.dart` | Imports `supabase_client.dart` directly (bypasses service layer) | Medium |
| `onboarding_step4_screen.dart` | Imports `shift_defaults.dart` (data layer from screen) | Low |

**Architecture Score**: 80%

---

## 10. Convention Compliance

| Category | Convention | Compliance |
|---|---|:---:|
| Classes | PascalCase | 100% |
| Methods | camelCase | 100% |
| Files | snake_case.dart | 100% |
| Folders | snake_case | 100% |
| `const` constructors | Where applicable | 100% |
| `super.key` | All StatefulWidget/StatelessWidget | 100% |
| `dispose()` for controllers | All TextEditingController/PageController | 100% |
| `mounted` check after async | All async setState calls | 100% |
| Import order | External -> Internal -> Relative | 90% |

**Convention Score**: 92%

---

## 11. Recommended Actions

### 11.1 Immediate (to reach 85%+)

| # | Action | Impact |
|---|--------|--------|
| 1 | Add `DistanceType` / `WorkPatternType` enums | +3% model score |
| 2 | Add user-facing error feedback in onboarding `_complete()` | +2% error handling |
| 3 | Remove direct Supabase import from `settings_screen.dart` | +2% architecture |

### 11.2 Short-term (to reach 90%)

| # | Action | Impact |
|---|--------|--------|
| 4 | Implement `watchPartnerProfile()` realtime stream | +5% service score |
| 5 | Add `hasCar` toggle to onboarding Step 4 | +1% flow score |
| 6 | Make `id`, `userId`, `nickname`, `coupleStartDate` non-nullable | +2% model score |

### 11.3 Design Document Updates Needed

Update the design doc to match intentional implementation decisions:

- [ ] DB schema: `profiles` columns instead of separate `couple_profiles` table
- [ ] DB schema: `couples.invite_code` instead of `invite_codes` table
- [ ] Step 1: Nickname only (coupleStartDate moved to settings)
- [ ] Step 3: My city/station only (partner deferred to settings)
- [ ] Invite code: 6-char format
- [ ] State management: Singleton FeatureFlagService
- [ ] `isDdayEnabled`: Always true
- [ ] JSONB keys: `start_h`/`start_m`/`end_h`/`end_m`
- [ ] Settings screen location: `features/settings/`
- [ ] Added features: OnboardingProgress, CoupleConnectScreen, disconnect flow

---

## 12. Synchronization Recommendation

| Strategy | Items |
|----------|-------|
| Modify implementation to match design | Enums, realtime stream, hasCar in onboarding, error feedback |
| Update design to match implementation | DB schema, invite code format, Step 1/3 scope, JSONB keys, singleton pattern |
| Record as intentional | CoupleConnectScreen, OnboardingProgress, expanded city data, disconnect flow |

Match rate 79% falls in the 70-90% range: **"There are some differences. Document update is recommended."**

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-03-18 | Initial gap analysis (72%) | Claude (gap-detector) |
| 0.2 | 2026-03-18 | Re-analysis after GAP-FIX iterations (79%) | Claude (gap-detector) |
