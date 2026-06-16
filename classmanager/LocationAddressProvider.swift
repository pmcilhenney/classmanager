//
//  LocationAddressProvider.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/29/25.
//
import Foundation
import CoreLocation

final class LocationAddressProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((String?) -> Void)?

    func getCurrentAddress(completion: @escaping (String?) -> Void) {
        self.completion = completion
        manager.delegate = self

        // Make sure you have NSLocationWhenInUseUsageDescription in Info.plist
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            completion?(nil)
            completion = nil
            return
        }

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, error in
            guard let self = self else { return }

            if let p = placemarks?.first {
                var parts: [String] = []

                if let sub = p.subThoroughfare, let street = p.thoroughfare {
                    parts.append("\(sub) \(street)")
                } else if let street = p.thoroughfare {
                    parts.append(street)
                }

                if let city = p.locality {
                    parts.append(city)
                }
                if let state = p.administrativeArea {
                    parts.append(state)
                }
                if let zip = p.postalCode {
                    parts.append(zip)
                }

                let address = parts.joined(separator: ", ")
                self.completion?(address.isEmpty ? nil : address)
            } else {
                self.completion?(nil)
            }

            self.completion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil)
        completion = nil
    }
}
