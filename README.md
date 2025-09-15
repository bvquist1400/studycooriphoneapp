# StudyCoor

A pharmaceutical study coordination app for iOS that helps calculate dosing schedules, track compliance, and manage study subjects.

## Overview

StudyCoor provides tools for clinical study coordinators to:
- Calculate medication doses and schedules
- Track subject compliance 
- Manage study data and history
- Generate reports and calculations

## Requirements

- **Xcode 15.0** or later
- **iOS 17.0** target minimum
- **macOS 13.0** or later for development

## Build and Run

1. Clone or download the project
2. Open `StudyCoor.xcodeproj` in Xcode
3. Select your target device or simulator
4. Press ⌘+R to build and run

### Project Structure

- `StudyCoor/` - Main app target and entry point
- `Models/` - Core data models (Drug, Study, Subject, etc.)
- `Views/` - SwiftUI views and screens
- `Engine/` - Calculation and compliance logic
- `StudyCoorCalc/` - Calculation utilities
- `StudyCoorTests/` - Unit tests
- `StudyCoorUITests/` - UI automation tests

## Features

- Dosing calculation with partial dose support
- Study subject management
- Compliance tracking and monitoring  
- Calculation history
- Export capabilities
- Dark/light theme support

## Development

The app uses SwiftUI with SwiftData for local storage. Core calculation logic is separated into dedicated engine modules for testability and maintainability.