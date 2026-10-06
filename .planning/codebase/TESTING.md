# Testing Patterns

**Analysis Date:** 2026-10-05

## Test Framework

**Runner:**
- `flutter_test` (Flutter SDK)

**Assertion Library:**
- `flutter_test` matchers (`expect`, `findsOneWidget`, `isA<T>()`).

**Run Commands:**
```bash
flutter test                                      # Run all tests in current package
flutter test test/navigation_test.dart            # Run single test file
melos run format:check                            # Monorepo format check
python tools/check_migrations.py                  # Verify database migration integrity
python tools/check_faq.py                         # Verify feature flag FAQ synchronization
```

## Test File Organization

**Location:**
- Dedicated `test/` directory in each app and package (`apps/swansport_app/test/`, `packages/swansport_data/test/`, etc.).

**Naming:**
- Matches target feature with `*_test.dart` suffix.

## Test Structure

**Sample Widget Test:**
```dart
void main() {
  testWidgets('renders bottom navigation with five items', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SwanBottomNav(),
          ),
        ),
      ),
    );
    expect(find.byType(SwanBottomNav), findsOneWidget);
  });
}
```

## Key Test Suites

- `apps/swansport_app/test/navigation_test.dart` - Verifies that every declared route has an accessible entry point.
- `apps/swansport_app/test/merged_routes_test.dart` - Verifies backward compatibility of merged legacy routes.
- `apps/swansport_app/test/inbox_actions_test.dart` - Verifies notification bell and message badge tap behaviors.
- `apps/swansport_app/test/swan_contrast_test.dart` - Accessibility contrast verification across theme modes.
- `tools/check_faq.py` - Ensures every feature flag exposed to testers/users has corresponding FAQ documentation.

---

*Testing analysis: 2026-10-05*
