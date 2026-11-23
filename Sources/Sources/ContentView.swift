import SwiftUI
import Combine

class NetworkSpeedMonitor: ObservableObject {
    @Published var downloadSpeed: String = "0.0 KB/s"
    @Published var uploadSpeed: String = "0.0 KB/s"
    
    private var timer: Timer?
    private var previousRxBytes: UInt64 = 0
    private var previousTxBytes: UInt64 = 0
    
    func startMonitoring() {
        let initial = getNetworkBytes()
        previousRxBytes = initial.rx
        previousTxBytes = initial.tx
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSpeed()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateSpeed() {
        let current = getNetworkBytes()
        let rxDiff = current.rx >= previousRxBytes ? current.rx - previousRxBytes : 0
        let txDiff = current.tx >= previousTxBytes ? current.tx - previousTxBytes : 0
        
        previousRxBytes = current.rx
        previousTxBytes = current.tx
        
        DispatchQueue.main.async {
            self.downloadSpeed = self.formatSpeed(bytesPerSec: rxDiff)
            self.uploadSpeed = self.formatSpeed(bytesPerSec: txDiff)
        }
    }
    
    private func getNetworkBytes() -> (rx: UInt64, tx: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        var totalRx: UInt64 = 0
        var totalTx: UInt64 = 0
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let name = String(cString: interface.ifa_name)
            if name == "en0" || name.hasPrefix("pdp_ip") {
                if let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    totalRx += UInt64(data.pointee.ifi_ibytes)
                    totalTx += UInt64(data.pointee.ifi_obytes)
                }
            }
        }
        return (totalRx, totalTx)
    }
    
    private func formatSpeed(bytesPerSec: UInt64) -> String {
        let kb = Double(bytesPerSec) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB/s", kb)
        } else {
            return String(format: "%.2f MB/s", kb / 1024.0)
        }
    }
}

struct ContentView: View {
    @StateObject private var monitor = NetworkSpeedMonitor()
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Tốc độ mạng Real-time")
                .font(.title2.bold())
            
            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("↓ Tải xuống")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(monitor.downloadSpeed)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 40)
                
                VStack(spacing: 8) {
                    Text("↑ Tải lên")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(monitor.uploadSpeed)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            monitor.startMonitoring()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            monitor.stopMonitoring()
        }
    }
}
