import AppKit
import SwiftUI

/// Renders the custom chezmoi menu bar icon programmatically from SVG path data.
///
/// Produces `NSImage` instances suitable for use in `MenuBarExtra`. All images are
/// created as template images so macOS automatically handles light/dark appearance.
/// State badges (drift, error, offline) are composited as small overlays on the
/// base icon.
enum MenuBarIconRenderer {

    /// The canonical size for a menu bar icon (points).
    private static let iconSize = NSSize(width: 18, height: 18)

    /// The original SVG viewBox size used for coordinate scaling.
    private static let svgViewBox = CGSize(width: 22, height: 22)

    /// Cache for rendered icons keyed by badge type (nil = base icon).
    /// Badge combinations are finite (7 variants), so caching avoids redundant rendering.
    /// Access is safe because icon rendering only occurs on the main thread (UI layer).
    private nonisolated(unsafe) static var iconCache: [String: NSImage] = [:]

    /// Returns a cache key string for the given badge type.
    /// - Parameter badge: The badge type, or `nil` for the base icon.
    /// - Returns: A unique string key.
    private static func cacheKey(for badge: Badge?) -> String {
        guard let badge = badge else { return "base" }
        return String(describing: badge)
    } // End of func cacheKey(for:)

    // MARK: - Public API

    /// Creates the base chezmoi menu bar icon with no badge overlay.
    /// - Returns: A template `NSImage` sized for the menu bar.
    static func baseIcon() -> NSImage {
        return renderIcon(badge: nil)
    } // End of func baseIcon()

    /// Creates a menu bar icon with the appropriate badge for the given state.
    /// - Parameters:
    ///   - overallState: The worst sync state across all files.
    ///   - refreshState: The current refresh operation state.
    ///   - isOnline: Whether the network is currently reachable.
    /// - Returns: A template `NSImage` with the appropriate badge overlay.
    static func icon(
        for overallState: FileSyncState,
        refreshState: RefreshState,
        isOnline: Bool = true
    ) -> NSImage {
        if !isOnline {
            return renderIcon(badge: .offline)
        }

        if case .running = refreshState {
            return renderIcon(badge: .refreshing)
        }

        switch overallState {
        case .clean:
            return renderIcon(badge: nil)
        case .localDrift:
            return renderIcon(badge: .localDrift)
        case .remoteDrift:
            return renderIcon(badge: .remoteDrift)
        case .dualDrift:
            return renderIcon(badge: .dualDrift)
        case .error:
            return renderIcon(badge: .error)
        }
    } // End of func icon(for:refreshState:isOnline:)

    // MARK: - Badge types

    /// The types of badge overlays that can be composited onto the base icon.
    private enum Badge {
        case localDrift
        case remoteDrift
        case dualDrift
        case error
        case refreshing
        case offline
    } // End of enum Badge

    // MARK: - Rendering

    /// Renders the full icon by drawing the base chezmoi shape and an optional badge.
    /// Returns a cached image if available to avoid redundant rendering.
    /// - Parameter badge: The badge type to overlay, or `nil` for the plain icon.
    /// - Returns: A template `NSImage` at the canonical menu bar size.
    private static func renderIcon(badge: Badge?) -> NSImage {
        let key = cacheKey(for: badge)
        if let cached = iconCache[key] {
            return cached
        }

        let size = iconSize
        let image = NSImage(size: size, flipped: false) { rect in
            // Draw base chezmoi icon
            drawBaseIcon(in: rect)

            // Draw badge overlay if needed
            if let badge = badge {
                drawBadge(badge, in: rect)
            }

            return true
        } // End of NSImage drawing closure

        image.isTemplate = true
        iconCache[key] = image
        return image
    } // End of func renderIcon(badge:)

    /// Draws the base chezmoi icon (circle with sync arrow + house) scaled to fit the given rect.
    ///
    /// The icon is derived from the SVG paths in `icono-chezmoi-menubar.svg`:
    /// - Path 1: Open circle with sync arrow tail (stroke)
    /// - Path 2: Arrow head (stroke)
    /// - Path 3: House shape (fill)
    /// - Parameter rect: The bounding rectangle to draw into.
    private static func drawBaseIcon(in rect: NSRect) {
        let scaleX = rect.width / svgViewBox.width
        let scaleY = rect.height / svgViewBox.height

        let transform = NSAffineTransform()
        transform.scaleX(by: scaleX, yBy: scaleY)

        NSColor.black.setStroke()
        NSColor.black.setFill()

        // Path 1: Open circle with sync arrow tail
        let circlePath = NSBezierPath()
        // M18.5 11C18.5 6.858 15.142 3.5 11 3.5C6.858 3.5 3.5 6.858 3.5 11
        // C3.5 15.142 6.858 18.5 11 18.5C12.7 18.5 14.2 17.9 15.4 17
        circlePath.move(to: NSPoint(x: 18.5, y: 11))
        circlePath.curve(
            to: NSPoint(x: 11, y: 3.5),
            controlPoint1: NSPoint(x: 18.5, y: 6.858),
            controlPoint2: NSPoint(x: 15.142, y: 3.5)
        )
        circlePath.curve(
            to: NSPoint(x: 3.5, y: 11),
            controlPoint1: NSPoint(x: 6.858, y: 3.5),
            controlPoint2: NSPoint(x: 3.5, y: 6.858)
        )
        circlePath.curve(
            to: NSPoint(x: 11, y: 18.5),
            controlPoint1: NSPoint(x: 3.5, y: 15.142),
            controlPoint2: NSPoint(x: 6.858, y: 18.5)
        )
        circlePath.curve(
            to: NSPoint(x: 15.4, y: 17),
            controlPoint1: NSPoint(x: 12.7, y: 18.5),
            controlPoint2: NSPoint(x: 14.2, y: 17.9)
        )

        // Flip Y coordinates (SVG is top-down, NSImage draw rect is bottom-up)
        let flipTransform = NSAffineTransform()
        flipTransform.translateX(by: 0, yBy: svgViewBox.height)
        flipTransform.scaleX(by: 1, yBy: -1)

        let combinedTransform = NSAffineTransform()
        combinedTransform.append(flipTransform as AffineTransform)
        combinedTransform.append(transform as AffineTransform)

        let transformedCircle = combinedTransform.transform(circlePath)
        transformedCircle.lineWidth = 2.0 * scaleX
        transformedCircle.lineCapStyle = .round
        transformedCircle.stroke()

        // Path 2: Arrow head — M14.5 19L16 17L14 15.5
        let arrowPath = NSBezierPath()
        arrowPath.move(to: NSPoint(x: 14.5, y: 19))
        arrowPath.line(to: NSPoint(x: 16, y: 17))
        arrowPath.line(to: NSPoint(x: 14, y: 15.5))

        let transformedArrow = combinedTransform.transform(arrowPath)
        transformedArrow.lineWidth = 2.0 * scaleX
        transformedArrow.lineCapStyle = .round
        transformedArrow.lineJoinStyle = .round
        transformedArrow.stroke()

        // Path 3: House shape (filled)
        // m 10.894 6.019 l -4.0 3.5 V 14.019 H 14.894 V 9.519 Z
        let housePath = NSBezierPath()
        housePath.move(to: NSPoint(x: 10.894, y: 6.019))
        housePath.line(to: NSPoint(x: 6.894, y: 9.519))
        housePath.line(to: NSPoint(x: 6.894, y: 14.019))
        housePath.line(to: NSPoint(x: 14.894, y: 14.019))
        housePath.line(to: NSPoint(x: 14.894, y: 9.519))
        housePath.close()

        let transformedHouse = combinedTransform.transform(housePath)
        transformedHouse.fill()
    } // End of func drawBaseIcon(in:)

    /// Draws a small badge indicator in the bottom-right corner of the icon.
    /// - Parameters:
    ///   - badge: The badge type to draw.
    ///   - rect: The bounding rectangle of the full icon.
    private static func drawBadge(_ badge: Badge, in rect: NSRect) {
        let badgeSize: CGFloat = 7
        let badgeOrigin = NSPoint(
            x: rect.maxX - badgeSize - 0.5,
            y: 0.5
        )
        let badgeRect = NSRect(origin: badgeOrigin, size: NSSize(width: badgeSize, height: badgeSize))

        switch badge {
        case .localDrift:
            // Small up arrow
            drawArrowBadge(in: badgeRect, pointingUp: true)
        case .remoteDrift:
            // Small down arrow
            drawArrowBadge(in: badgeRect, pointingUp: false)
        case .dualDrift:
            // Small warning triangle
            drawTriangleBadge(in: badgeRect)
        case .error:
            // Small X mark
            drawXBadge(in: badgeRect)
        case .refreshing:
            // Small circular arrows
            drawRefreshBadge(in: badgeRect)
        case .offline:
            // Small slash circle
            drawOfflineBadge(in: badgeRect)
        }
    } // End of func drawBadge(_:in:)

    /// Draws a small arrow badge pointing up or down.
    /// - Parameters:
    ///   - rect: The badge bounding rect.
    ///   - pointingUp: If `true`, arrow points up; otherwise, down.
    private static func drawArrowBadge(in rect: NSRect, pointingUp: Bool) {
        let path = NSBezierPath()
        let midX = rect.midX
        if pointingUp {
            path.move(to: NSPoint(x: midX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.minX, y: rect.minY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        } else {
            path.move(to: NSPoint(x: midX, y: rect.minY))
            path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        }
        path.close()
        NSColor.black.setFill()
        path.fill()
    } // End of func drawArrowBadge(in:pointingUp:)

    /// Draws a small warning triangle badge.
    ///
    /// Uses destination-out compositing to cut a transparent exclamation line,
    /// since template images only use alpha — color differences are discarded.
    /// - Parameter rect: The badge bounding rect.
    private static func drawTriangleBadge(in rect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.midX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        path.close()
        NSColor.black.setFill()
        path.fill()

        // Punch a transparent exclamation line inside the triangle
        let exclPath = NSBezierPath()
        exclPath.move(to: NSPoint(x: rect.midX, y: rect.maxY - 2))
        exclPath.line(to: NSPoint(x: rect.midX, y: rect.minY + 2.5))
        exclPath.lineWidth = 1.0
        exclPath.lineCapStyle = .round

        let savedOp = NSGraphicsContext.current?.compositingOperation
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSColor.black.setStroke()
        exclPath.stroke()
        NSGraphicsContext.current?.compositingOperation = savedOp ?? .sourceOver
    } // End of func drawTriangleBadge(in:)

    /// Draws a small X mark badge.
    /// - Parameter rect: The badge bounding rect.
    private static func drawXBadge(in rect: NSRect) {
        let inset = rect.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: inset.minX, y: inset.minY))
        path.line(to: NSPoint(x: inset.maxX, y: inset.maxY))
        path.move(to: NSPoint(x: inset.maxX, y: inset.minY))
        path.line(to: NSPoint(x: inset.minX, y: inset.maxY))
        NSColor.black.setStroke()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.stroke()
    } // End of func drawXBadge(in:)

    /// Draws a small circular arrows badge indicating a refresh.
    /// - Parameter rect: The badge bounding rect.
    private static func drawRefreshBadge(in rect: NSRect) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2 - 1

        // Draw a partial arc
        let path = NSBezierPath()
        path.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 270,
            clockwise: false
        )
        NSColor.black.setStroke()
        path.lineWidth = 1.2
        path.stroke()

        // Small arrowhead at the end of the arc
        let arrowTip = NSPoint(
            x: center.x,
            y: center.y + radius
        )
        let arrowPath = NSBezierPath()
        arrowPath.move(to: NSPoint(x: arrowTip.x - 2, y: arrowTip.y))
        arrowPath.line(to: arrowTip)
        arrowPath.line(to: NSPoint(x: arrowTip.x, y: arrowTip.y - 2))
        NSColor.black.setStroke()
        arrowPath.lineWidth = 1.2
        arrowPath.lineCapStyle = .round
        arrowPath.stroke()
    } // End of func drawRefreshBadge(in:)

    /// Draws a small slash-circle badge indicating offline state.
    /// - Parameter rect: The badge bounding rect.
    private static func drawOfflineBadge(in rect: NSRect) {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2 - 0.5

        // Circle
        let circlePath = NSBezierPath(
            ovalIn: NSRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
        NSColor.black.setStroke()
        circlePath.lineWidth = 1.2
        circlePath.stroke()

        // Diagonal slash
        let slashPath = NSBezierPath()
        let offset = radius * 0.6
        slashPath.move(to: NSPoint(x: center.x - offset, y: center.y + offset))
        slashPath.line(to: NSPoint(x: center.x + offset, y: center.y - offset))
        slashPath.lineWidth = 1.2
        slashPath.lineCapStyle = .round
        slashPath.stroke()
    } // End of func drawOfflineBadge(in:)
} // End of enum MenuBarIconRenderer
