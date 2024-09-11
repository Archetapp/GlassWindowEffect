//
//  GlassWindowEffect.swift
//  GlassWindowEffect
//
//  Created by Jared Davidson on 9/11/24.
//

import Foundation
import SwiftUI
import ARKit
import RealityKit

class ARLightDetector: NSObject, ObservableObject {
    @Published var lightPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)  // Default to center
    @Published var isReady: Bool = false
    @Published var trackingState: String = "Initializing"
    
    private var session: ARSession?
    private let queue = DispatchQueue(label: "com.lightdetector.queue")
    private var lastValidPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    
    override init() {
        super.init()
        setupARSession()
    }
    
    private func setupARSession() {
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true

        session = ARSession()
        session?.delegate = self
        session?.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    private func detectLightSource(in frame: ARFrame) {
        guard isReady else { return }

        if let lightEstimate = frame.lightEstimate {
            if let directionalEstimate = lightEstimate as? ARDirectionalLightEstimate {
                let direction = directionalEstimate.primaryLightDirection
                let mirroredX = 1.0 - CGFloat(direction.x * 0.5 + 0.5)
                let position = CGPoint(x: mirroredX, y: CGFloat(-direction.z * 0.5 + 0.5))
                
                lastValidPosition = position
                DispatchQueue.main.async { self.lightPosition = position }
            } else {
                let intensity = lightEstimate.ambientIntensity / 1000.0
                let position = CGPoint(x: 0.5, y: 1.0 - intensity)
                
                lastValidPosition = position
                DispatchQueue.main.async { self.lightPosition = position }
            }
        }
    }
}

extension ARLightDetector: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        queue.async {
            self.detectLightSource(in: frame)
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            switch camera.trackingState {
            case .normal:
                self.trackingState = "Normal"
                self.isReady = true
            case .limited(.initializing):
                self.trackingState = "Initializing"
                self.isReady = false
            case .limited(.excessiveMotion):
                self.trackingState = "Excessive Motion"
            case .limited(.insufficientFeatures):
                self.trackingState = "Insufficient Features"
            case .limited(_):
                self.trackingState = "Limited"
            case .notAvailable:
                self.trackingState = "Not Available"
            @unknown default:
                self.trackingState = "Unknown"
            }
            
            if camera.trackingState != .normal {
                self.lightPosition = self.lastValidPosition
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.trackingState = "Session Failed"
            self.isReady = false
        }
    }
}

struct GlassWindowView: View {
    @StateObject private var lightDetector = ARLightDetector()
    @State private var viewSize: CGSize = .zero
    
    var showingBall: Bool = false
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Material.ultraThin)
                        .overlay(
                            GlassEdgeGlow(lightPosition: clampedLightPosition)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    
                    RoundedRectangle(cornerRadius: 19)
                        .fill(Material.regular)
                        .padding(1)
                    if showingBall {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 30, height: 30)
                            .position(clampedLightPosition)
                            .animation(.easeInOut(duration: 0.5), value: clampedLightPosition)
                    }
                }
                .onAppear { viewSize = geometry.size }
                .onChange(of: geometry.size) { _, newSize in
                    viewSize = newSize
                }
            }
        }
    }
    
    private var clampedLightPosition: CGPoint {
        let ballRadius: CGFloat = 15
        let x = max(ballRadius, min(lightDetector.lightPosition.x * viewSize.width, viewSize.width - ballRadius))
        let y = max(ballRadius, min(lightDetector.lightPosition.y * viewSize.height, viewSize.height - ballRadius))
        return CGPoint(x: x, y: y)
    }
}

struct GlassEdgeGlow: View {
    let lightPosition: CGPoint
    
    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let glowWidth: CGFloat = 10
            
            ContinuousEdgePath(rect: rect, glowWidth: glowWidth)
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.1),
                            .white.opacity(0.3),
                            .white.opacity(1.0),
                            .white.opacity(0.3),
                            .white.opacity(0.1),
                            .clear
                        ]),
                        center: .center,
                        angle: .degrees(angleToCenterFromLightSource(in: rect))
                    )
                )
                .blur(radius: 3)
        }
    }
    
    func angleToCenterFromLightSource(in rect: CGRect) -> Double {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return atan2(center.y - lightPosition.y, center.x - lightPosition.x) * (180 / Double.pi)
    }
}

struct ContinuousEdgePath: Shape {
    let rect: CGRect
    let glowWidth: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let innerRect = rect.insetBy(dx: glowWidth, dy: glowWidth)
        
        path.addRect(rect)
        path.addRect(innerRect)
        
        return path
    }
}
