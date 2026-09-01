//
//  Date+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import Foundation

extension Date {
  func relativeNamedFormat(locale: Locale) -> String {
    var formatStyle = Date.RelativeFormatStyle()
    formatStyle.presentation = .named
    formatStyle.locale = locale
    return formatted(formatStyle)
  }
}

#endif
