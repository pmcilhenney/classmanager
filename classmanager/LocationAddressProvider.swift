//
//  LocationAddressProvider.swift
//  classmanager
//
//  Created by Patrick McIlhenney on 11/29/25.
//
import Foundation
import CoreLocation

struct AttendanceLocationSnapshot {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let address: String?
}

final class LocationAddressProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((String?) -> Void)?
    private var locationCompletion: ((AttendanceLocationSnapshot?) -> Void)?
    private var pendingRequestAfterAuthorization = false

    func getCurrentAddress(completion: @escaping (String?) -> Void) {
        self.completion = completion
        manager.delegate = self

        requestWhenReady()
    }

    func getCurrentLocation(completion: @escaping (AttendanceLocationSnapshot?) -> Void) {
        self.locationCompletion = completion
        manager.delegate = self

        requestWhenReady()
    }

    private func requestWhenReady() {
        switch manager.authorizationStatus {
        case .notDetermined:
            pendingRequestAfterAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            pendingRequestAfterAuthorization = false
            manager.requestLocation()
        case .denied, .restricted:
            finish(address: nil, snapshot: nil)
        @unknown default:
            finish(address: nil, snapshot: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else {
            finish(address: nil, snapshot: nil)
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
                self.finish(
                    address: address.isEmpty ? nil : address,
                    snapshot: AttendanceLocationSnapshot(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude,
                        horizontalAccuracy: loc.horizontalAccuracy,
                        address: address.isEmpty ? nil : address
                    )
                )
            } else {
                self.finish(
                    address: nil,
                    snapshot: AttendanceLocationSnapshot(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude,
                        horizontalAccuracy: loc.horizontalAccuracy,
                        address: nil
                    )
                )
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(address: nil, snapshot: nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard pendingRequestAfterAuthorization else { return }
        requestWhenReady()
    }

    private func finish(address: String?, snapshot: AttendanceLocationSnapshot?) {
        pendingRequestAfterAuthorization = false
        completion?(address)
        completion = nil
        locationCompletion?(snapshot)
        locationCompletion = nil
    }
}

final class AttendanceLocationBackfillCoordinator {
    static let shared = AttendanceLocationBackfillCoordinator()

    private final class Request {
        let provider = LocationAddressProvider()
        var snapshot: AttendanceLocationSnapshot?
        var didFinish = false
        var callbacks: [(AttendanceLocationSnapshot?) -> Void] = []
    }

    private var requests: [UUID: Request] = [:]

    private init() {}

    @discardableResult
    func begin(onUpdate: ((AttendanceLocationSnapshot?) -> Void)? = nil) -> UUID {
        let id = UUID()
        let request = Request()
        if let onUpdate {
            request.callbacks.append(onUpdate)
        }
        requests[id] = request

        request.provider.getCurrentLocation { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self, let request = self.requests[id] else { return }
                request.snapshot = snapshot
                request.didFinish = true
                let callbacks = request.callbacks
                request.callbacks = []
                callbacks.forEach { $0(snapshot) }
            }
        }

        return id
    }

    func observe(_ id: UUID?, completion: @escaping (AttendanceLocationSnapshot?) -> Void) {
        guard let id, let request = requests[id] else {
            completion(nil)
            return
        }
        if request.didFinish {
            completion(request.snapshot)
        } else {
            request.callbacks.append(completion)
        }
    }

    func finish(_ id: UUID?) {
        guard let id else { return }
        requests.removeValue(forKey: id)
    }
}
