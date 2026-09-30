#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p .build
python3 Scripts/check_localization.py
swiftc Sources/Core.swift Sources/Localization.swift Tests/BudgetTests.swift -o .build/BudgetTests
.build/BudgetTests
swiftc Sources/Core.swift Sources/Localization.swift Sources/Learning.swift Sources/Journey.swift Sources/Places.swift Sources/EnergyPolicy.swift Sources/PlaceHistory.swift Sources/AutomaticSessions.swift Sources/Companion.swift Sources/Hardware.swift Tests/LearningTests.swift -o .build/LearningTests
.build/LearningTests
swiftc -swift-version 5 Sources/Core.swift Sources/Localization.swift Sources/Learning.swift Sources/Journey.swift Sources/Places.swift Sources/EnergyPolicy.swift Sources/PlaceHistory.swift Sources/AutomaticSessions.swift Sources/Hardware.swift Sources/NativeApps.swift Sources/Conditions.swift Sources/Companion.swift Sources/Performance.swift Sources/BatteryHistory.swift Sources/System.swift Sources/Integrations.swift Tests/IntegrationTests.swift -o .build/IntegrationTests -framework AppKit -framework IOKit -framework CoreLocation -framework UserNotifications -framework ServiceManagement
.build/IntegrationTests
swiftc Sources/Core.swift Sources/Localization.swift Sources/Learning.swift Sources/Journey.swift Sources/Places.swift Sources/EnergyPolicy.swift Sources/PlaceHistory.swift Sources/AutomaticSessions.swift Sources/Companion.swift Tests/JourneyTests.swift -o .build/JourneyTests
.build/JourneyTests
swiftc Sources/Core.swift Sources/Localization.swift Sources/Learning.swift Sources/Journey.swift Sources/Companion.swift Tests/CompanionTests.swift -o .build/CompanionTests
.build/CompanionTests
swiftc -swift-version 5 Sources/Core.swift Sources/Localization.swift Sources/Learning.swift Sources/Journey.swift Sources/Places.swift Sources/EnergyPolicy.swift Sources/PlaceHistory.swift Sources/AutomaticSessions.swift Sources/Companion.swift Sources/Integrations.swift Tests/LocationInputTests.swift -o .build/LocationInputTests -framework AppKit -framework CoreLocation -framework UserNotifications -framework ServiceManagement
.build/LocationInputTests
swiftc Sources/Core.swift Sources/Localization.swift Sources/Learning.swift Sources/Journey.swift Sources/Companion.swift Sources/AutomaticSessions.swift Tests/AutomaticSessionTests.swift -o .build/AutomaticSessionTests
.build/AutomaticSessionTests
swiftc Sources/PlaceHistory.swift Tests/PlaceHistoryTests.swift -o .build/PlaceHistoryTests
.build/PlaceHistoryTests
swiftc Sources/EnergyPolicy.swift Tests/EnergyPolicyTests.swift -o .build/EnergyPolicyTests
.build/EnergyPolicyTests

swiftc Sources/BatteryHistory.swift Tests/BatteryHistoryTests.swift -o .build/BatteryHistoryTests
.build/BatteryHistoryTests

swiftc Sources/Core.swift Sources/Localization.swift Tests/LocalizationTests.swift -o .build/LocalizationTests
.build/LocalizationTests

swiftc Sources/Core.swift Sources/Localization.swift Sources/Learning.swift Sources/Journey.swift Sources/Companion.swift Sources/AutomaticSessions.swift Tests/RoutineAutonomyTests.swift -o .build/RoutineAutonomyTests
.build/RoutineAutonomyTests
