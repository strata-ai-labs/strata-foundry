//
//  FormatHelpers.swift
//  StrataFoundry
//
//  Shared formatting utilities extracted from duplicated view code.
//

import Foundation

// MARK: - Byte Formatting

/// Format a byte count as human-readable size (B, KB, MB, GB).
func formatBytes(_ bytes: UInt64) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    let kb = Double(bytes) / 1024.0
    if kb < 1024 { return String(format: "%.1f KB", kb) }
    let mb = kb / 1024.0
    if mb < 1024 { return String(format: "%.1f MB", mb) }
    let gb = mb / 1024.0
    return String(format: "%.1f GB", gb)
}

/// Format a byte count as human-readable size (Int variant).
func formatBytes(_ bytes: Int) -> String {
    formatBytes(UInt64(max(0, bytes)))
}

// MARK: - Timestamp Formatting

/// Format a microsecond timestamp as a human-readable date/time string.
func formatTimestamp(_ microseconds: UInt64) -> String {
    let date = Date(timeIntervalSince1970: Double(microseconds) / 1_000_000.0)
    return timestampFormatter.string(from: date)
}

/// Shared date formatter for timestamp display.
private let timestampFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .medium
    return f
}()

// MARK: - Uptime Formatting

/// Format seconds as a human-readable uptime string.
func formatUptime(_ seconds: UInt64) -> String {
    if seconds < 60 { return "\(seconds)s" }
    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m \(seconds % 60)s" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h \(minutes % 60)m" }
    let days = hours / 24
    return "\(days)d \(hours % 24)h"
}

/// Format seconds as uptime (Int variant).
func formatUptime(_ seconds: Int) -> String {
    formatUptime(UInt64(max(0, seconds)))
}

// MARK: - Time Travel

/// Convert a Date to microseconds since epoch for as_of queries.
func dateToMicros(_ date: Date) -> UInt64 {
    UInt64(date.timeIntervalSince1970 * 1_000_000)
}

/// Convert an optional time-travel Date to an optional as_of value.
func asOfFromDate(_ date: Date?) -> UInt64? {
    date.map { dateToMicros($0) }
}
