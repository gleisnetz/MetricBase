import SwiftUI
import CoreLocation
import CoreMotion

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var speed: Double = 0.0
    @Published var altitude: Double = 0.0
    @Published var heading: Double = 0.0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        self.location = location
        self.speed = max(location.speed, 0) * 3.6 // m/s zu km/h
        self.altitude = location.altitude
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.heading = newHeading.magneticHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        }
    }
}

// MARK: - Motion Manager
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var pitch: Double = 0.0  // Neigung vorne/hinten
    @Published var roll: Double = 0.0   // Neigung links/rechts
    @Published var yaw: Double = 0.0    // Rotation um vertikale Achse
    @Published var isActive: Bool = false
    
    init() {
        startDeviceMotionUpdates()
    }
    
    func startDeviceMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let motion = motion else { return }
            
            self?.pitch = motion.attitude.pitch * 180 / .pi
            self?.roll = motion.attitude.roll * 180 / .pi
            self?.yaw = motion.attitude.yaw * 180 / .pi
            self?.isActive = true
        }
    }
    
    func stopDeviceMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        isActive = false
    }
}

// MARK: - Main App View
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var motionManager = MotionManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Status Header
                    StatusHeaderView(
                        locationAuth: locationManager.authorizationStatus,
                        motionActive: motionManager.isActive
                    )
                    
                    // Sensor Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 15) {
                        SensorCard(
                            title: "Geschwindigkeit",
                            value: String(format: "%.1f", locationManager.speed),
                            unit: "km/h",
                            icon: "speedometer",
                            color: .blue
                        )
                        
                        SensorCard(
                            title: "Höhe",
                            value: String(format: "%.0f", locationManager.altitude),
                            unit: "m",
                            icon: "mountain.2",
                            color: .green
                        )
                    }
                    
                    // Kompass
                    CompassView(heading: locationManager.heading)
                    
                    // Neigung
                    InclinationView(
                        pitch: motionManager.pitch,
                        roll: motionManager.roll
                    )
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Sensor Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            locationManager.startUpdatingLocation()
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
            motionManager.stopDeviceMotionUpdates()
        }
    }
}

// MARK: - Status Header View
struct StatusHeaderView: View {
    let locationAuth: CLAuthorizationStatus
    let motionActive: Bool
    
    var body: some View {
        HStack {
            StatusIndicator(
                title: "GPS",
                isActive: locationAuth == .authorizedWhenInUse || locationAuth == .authorizedAlways,
                icon: "location"
            )
            
            Spacer()
            
            StatusIndicator(
                title: "Motion",
                isActive: motionActive,
                icon: "gyroscope"
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusIndicator: View {
    let title: String
    let isActive: Bool
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isActive ? .green : .red)
            Text(title)
                .font(.caption)
                .foregroundColor(isActive ? .green : .red)
        }
    }
}

// MARK: - Sensor Card
struct SensorCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Compass View
struct CompassView: View {
    let heading: Double
    
    var body: some View {
        VStack {
            Text("Kompass")
                .font(.headline)
                .padding(.bottom, 8)
            
            ZStack {
                // Compass Ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 140, height: 140)
                
                // Cardinal Directions
                ForEach(0..<4) { i in
                    let angle = Double(i) * 90
                    let direction = ["N", "E", "S", "W"][i]
                    let color: Color = i == 0 ? .red : .primary
                    
                    Text(direction)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                        .rotationEffect(.degrees(-angle))
                        .offset(y: -60)
                        .rotationEffect(.degrees(angle))
                }
                
                // Compass Needle
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 55)
                    .offset(y: -27)
                    .rotationEffect(.degrees(heading))
                
                // Center Circle
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
            
            Text("\(Int(heading))°")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Inclination View
struct InclinationView: View {
    let pitch: Double
    let roll: Double
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Neigung")
                .font(.headline)
            
            // Pitch (Vorne/Hinten)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Längs")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(pitch))°")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(
                                width: abs(pitch) / 90 * geometry.size.width,
                                height: 8
                            )
                            .cornerRadius(4)
                            .offset(x: pitch < 0 ? geometry.size.width - abs(pitch) / 90 * geometry.size.width : 0)
                    }
                }
                .frame(height: 8)
            }
            
            // Roll (Links/Rechts)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quer")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(roll))°")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(Color.orange)
                            .frame(
                                width: abs(roll) / 90 * geometry.size.width,
                                height: 8
                            )
                            .cornerRadius(4)
                            .offset(x: roll < 0 ? geometry.size.width - abs(roll) / 90 * geometry.size.width : 0)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - App Entry Point
@main
struct SensorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

