//
//  main.swift
//  BeeBar
//
//  Entry point for the BeeBar macOS menu bar application.
//  Configures the shared NSApplication instance with AppDelegate and starts the main run loop.
//

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
