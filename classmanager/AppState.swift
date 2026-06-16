//
//  AppState.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/7/25.
//

import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var attendee: RosterAttendee?
    @Published var lastScanRaw: String = ""
}

