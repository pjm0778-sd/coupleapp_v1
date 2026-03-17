# couple-profile-setup Analysis Report

> **Analysis Type**: Gap Analysis (Design vs Implementation)
>
> **Project**: coupleapp_v1
> **Version**: 1.0.0+1
> **Analyst**: Claude (gap-detector)
> **Date**: 2026-03-18
> **Design Doc**: [couple-profile-setup.design.md](../02-design/features/couple-profile-setup.design.md)

---

## 1. Analysis Overview

### 1.1 Analysis Purpose

Design document (couple-profile-setup.design.md) vs actual Flutter implementation gap detection for the PDCA Check phase.

### 1.2 Analysis Scope

- **Design Document**: `docs/02-design/features/couple-profile-setup.design.md`
- **Implementation Path**: `lib/features/onboarding/`, `lib/features/profile/`, `lib/features/settings/`, `lib/core/services/`
- **Files Analyzed**: 15 files
- **Analysis Date**: 2026-03-18

---

## 2. Overall Scores

| Category | Score | Status |
|----------|:-----:|:------:|
| Design Match | 72% | ⚠️ |
| Architecture Compliance | 78% | ⚠️ |
| Convention Compliance | 90% | ✅ |
| **Overall** | **76%** | **⚠️** |

---

## 3. Gap Analysis (Design vs Implementation)

### 3.1 Data Model

| Field / Item | Design | Implementation | Status |
|---|---|---|---|
| `id` (uuid PK) | `final String id` | Missing | ❌ |
| `userId` (uuid FK) | `final String userId` | Missing | ❌ |
| `coupleId` (uuid) | `final String? coupleId` | Missing | ❌ |
| `nickname` | `final String nickname` | Missing (saved separately via `saveNickname()`) | ⚠️ |
| `coupleStartDate` | `final DateTime coupleStartDate` | Missing (saved separately via `saveCoupleStartDate()`) | ⚠️ |
| `distanceType` | enum `DistanceType` | `String` (no enum) | ⚠️ |
| `myCity` | `String?` | `String?` | ✅ |
| `myStation` | `String?` | `String?` | ✅ |
| `partnerCity` | `String?` | `String?` | ✅ |
| `partnerStation` | `String?` | `String?` | ✅ |
| `workPattern` | enum `WorkPatternType` | `String` (no enum) | ⚠️ |
| `shiftTimes` | `List<ShiftTime>` (typed class) | `List<Map<String, dynamic>>` (untyped) | ⚠️ |
| `notifyMinutesBefore` | `int` (default 30) | `int` (default 30) | ✅ |
| `hasCar` | `bool` | `bool` | ✅ |
| `onboardingCompleted` | DB column only | `bool` field in model | ✅ |
| `createdAt` | `DateTime` | Missing | ❌ |
| `updatedAt` | `DateTime` | Missing | ❌ |
| computed `isConnected` | `coupleId != null` | Missing (no coupleId) | ❌ |
| computed `hasShiftWork` | getter | getter (matches logic) | ✅ |
| computed `isLongDistance` | getter | getter (matches logic) | ✅ |
| computed `hasTransportInfo` | getter | getter (matches logic) | ✅ |
| computed `hasNightShift` | getter | getter (matches logic) | ✅ |

**Design has a separate `ShiftTime` class** with typed fields (`shiftType`, `label`, `startTime: TimeOfDay`, `endTime: TimeOfDay`, `isNextDay`, plus `endDateTime()` method). Implementation uses raw `Map<String, dynamic>` instead.

**Data Model Score**: 60% (12/20 items match or partially match)

### 3.2 Supabase Schema Alignment

| Design Table | Implementation Reference | Status | Notes |
|---|---|---|---|
| `couple_profiles` (dedicated table) | `profiles` (shared existing table) | ⚠️ Changed | Implementation adds columns to existing `profiles` table instead of separate `couple_profiles` table |
| `invite_codes` table | Not directly referenced in scanned files | ⚠️ | Handled via `CoupleService` (external to analysis scope) |
| RLS: own profile R/W | Not verifiable from Dart code | -- | |
| RLS: partner read-only | Not verifiable from Dart code | -- | |

### 3.3 Service Layer (ProfileService)

| Design Method | Implementation | Status |
|---|---|---|
| `saveProfile(CoupleProfile)` | `saveProfile(CoupleProfile)` -- updates `profiles` table | ✅ |
| `loadMyProfile()` | `loadMyProfile()` -- selects from `profiles` | ✅ |
| `loadPartnerProfile()` | Missing | ❌ |
| `generateInviteCode()` | Missing (delegated to `CoupleService.getOrCreateMyCode()`) | ⚠️ |
| `connectWithCode(String)` | Missing (delegated to `CoupleService.connectWithCode()`) | ⚠️ |
| `watchPartnerProfile()` (Realtime) | Missing | ❌ |
| -- | `saveCoupleStartDate(DateTime)` | ⚠️ Added |
| -- | `saveNickname(String)` | ⚠️ Added |
| -- | `isOnboardingCompleted()` | ⚠️ Added |

**Service Score**: 50% (2/6 design methods implemented in ProfileService; 3 missing, 3 added)

### 3.4 FeatureFlag System

| Design Flag | Design Implementation | Actual Implementation | Status |
|---|---|---|---|
| `isDdayEnabled` | `coupleStartDate != null` | `true` (always on) | ⚠️ Changed |
| `isTransportEnabled` | `hasTransportInfo == true` | `hasTransportInfo ?? false` | ✅ |
| `isOcrAutoTimeEnabled` | `hasShiftWork && shiftTimes.isNotEmpty` | Same logic | ✅ |
| `isCommuteAlertEnabled` | `shiftTimes.isNotEmpty` | Same logic | ✅ |
| `isNightShiftDndEnabled` | `hasNightShift == true` | Same logic | ✅ |
| `isPartnerStatusEnabled` | `isConnected && hasShiftWork` | `hasShiftWork` only (no `isConnected` check) | ⚠️ Changed |
| Design: `ChangeNotifier` (Provider) | -- | Singleton service (no `ChangeNotifier`) | ⚠️ Changed |
| -- | -- | `isVisitTrackingEnabled` added | ⚠️ Added |
| -- | -- | `isCarOptionEnabled` added | ⚠️ Added |
| -- | -- | `getShiftTime()` helper added | ⚠️ Added |
| -- | -- | `notifyMinutesBefore` getter added | ⚠️ Added |
| -- | -- | `clear()` method added | ⚠️ Added |

**FeatureFlag Score**: 75% (4/6 core flags match, 2 changed, 5 additions)

### 3.5 Component / UI Structure

| Design Component | Design Location | Implementation File | Status |
|---|---|---|---|
| `OnboardingStep1Screen` | `onboarding/screens/` | `onboarding/screens/onboarding_step1_screen.dart` | ✅ |
| `OnboardingStep2Screen` | `onboarding/screens/` | `onboarding/screens/onboarding_step2_screen.dart` | ✅ |
| `OnboardingStep3Screen` | `onboarding/screens/` | `onboarding/screens/onboarding_step3_screen.dart` | ✅ |
| `OnboardingStep4Screen` | `onboarding/screens/` | `onboarding/screens/onboarding_step4_screen.dart` | ✅ |
| `ShiftTimeEditor` | `onboarding/widgets/` | `onboarding/widgets/shift_time_editor.dart` | ✅ |
| `CitySelectorWidget` | `onboarding/widgets/` | `onboarding/widgets/city_selector_widget.dart` | ✅ |
| `InviteCodeWidget` | `onboarding/widgets/` | Missing (inline in Step2) | ❌ |
| `ProfileSettingsScreen` | `profile/screens/` | Missing (merged into `settings/screens/settings_screen.dart`) | ⚠️ Changed |
| `OnboardingFlow` | `onboarding/` | `onboarding/onboarding_flow.dart` | ✅ |
| `OnboardingProgress` | -- (not in design) | `onboarding/onboarding_progress.dart` | ⚠️ Added |

**Component Score**: 80% (7/9 design components exist; 1 missing, 1 relocated)

### 3.6 File Structure

| Design Path | Implementation Path | Status |
|---|---|---|
| `models/couple_profile.dart` | `features/profile/models/couple_profile.dart` | ✅ |
| `models/shift_time.dart` | Missing (no separate file) | ❌ |
| `services/profile_service.dart` | `features/profile/services/profile_service.dart` | ✅ |
| `services/invite_code_service.dart` | Missing (handled by `couple/services/couple_service.dart`) | ⚠️ Changed |
| `providers/couple_profile_provider.dart` | Missing (no Provider pattern used) | ❌ |
| `providers/feature_flag_provider.dart` | `core/services/feature_flag_service.dart` (Singleton, not Provider) | ⚠️ Changed |
| `data/city_station_data.dart` | `features/profile/data/city_station_data.dart` | ✅ |
| `data/shift_defaults.dart` | `features/profile/data/shift_defaults.dart` | ✅ |

**File Structure Score**: 62% (4/8 match, 2 changed, 2 missing)

### 3.7 Onboarding Flow Behavior

| Design Behavior | Implementation | Status |
|---|---|---|
| 4-step PageView flow (Step1-4 -> HomeScreen) | PageView with 4 steps, navigates to '/' on complete | ✅ |
| Step 1: Nickname + couple start date | Nickname + date picker, "next" validation | ✅ |
| Step 2: Invite code generate + input + skip | Code display, input (6-char), connect, skip | ✅ |
| Step 2: Code format `AB12-CD34` (8 chars with dash) | 6-char uppercase alphanumeric (no dash) | ⚠️ Changed |
| Step 3: Distance type 3 options | 3 options with same labels/icons | ✅ |
| Step 3: Long distance -> city/station selector | CitySelectorWidget shown conditionally | ✅ |
| Step 4: 4 work pattern options | 4 options matching design | ✅ |
| Step 4: Shift time editor for shift_3/shift_2 | ShiftTimeEditor shown conditionally | ✅ |
| Step 4: notify_minutes_before dropdown | Dropdown with [10, 20, 30, 60] options | ✅ |
| Step 2: Kakao share button | Missing | ❌ |
| App start: onboarding_completed check | `main.dart` checks `onboarding_completed` from profiles | ✅ |
| Draft saved locally before completion | `_draft` state in OnboardingFlow | ✅ |
| Profile saved on completion | `_complete()` saves nickname, date, profile | ✅ |
| FeatureFlag refreshed on completion | `FeatureFlagService().refresh(...)` called | ✅ |

**Flow Score**: 85% (12/14 match)

### 3.8 Settings Screen

| Design Setting Section | Implementation | Status |
|---|---|---|
| Basic info (nickname, couple date) | Nickname edit + date edit in "couple info" section | ✅ |
| Partner info (connection status, partner nickname) | Partner nickname display, couple connection | ✅ |
| Distance settings (type, city/station) | Missing from settings | ❌ |
| Work settings (type, shift times, alert) | Work pattern picker + ShiftTimeEditor inline | ✅ |
| Transport (hasCar) | Missing from settings | ❌ |
| Dedicated ProfileSettingsScreen | Merged into general SettingsScreen | ⚠️ |

**Settings Score**: 60% (3/6 design sections present; 2 missing, 1 merged)

### 3.9 Static Data

| Design Data | Implementation | Status |
|---|---|---|
| 11 cities (Seoul~Jeju) + custom input | 14 cities (added Cheongju, Chuncheon, Gangneung) + custom input | ⚠️ Extended |
| Station names (parenthesis style) | Slightly different formatting: `(KTX)` vs `서울역(KTX)` -> `서울역 (KTX)` (space before paren) | ⚠️ Minor |
| Busan terminal: `부산종합터미널` | `부산종합터미널 (노포)` -- added sub-name | ⚠️ Minor |
| Shift defaults: D 06-15 / E 13-22 / N 20-08 | Matches exactly | ✅ |
| 2-shift defaults: day 07-19 / night 19-07 | Matches exactly | ✅ |
| Office default: 09-18 | Matches exactly | ✅ |
| shiftLabel() function | Present, matches all 4 patterns | ✅ |

**Static Data Score**: 90%

### 3.10 Error Handling

| Design Error Case | Implementation | Status |
|---|---|---|
| Invite code expired (7 days) | Not verifiable (in CoupleService) | -- |
| Already used code | `invalid_code` error caught, snackbar shown | ✅ |
| Own code entered | `own_code` error caught, snackbar shown | ✅ |
| Network error during onboarding | `try/catch` in `_complete()`, `debugPrint` only | ⚠️ Minimal |
| Realtime re-subscribe + manual refresh | Not implemented (no Realtime) | ❌ |

**Error Handling Score**: 50%

---

## 4. Missing Features (Design O, Implementation X)

| # | Item | Design Reference | Description | Impact |
|---|---|---|---|---|
| 1 | `ShiftTime` typed class | Design 3.1 | No separate class; raw Map used instead | Medium - reduces type safety |
| 2 | `shift_time.dart` file | Design 11.1 | Missing dedicated model file | Low |
| 3 | `invite_code_service.dart` | Design 11.1 | No dedicated service (in CoupleService) | Low - functionally equivalent |
| 4 | `CoupleProfileProvider` | Design 2.1, 11.1 | No ChangeNotifier/Provider state management | High - affects reactivity |
| 5 | `FeatureFlagProvider` (ChangeNotifier) | Design 6.1 | Singleton service instead of Provider | Medium - no auto-rebuild |
| 6 | `loadPartnerProfile()` | Design 4.3 | Not in ProfileService | Medium |
| 7 | `watchPartnerProfile()` Realtime | Design 4.3 | No Realtime subscription | High - core feature |
| 8 | `InviteCodeWidget` | Design 5.5 | Code UI inlined in Step2Screen | Low - functionally present |
| 9 | `ProfileSettingsScreen` | Design 5.5 | Merged into SettingsScreen | Low |
| 10 | Distance editing in Settings | Design 5.3 | Cannot change distance/city after onboarding | Medium |
| 11 | Transport (hasCar) in Settings | Design 5.3 | Cannot change hasCar after onboarding | Low |
| 12 | Kakao share button (Step 2) | Design 5.2 | No social sharing for invite code | Low |
| 13 | `couple_profiles` table (separate) | Design 3.3 | Uses `profiles` table instead | Medium - schema deviation |
| 14 | DistanceType / WorkPatternType enums | Design 3.1 | String literals instead of enums | Medium - type safety |
| 15 | `id`, `userId`, `coupleId`, `createdAt`, `updatedAt` fields | Design 3.1 | Missing from CoupleProfile model | Medium |

## 5. Added Features (Design X, Implementation O)

| # | Item | Location | Description |
|---|---|---|---|
| 1 | `OnboardingProgress` widget | `onboarding/onboarding_progress.dart` | Visual step progress bar (not in design component list) |
| 2 | `saveCoupleStartDate()` | `profile_service.dart` | Saves date to `couples` table separately |
| 3 | `saveNickname()` | `profile_service.dart` | Saves nickname separately |
| 4 | `isOnboardingCompleted()` | `profile_service.dart` | Standalone check method |
| 5 | `isVisitTrackingEnabled` flag | `feature_flag_service.dart` | Long-distance visit tracking |
| 6 | `isCarOptionEnabled` flag | `feature_flag_service.dart` | Car transport option |
| 7 | `getShiftTime()` helper | `feature_flag_service.dart` | Shift lookup by type |
| 8 | 3 additional cities | `city_station_data.dart` | Cheongju, Chuncheon, Gangneung |
| 9 | `getCities()` / `getStations()` helpers | `city_station_data.dart` | Convenience functions |
| 10 | Break-up flow in Settings | `settings_screen.dart` | Two-step confirmation couple disconnect |

## 6. Changed Features (Design != Implementation)

| # | Item | Design | Implementation | Impact |
|---|---|---|---|---|
| 1 | DB table name | `couple_profiles` | `profiles` (columns added) | Medium |
| 2 | State management | Provider (ChangeNotifier) | Singleton service | High |
| 3 | Invite code format | `AB12-CD34` (8 chars, dash) | 6-char alphanumeric | Low |
| 4 | `isDdayEnabled` logic | `coupleStartDate != null` | `true` (always) | Low |
| 5 | `isPartnerStatusEnabled` | requires `isConnected` | only checks `hasShiftWork` | Medium |
| 6 | ShiftTime data type | Typed `ShiftTime` class | Raw `Map<String, dynamic>` | Medium |
| 7 | ProfileSettings location | Separate screen | Merged into SettingsScreen | Low |
| 8 | City station name format | `서울역(KTX)` | `서울역 (KTX)` | Low |

---

## 7. Architecture Compliance

### 7.1 Layer Structure (Flutter/Feature-based)

| Expected Layer | Actual Path | Status |
|---|---|---|
| Presentation (screens) | `features/onboarding/screens/` | ✅ |
| Presentation (widgets) | `features/onboarding/widgets/` | ✅ |
| Domain (models) | `features/profile/models/` | ✅ |
| Application (services) | `features/profile/services/` | ✅ |
| Infrastructure (data) | `features/profile/data/` | ✅ |
| Core (services) | `core/services/` | ✅ |

### 7.2 Dependency Direction

| Source | Imports | Status |
|---|---|---|
| Screens -> Models | `onboarding_step3_screen.dart` -> `couple_profile.dart` | ✅ |
| Screens -> Widgets | `onboarding_step4_screen.dart` -> `shift_time_editor.dart` | ✅ |
| Screens -> Data | `onboarding_step4_screen.dart` -> `shift_defaults.dart` | ⚠️ Screen directly imports data layer |
| OnboardingFlow -> Service | `onboarding_flow.dart` -> `profile_service.dart` | ✅ |
| Settings -> Service | `settings_screen.dart` -> `profile_service.dart` | ✅ |
| Settings -> Supabase directly | `settings_screen.dart` imports `supabase_client.dart` | ❌ Bypasses service layer |

**Architecture Score**: 78%

---

## 8. Convention Compliance

### 8.1 Naming

| Category | Convention | Compliance | Notes |
|---|---|---|---|
| Classes | PascalCase | 100% | `CoupleProfile`, `ShiftTimeEditor`, etc. |
| Functions/Methods | camelCase | 100% | `loadMyProfile()`, `_pickTime()`, etc. |
| Constants | UPPER_SNAKE_CASE or camelCase | 90% | `shiftDefaults` (camelCase map, acceptable in Dart) |
| Files | snake_case.dart | 100% | All files follow Dart convention |
| Folders | snake_case | 100% | `shift_defaults`, `city_station_data` |

### 8.2 Flutter/Dart Conventions

| Item | Status |
|---|---|
| `const` constructors where applicable | ✅ |
| `super.key` parameter | ✅ |
| Proper `dispose()` for controllers | ✅ |
| `mounted` check after async | ✅ |

**Convention Score**: 90%

---

## 9. Match Rate Summary

```
+-----------------------------------------------+
|  Overall Match Rate: 72%                       |
+-----------------------------------------------+
|  Data Model:          60%  (12/20)             |
|  Service Layer:       50%  (2/6 + 3 added)     |
|  FeatureFlag:         75%  (4/6 + 5 added)     |
|  Components/UI:       80%  (7/9)               |
|  Onboarding Flow:     85%  (12/14)             |
|  Settings Screen:     60%  (3/6)               |
|  Static Data:         90%                      |
|  File Structure:      62%  (4/8)               |
|  Error Handling:      50%  (2/5)               |
|  Architecture:        78%                      |
|  Convention:          90%                      |
+-----------------------------------------------+
|  Missing features:    15 items                 |
|  Added features:      10 items                 |
|  Changed features:     8 items                 |
+-----------------------------------------------+
```

---

## 10. Recommended Actions

### 10.1 Immediate (High Impact)

| # | Action | Files Affected | Rationale |
|---|---|---|---|
| 1 | Create `ShiftTime` typed class in `shift_time.dart` | New file + `couple_profile.dart` | Type safety, design compliance, `endDateTime()` method needed for scheduling |
| 2 | Add missing fields to `CoupleProfile` (`id`, `userId`, `coupleId`, `nickname`, `coupleStartDate`) | `couple_profile.dart` | Core identity fields required for partner features |
| 3 | Add distance/transport editing to Settings | `settings_screen.dart` | Users cannot modify distance settings post-onboarding |
| 4 | Fix `isPartnerStatusEnabled` to check `isConnected` | `feature_flag_service.dart` | Currently shows partner status even when not connected |

### 10.2 Short-term

| # | Action | Files Affected | Rationale |
|---|---|---|---|
| 5 | Implement `loadPartnerProfile()` in ProfileService | `profile_service.dart` | Required for partner data features |
| 6 | Create enums `DistanceType`, `WorkPatternType` | `couple_profile.dart` or new files | Type safety, matches design |
| 7 | Remove direct Supabase calls from SettingsScreen | `settings_screen.dart` | Should go through ProfileService/CoupleService |
| 8 | Add network error user feedback in onboarding completion | `onboarding_flow.dart` | Currently only `debugPrint`, no user-visible error |

### 10.3 Long-term / Backlog

| # | Action | Notes |
|---|---|---|
| 9 | Implement Realtime partner profile subscription | Design specifies `watchPartnerProfile()` stream |
| 10 | Consider Provider/Riverpod for state management | Design specified `ChangeNotifier` pattern; current Singleton lacks reactivity |
| 11 | Add Kakao share for invite codes (Step 2) | Nice-to-have social sharing |
| 12 | Extract `InviteCodeWidget` from Step2Screen | Improves reusability |

### 10.4 Design Document Updates Needed

If implementation decisions are intentional, update the design doc to reflect:

- [ ] Table name: `profiles` instead of `couple_profiles`
- [ ] Singleton pattern instead of Provider for FeatureFlag
- [ ] Invite code format: 6-char instead of 8-char with dash
- [ ] `isDdayEnabled` always true (coupled with `couples.started_at`)
- [ ] Additional cities in city_station_data
- [ ] `OnboardingProgress` widget addition
- [ ] Break-up flow in Settings (not in original design)
- [ ] `saveCoupleStartDate()` and `saveNickname()` as separate operations

---

## 11. Synchronization Options

Given the 72% match rate, the following strategies are recommended:

1. **Modify implementation to match design** -- for items #1, #2, #3, #4 (type safety, missing fields, settings gaps)
2. **Update design to match implementation** -- for table name (`profiles`), invite code format, additional cities, Singleton pattern
3. **Record as intentional** -- break-up flow (added feature), additional FeatureFlag helpers

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-03-18 | Initial gap analysis | Claude (gap-detector) |
