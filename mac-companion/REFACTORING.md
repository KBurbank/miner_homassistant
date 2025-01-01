# MinerTimer App Refactoring Plan

## Current State Analysis
- App is functional on Intel Mac (Catalina)
- Issues identified:
  - Too many files/components
  - Duplicate functionality
  - Unused functions
  - Potential circular dependencies

## Refactoring Goals
1. Simplify the codebase
2. Remove duplicate code
3. Eliminate unused functions
4. Resolve circular dependencies
5. Maintain existing functionality

## Approach
We will refactor one class at a time, ensuring the app remains functional after each change.
The process for each class will be:
1. Analyze dependencies and relationships
2. Identify unused code
3. Find duplicate functionality
4. Make changes
5. Test compilation
6. Verify functionality

## Class Analysis & Status

### Core Services
- [x] ProcessMonitor
  - Simplified to focus only on process management
  - Removed time-related functionality
  - Removed MQTT update logic
  - Reduced dependencies
- [x] StatusBarManager
  - No changes needed, already well-structured
- [x] NotificationManager
  - No changes needed, already well-structured
- [x] TimeScheduler
  - Consolidated time-related functionality
  - Improved MQTT update handling
  - Added proper day transition handling
- [x] HomeAssistantClient
  - Removed ProcessMonitor dependency
  - Simplified MQTT update logic
  - Improved message handling

### Models
- [ ] TimeIntervalKind
- [ ] Process
- [ ] HAConfig

### Views
- [ ] PasswordSheet
- [ ] SettingsWindowController

### App Infrastructure
- [x] AppDelegate
  - Updated to reflect service refactoring
  - Simplified initialization
  - Improved window management
  - Fixed actor isolation issues
  - Added back settings functionality
  - Improved state management
  - Selective actor isolation for properties
- [x] main.swift
  - Simplified app initialization
  - Fixed actor isolation issues
  - Proper application lifecycle management

## Progress Log
1. Refactored ProcessMonitor:
   - Removed time management functionality
   - Focused on process monitoring and control
   - Reduced dependencies

2. Updated TimeScheduler:
   - Consolidated time management logic
   - Improved day transition handling
   - Added proper MQTT integration

3. Simplified HomeAssistantClient:
   - Removed ProcessMonitor dependency
   - Streamlined MQTT update logic
   - Improved message handling

4. Updated AppDelegate:
   - Simplified initialization
   - Improved service coordination
   - Better window management
   - Fixed actor isolation issues
   - Added back settings functionality

5. Fixed Build Issues:
   - Resolved actor isolation in AppDelegate and main.swift
   - Fixed @main attribute conflicts
   - Properly handled async initialization
   - Added missing settings functionality

6. Fixed Initialization Issues:
   - Moved component initialization to applicationDidFinishLaunching
   - Added proper state management
   - Implemented selective actor isolation
   - Fixed application startup sequence

## Testing Strategy
After each class refactor:
1. Run build script
2. Test basic functionality
3. Document any issues or regressions

## Next Steps
1. Review and refactor Model classes
2. Update View components
3. Final cleanup and optimization

## Current Build Status
✅ Building successfully with minor warnings:
- Some async/await operations might be unnecessary
- All critical errors resolved
- Proper actor isolation implemented 