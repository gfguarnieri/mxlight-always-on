No GUI

swiftc -O -parse-as-library SleepMonitor.swift -o mxsleepd -framework AppKit -framework IOKit

launchctl load   ~/Library/LaunchAgents/com.example.mxsleepd.plist

