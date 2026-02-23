//
//  GraphCanvasView.swift
//  StrataFoundry
//
//  Force-directed graph visualization using Canvas with pan/zoom.
//

import SwiftUI

struct GraphCanvasNode: Identifiable {
    let id: String
    let label: String?
}

struct GraphCanvasEdge: Identifiable {
    let id: String
    let source: String
    let target: String
    let edgeType: String
}

struct GraphCanvasView: View {
    let nodes: [GraphCanvasNode]
    let edges: [GraphCanvasEdge]
    let selectedNodeId: String?
    let onNodeTap: ((String) -> Void)?

    @State private var positions: [String: CGPoint] = [:]
    @State private var velocities: [String: CGVector] = [:]
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var isSimulating = true
    @State private var timer: Timer?

    private let nodeRadius: CGFloat = 18
    private let damping: CGFloat = 0.9
    private let repulsionStrength: CGFloat = 5000
    private let springLength: CGFloat = 100
    private let springStrength: CGFloat = 0.02
    private let centerGravity: CGFloat = 0.01
    private let energyThreshold: CGFloat = 0.5

    // Deterministic color palette for edge types
    private static let edgeColors: [Color] = [
        .blue, .purple, .orange, .green, .pink, .cyan, .indigo, .mint, .teal, .red
    ]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            Canvas { context, size in
                let transform = CGAffineTransform(translationX: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                    .scaledBy(x: scale, y: scale)
                    .translatedBy(x: center.x / scale, y: center.y / scale)

                // Draw edges
                for edge in edges {
                    guard let srcPos = positions[edge.source],
                          let dstPos = positions[edge.target] else { continue }

                    let src = srcPos.applying(transform)
                    let dst = dstPos.applying(transform)

                    var path = Path()
                    path.move(to: src)
                    path.addLine(to: dst)

                    let edgeColor = Self.edgeColors[abs(edge.edgeType.hashValue) % Self.edgeColors.count]
                    context.stroke(path, with: .color(edgeColor.opacity(0.5)), lineWidth: 1.5)
                }

                // Draw nodes
                for node in nodes {
                    guard let pos = positions[node.id] else { continue }
                    let screenPos = pos.applying(transform)
                    let r = nodeRadius * scale
                    let rect = CGRect(x: screenPos.x - r, y: screenPos.y - r, width: r * 2, height: r * 2)

                    let isSelected = node.id == selectedNodeId
                    let fillColor: Color = isSelected ? .accentColor : .blue

                    context.fill(Circle().path(in: rect), with: .color(fillColor.opacity(0.85)))
                    context.stroke(Circle().path(in: rect), with: .color(.white.opacity(0.6)), lineWidth: isSelected ? 2 : 1)
                }
            }
            .overlay {
                // Text labels for nodes
                ForEach(nodes) { node in
                    if let pos = positions[node.id] {
                        let screenX = (pos.x + center.x / scale) * scale + offset.width + dragOffset.width
                        let screenY = (pos.y + center.y / scale) * scale + offset.height + dragOffset.height

                        Text(node.label ?? node.id)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .fixedSize()
                            .position(x: screenX, y: screenY + nodeRadius * scale + 10)
                            .onTapGesture {
                                onNodeTap?(node.id)
                            }
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                        dragOffset = .zero
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(0.1, min(5.0, value))
                    }
            )
            .onAppear {
                initializePositions()
                startSimulation()
            }
            .onDisappear {
                stopSimulation()
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: StrataRadius.md))
    }

    // MARK: - Simulation

    private func initializePositions() {
        guard positions.isEmpty else { return }
        for (index, node) in nodes.enumerated() {
            let angle = Double(index) / Double(max(nodes.count, 1)) * 2 * .pi
            let radius: Double = 80 + Double(index) * 5
            positions[node.id] = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            velocities[node.id] = .zero
        }
    }

    private func startSimulation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if isSimulating {
                    stepSimulation()
                }
            }
        }
    }

    private func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }

    private func stepSimulation() {
        var forces: [String: CGVector] = [:]
        for node in nodes {
            forces[node.id] = .zero
        }

        // Repulsion between all pairs
        for i in 0..<nodes.count {
            for j in (i + 1)..<nodes.count {
                let nodeA = nodes[i]
                let nodeB = nodes[j]
                guard let posA = positions[nodeA.id],
                      let posB = positions[nodeB.id] else { continue }

                let dx = posA.x - posB.x
                let dy = posA.y - posB.y
                let dist = max(sqrt(dx * dx + dy * dy), 1)
                let force = repulsionStrength / (dist * dist)
                let fx = (dx / dist) * force
                let fy = (dy / dist) * force

                forces[nodeA.id]!.dx += fx
                forces[nodeA.id]!.dy += fy
                forces[nodeB.id]!.dx -= fx
                forces[nodeB.id]!.dy -= fy
            }
        }

        // Spring forces on edges (Hooke's law)
        for edge in edges {
            guard let srcPos = positions[edge.source],
                  let dstPos = positions[edge.target] else { continue }

            let dx = dstPos.x - srcPos.x
            let dy = dstPos.y - srcPos.y
            let dist = max(sqrt(dx * dx + dy * dy), 1)
            let displacement = dist - springLength
            let force = springStrength * displacement
            let fx = (dx / dist) * force
            let fy = (dy / dist) * force

            forces[edge.source]?.dx += fx
            forces[edge.source]?.dy += fy
            forces[edge.target]?.dx -= fx
            forces[edge.target]?.dy -= fy
        }

        // Center gravity
        for node in nodes {
            guard let pos = positions[node.id] else { continue }
            forces[node.id]?.dx -= pos.x * centerGravity
            forces[node.id]?.dy -= pos.y * centerGravity
        }

        // Apply forces
        var totalEnergy: CGFloat = 0
        for node in nodes {
            guard var vel = velocities[node.id],
                  let force = forces[node.id],
                  var pos = positions[node.id] else { continue }

            vel.dx = (vel.dx + force.dx) * damping
            vel.dy = (vel.dy + force.dy) * damping
            pos.x += vel.dx
            pos.y += vel.dy

            velocities[node.id] = vel
            positions[node.id] = pos

            totalEnergy += vel.dx * vel.dx + vel.dy * vel.dy
        }

        if totalEnergy < energyThreshold {
            isSimulating = false
        }
    }
}
