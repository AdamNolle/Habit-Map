# Habit Map

Non-punishing pixel-art habit tracker for iOS, iPadOS, and watchOS.

## Setup

1. `brew install xcodegen` (one-time)
2. `xcodegen generate` (after pulling, or after editing `project.yml`)
3. `open HabitMap.xcodeproj`
4. Build & run on iOS 17+ simulator

## Project layout

- `Packages/HabitMapCore` — Swift package containing models, design system, components, services
- `Apps/iOS` — iOS app target (thin shell around HabitMapCore)
- `project.yml` — XcodeGen manifest, source of truth for project structure

## Regenerating the project

Edit `project.yml`, then run `xcodegen generate`. The `.xcodeproj` is committed for CI stability but is fully regenerable.

## Running tests

```bash
xcodebuild -scheme HabitMap -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Or run from Xcode (⌘U).
