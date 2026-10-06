// LocationManager.swift
import CoreLocation
import CoreMotion
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var authorized = false

    private let clManager = CLLocationManager()
    private let motionManager = CMMotionManager()

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestAndStart() {
        clManager.requestWhenInUseAuthorization()
        clManager.startUpdatingLocation()
        clManager.startUpdatingHeading()
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        location = locs.last
    }

    func locationManager(_ m: CLLocationManager, didUpdateHeading h: CLHeading) {
        heading = h
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        authorized = m.authorizationStatus == .authorizedWhenInUse
                  || m.authorizationStatus == .authorizedAlways
    }

    func compassDirection(from degrees: Double) -> String {
        let dirs = ["С","СВ","В","ЮВ","Ю","ЮЗ","З","СЗ"]
        let idx = Int((degrees + 22.5) / 45) % 8
        return dirs[idx]
    }
}
