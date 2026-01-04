# Contributing to Snapflow

Thank you for your interest in contributing to Snapflow! This guide will help you maintain code quality and consistency with our Material Design 3 standards.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Material3 Guidelines](#material3-guidelines)
3. [Code Style](#code-style)
4. [Development Workflow](#development-workflow)
5. [Pull Request Process](#pull-request-process)
6. [Testing Requirements](#testing-requirements)

---

## Getting Started

### Prerequisites

- Flutter SDK 3.19+ (stable channel)
- Firebase CLI
- Android Studio or VS Code with Flutter extensions
- Git

### Setup

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/snapflow.git`
3. Install dependencies: `flutter pub get`
4. Configure Firebase: Follow setup in [README.md](README.md)
5. Run the app: `flutter run`

---

## Material3 Guidelines

**CRITICAL:** Snapflow is 100% Material Design 3 compliant. All code contributions MUST maintain this compliance.

### Required Reading

Before making any UI changes, read:
- [Theming Guide](docs/THEMING_GUIDE.md) - Comprehensive Material3 patterns
- [Testing Checklist](docs/MATERIAL3_TESTING_CHECKLIST.md) - Validation requirements
- [Material Design 3 Docs](https://m3.material.io/)

### Color System

**✅ DO:**
```dart
// Use colorScheme tokens
Container(
  color: Theme.of(context).colorScheme.surface,
  child: Text(
    'Hello',
    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
  ),
)
```

**❌ DON'T:**
```dart
// Never hardcode colors
Container(
  color: Colors.white,
  child: Text('Hello', style: TextStyle(color: Colors.black)),
)
```

**Exceptions (must be documented):**
- Video overlays requiring specific contrast (Colors.white/white70)
- Semantic colors (red delete button, green success states)
- Colors.transparent for gesture detection
- Camera UI colors (black backgrounds for video capture)

### Typography System

**✅ DO:**
```dart
// Use textTheme tokens
Text(
  'Welcome',
  style: Theme.of(context).textTheme.displayMedium,
)

// TextField with theme-aware styling
TextField(
  style: Theme.of(context).textTheme.bodyLarge,
)
```

**❌ DON'T:**
```dart
// Never hardcode font sizes
Text('Welcome', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold))
```

**Exceptions (must be documented):**
- Video overlay text (fontSize 12 for compact display)
- Small badges (fontSize 10 for intentional tiny text)
- Custom notification hierarchy (fontSize 13-15)

### Spacing System

**✅ DO:**
```dart
// Use AppSpacing constants
Padding(
  padding: AppSpacing.horizontalLg,
  child: Column(
    children: [
      SizedBox(height: AppSpacing.md),
      Widget1(),
      SizedBox(height: AppSpacing.lg),
      Widget2(),
    ],
  ),
)
```

**❌ DON'T:**
```dart
// Never hardcode spacing
Padding(
  padding: EdgeInsets.symmetric(horizontal: 16),
  child: Column(
    children: [
      SizedBox(height: 12),
      Widget1(),
      SizedBox(height: 16),
      Widget2(),
    ],
  ),
)
```

### Shadow System

**✅ DO:**
```dart
// Use Material3 elevation
Card(
  elevation: 1,
  child: Widget(),
)

// Or AppShadows for custom shadows
Container(
  decoration: BoxDecoration(
    boxShadow: [AppShadows.medium],
  ),
)
```

**❌ DON'T:**
```dart
// Never create custom shadows without reason
Container(
  decoration: BoxDecoration(
    boxShadow: [
      BoxShadow(
        blurRadius: 15,
        color: Colors.black.withValues(alpha: 0.2),
      ),
    ],
  ),
)
```

### Animation Standards

**✅ DO:**
```dart
// Use AppDurations constants
AnimatedOpacity(
  duration: AppDurations.standard,
  curve: Curves.easeInOut,
  opacity: isVisible ? 1.0 : 0.0,
  child: Widget(),
)
```

**❌ DON'T:**
```dart
// Never hardcode durations
AnimatedOpacity(
  duration: Duration(milliseconds: 300),
  opacity: isVisible ? 1.0 : 0.0,
  child: Widget(),
)
```

### Button Components

**✅ DO:**
```dart
// Primary actions
FilledButton(
  onPressed: () {},
  child: Text('Submit'),
)

// Secondary actions
OutlinedButton(
  onPressed: () {},
  child: Text('Cancel'),
)

// Tertiary actions
TextButton(
  onPressed: () {},
  child: Text('Skip'),
)
```

**❌ DON'T:**
```dart
// Never use ElevatedButton (deprecated in Material3)
ElevatedButton(
  onPressed: () {},
  child: Text('Submit'),
)
```

---

## Code Style

### GetX Patterns

**Controllers:**
```dart
class FeatureController extends GetxController {
  // Reactive state
  final items = <Model>[].obs;
  final isLoading = false.obs;
  
  // Services (injected)
  final Repository _repo = Get.find();
  
  @override
  void onReady() {
    super.onReady();
    loadItems(); // Auth-dependent operations in onReady, not onInit
  }
  
  @override
  void onClose() {
    // Dispose subscriptions
    super.onClose();
  }
}
```

**Views:**
```dart
class FeatureView extends GetView<FeatureController> {
  const FeatureView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return LoadingWidget();
        }
        return ListView.builder(
          itemCount: controller.items.length,
          itemBuilder: (context, index) {
            return ItemWidget(controller.items[index]);
          },
        );
      }),
    );
  }
}
```

### File Organization

```
lib/app/modules/feature/
├── controllers/
│   └── feature_controller.dart
├── views/
│   └── feature_view.dart
├── bindings/
│   └── feature_binding.dart
└── widgets/
    └── feature_widget.dart
```

### Naming Conventions

- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variables:** `camelCase`
- **Constants:** `camelCase` (not SCREAMING_CASE)
- **Private:** `_leadingUnderscore`

---

## Development Workflow

### Branch Strategy

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/feature-name` - New features
- `fix/bug-description` - Bug fixes
- `refactor/area-name` - Code refactoring

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add video upload progress indicator
fix: resolve profile navigation from search
refactor: migrate LoginView to Material3
docs: update theming guide with new patterns
test: add unit tests for VideoRepository
```

### Before Committing

1. Run `flutter analyze` - Must pass with 0 errors
2. Run `flutter test` - All tests must pass
3. Format code: `flutter format lib/`
4. Check Material3 compliance: Review [Testing Checklist](docs/MATERIAL3_TESTING_CHECKLIST.md)
5. Hot reload app to verify UI changes visually

---

## Pull Request Process

### PR Checklist

- [ ] Code follows Material3 guidelines (see [Theming Guide](docs/THEMING_GUIDE.md))
- [ ] All colors use `colorScheme` tokens (no hardcoded colors)
- [ ] All text uses `textTheme` tokens (or documented exception)
- [ ] All spacing uses `AppSpacing` constants
- [ ] All shadows use `AppShadows` or Material3 elevation
- [ ] All animations use `AppDurations` constants
- [ ] All buttons use Material3 components (FilledButton/OutlinedButton/TextButton)
- [ ] Dark theme support maintained (test both themes)
- [ ] `flutter analyze` passes with 0 errors
- [ ] `flutter test` passes all tests
- [ ] UI tested on both Android and iOS (if applicable)
- [ ] No performance regressions (animations smooth at 60fps)
- [ ] Documentation updated if adding new patterns

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation
- [ ] UI/UX improvement

## Material3 Compliance
- [ ] Uses colorScheme tokens
- [ ] Uses textTheme tokens
- [ ] Uses AppSpacing constants
- [ ] Uses AppShadows/elevation
- [ ] Uses Material3 components
- [ ] Dark theme tested

## Screenshots (if UI changes)
- Before: [screenshot]
- After: [screenshot]
- Dark theme: [screenshot]

## Testing
- [ ] flutter analyze passes
- [ ] flutter test passes
- [ ] Manual testing completed
- [ ] No performance regressions

## Related Issues
Closes #123
```

### Review Process

1. Automated checks (CI/CD)
2. Code review by maintainer
3. Material3 compliance verification
4. Testing on emulator/device
5. Approval and merge

---

## Testing Requirements

### Unit Tests

All new features must include unit tests:

```dart
// test/controllers/feature_controller_test.dart
void main() {
  group('FeatureController', () {
    late FeatureController controller;
    
    setUp(() {
      controller = FeatureController();
    });
    
    test('should load items successfully', () async {
      await controller.loadItems();
      expect(controller.items.isNotEmpty, true);
      expect(controller.isLoading.value, false);
    });
  });
}
```

### Widget Tests

UI components should have widget tests:

```dart
// test/widgets/feature_widget_test.dart
void main() {
  testWidgets('FeatureWidget displays correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FeatureWidget()),
    );
    
    expect(find.text('Expected Text'), findsOneWidget);
  });
}
```

### Integration Tests

Critical user flows must have integration tests:

```dart
// integration_test/app_test.dart
void main() {
  testWidgets('complete video upload flow', (tester) async {
    // Test complete user flow
  });
}
```

### Material3 Compliance Testing

Before submitting PR, verify:

1. All screens use `colorScheme` tokens
2. All text uses `textTheme` tokens (or documented exception)
3. All spacing uses `AppSpacing` constants
4. All shadows use `AppShadows` or Material3 elevation
5. All animations smooth at 60fps
6. Dark theme works correctly
7. No visual regressions

Use the [Testing Checklist](docs/MATERIAL3_TESTING_CHECKLIST.md) for comprehensive verification.

---

## Code Review Checklist

**For Reviewers:**

### Material3 Compliance
- [ ] No hardcoded colors (except documented exceptions)
- [ ] No hardcoded font sizes (except documented exceptions)
- [ ] No hardcoded spacing (except documented exceptions)
- [ ] No custom shadows without justification
- [ ] No hardcoded animation durations
- [ ] Uses Material3 button components (FilledButton, not ElevatedButton)
- [ ] Dark theme support maintained

### Code Quality
- [ ] Follows GetX patterns (controllers, views, bindings)
- [ ] Proper error handling
- [ ] No memory leaks (subscriptions disposed in onClose)
- [ ] No hardcoded strings (use localization or constants)
- [ ] Comments explain "why", not "what"
- [ ] No dead code or commented-out code

### Performance
- [ ] No unnecessary rebuilds
- [ ] Efficient list rendering (ListView.builder)
- [ ] Images cached appropriately
- [ ] Animations smooth at 60fps
- [ ] No janky scrolling

### Testing
- [ ] Unit tests added for new logic
- [ ] Widget tests added for new UI
- [ ] Integration tests for critical flows
- [ ] Manual testing completed
- [ ] Edge cases handled

---

## Common Pitfalls

### 1. Using Colors.* Directly
**Problem:** Hardcoded colors break dark theme and Material3 compliance

**Solution:** Always use `Theme.of(context).colorScheme.*` tokens

### 2. Hardcoded TextStyle
**Problem:** Inconsistent typography and difficult maintenance

**Solution:** Use `Theme.of(context).textTheme.*` tokens

### 3. Custom Spacing Values
**Problem:** Inconsistent spacing breaks Material3 4dp grid

**Solution:** Use `AppSpacing.*` constants

### 4. Firebase Auth in onInit()
**Problem:** Auth state not restored yet, causes null errors

**Solution:** Use `onReady()` for auth-dependent operations

### 5. Not Disposing Subscriptions
**Problem:** Memory leaks

**Solution:** Cancel subscriptions in `onClose()`

### 6. Using ElevatedButton
**Problem:** Deprecated in Material3

**Solution:** Use `FilledButton` for primary actions

---

## Getting Help

- 📖 Read the [Theming Guide](docs/THEMING_GUIDE.md)
- ✅ Check the [Testing Checklist](docs/MATERIAL3_TESTING_CHECKLIST.md)
- 🐛 Search existing [Issues](https://github.com/YOUR_USERNAME/snapflow/issues)
- 💬 Join our Discord community (if applicable)
- 📧 Email maintainers at [your-email@example.com]

---

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing to Snapflow! Your efforts help make the app better for everyone.** 🎉
