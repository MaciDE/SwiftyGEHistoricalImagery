//
//  DateFormatter+rfc1123.swift
//
//
//  Created by Marcel Opitz on 07.01.24.
//

import Foundation

extension DateFormatter {
    static var rfc1123: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter
    }
}
