//
//  timeUtils.swift
//  TrackMapper
//
//  Created by Jack Stanley on 1/4/26.
//

import Foundation

func humanReadable(time: Double) -> String {
    let hours = Int(time) / 3600
    let minutes = Int(time) / 60 % 60
    let seconds = Int(time) % 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else if minutes > 0 {
        return "\(minutes)m \(seconds)s"
    } else {
        return "\(seconds)s"
    }
}

func humanReadable(timeInterval: TimeInterval) -> String {
    return humanReadable(time: Double(timeInterval))
}
