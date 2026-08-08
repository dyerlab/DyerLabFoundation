//
//  Camera2D.swift
//  DyerLabFoundation
//
//  2D camera for graph layout rendering with pan and zoom.
//

import Matrix
import Foundation
import simd
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 2D camera state for pan and zoom transformations.
public struct Camera2D {
    /// Zoom scale factor (0.1 to 5.0).
    public var zoom: Float = 1.0

    /// Pan offset in view units.
    public var pan: SIMD2<Float> = .zero

    /// Creates a camera with default settings.
    public init() {}

    /// Creates a camera with specific zoom and pan.
    ///
    /// - Parameters:
    ///   - zoom: Initial zoom factor
    ///   - pan: Initial pan offset
    public init(zoom: Float, pan: SIMD2<Float>) {
        self.zoom = zoom
        self.pan = pan
    }
}

// MARK: - Transform Functions

/// Transforms a world-space point to view-space coordinates.
///
/// Transform pipeline:
/// 1. Project 3D → 2D (ignore z)
/// 2. Apply zoom
/// 3. Apply pan
/// 4. Translate to canvas center
///
/// - Parameters:
///   - worldPoint: Position in world space
///   - canvasSize: Size of the canvas
///   - camera: Camera state
/// - Returns: View-space coordinate
public func worldToView(worldPoint: SIMD3<Float>, canvasSize: CGSize, camera: Camera2D) -> CGPoint {
    // 1. Project 3D → 2D (ignore z)
    let x = worldPoint.x
    let y = worldPoint.y

    // 2. Apply zoom
    let scaled = SIMD2<Float>(x, y) * camera.zoom

    // 3. Apply pan
    let panned = scaled + camera.pan

    // 4. Translate to canvas center
    let centerX = Float(canvasSize.width) / 2.0
    let centerY = Float(canvasSize.height) / 2.0
    let viewX = panned.x + centerX
    let viewY = panned.y + centerY

    return CGPoint(x: Double(viewX), y: Double(viewY))
}

/// Transforms a view-space point to world-space coordinates.
///
/// Inverse transform pipeline:
/// 1. Untranslate from canvas center
/// 2. Unapply pan
/// 3. Unapply zoom
/// 4. Return as 3D point with z=0
///
/// - Parameters:
///   - viewPoint: Position in view space
///   - canvasSize: Size of the canvas
///   - camera: Camera state
/// - Returns: World-space coordinate (z=0)
public func viewToWorld(viewPoint: CGPoint, canvasSize: CGSize, camera: Camera2D) -> SIMD3<Float> {
    let centerX = Float(canvasSize.width) / 2.0
    let centerY = Float(canvasSize.height) / 2.0

    // 1. Untranslate from canvas center
    var x = Float(viewPoint.x) - centerX
    var y = Float(viewPoint.y) - centerY

    // 2. Unapply pan
    x -= camera.pan.x
    y -= camera.pan.y

    // 3. Unapply zoom
    x /= camera.zoom
    y /= camera.zoom

    return SIMD3<Float>(x, y, 0)  // z=0 for 2D
}

// MARK: - Hit Testing

/// Finds the index of the node under the cursor.
///
/// - Parameters:
///   - viewPoint: Cursor position in view space
///   - state: Layout state
///   - camera: Camera state
///   - canvasSize: Size of the canvas
/// - Returns: Node index if hit, nil otherwise
public func hitTest(viewPoint: CGPoint, state: LayoutState, camera: Camera2D, canvasSize: CGSize) -> Int? {
    let worldPoint = viewToWorld(viewPoint: viewPoint, canvasSize: canvasSize, camera: camera)

    for i in 0..<state.nodeCount {
        let delta = worldPoint - state.positions[i]
        let distance = simd_length(delta)
        if distance <= state.radii[i] {
            return i
        }
    }
    return nil
}

// MARK: - Fit to View

/// Computes camera settings to fit all nodes in view.
///
/// - Parameters:
///   - state: Layout state
///   - canvasSize: Size of the canvas
///   - margin: Margin factor (default: 0.9 = 10% padding)
/// - Returns: Camera settings that fit all nodes
public func fitToView(state: LayoutState, canvasSize: CGSize, margin: Float = 0.9) -> Camera2D {
    guard state.nodeCount > 0 else { return Camera2D() }

    // Compute bounding box in world space
    var minX: Float = .infinity
    var maxX: Float = -.infinity
    var minY: Float = .infinity
    var maxY: Float = -.infinity

    for pos in state.positions {
        minX = min(minX, pos.x)
        maxX = max(maxX, pos.x)
        minY = min(minY, pos.y)
        maxY = max(maxY, pos.y)
    }

    // Handle degenerate case (all nodes at same position)
    if minX == maxX { minX -= 100; maxX += 100 }
    if minY == maxY { minY -= 100; maxY += 100 }

    let worldWidth = maxX - minX
    let worldHeight = maxY - minY
    let centerX = (minX + maxX) / 2.0
    let centerY = (minY + maxY) / 2.0

    // Compute zoom to fit (with margin)
    let viewWidth = Float(canvasSize.width) * margin
    let viewHeight = Float(canvasSize.height) * margin
    let zoomX = viewWidth / worldWidth
    let zoomY = viewHeight / worldHeight
    let zoom = min(zoomX, zoomY, 5.0)  // Cap at max zoom

    // Compute pan to center
    let pan = SIMD2<Float>(-centerX * zoom, -centerY * zoom)

    return Camera2D(zoom: zoom, pan: pan)
}
