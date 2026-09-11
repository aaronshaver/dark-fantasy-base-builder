import UIKit

/// Fixed-size pixel previews wrap within the available width; the enclosing screen owns scrolling.
final class ArtworkGridView: UIView {
    private var tiles: [ArtworkTileView] = []
    private let tileSize = CGSize(width: 68, height: 94)
    private let spacing: CGFloat = 4
    private var previousWidth: CGFloat = 0

    func show(_ frames: [(name: String, image: UIImage)]) {
        tiles.forEach { $0.removeFromSuperview() }
        tiles = frames.map { ArtworkTileView(name: $0.name, image: $0.image) }
        tiles.forEach(addSubview)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        let columns = max(1, Int((max(bounds.width, tileSize.width) + spacing) / (tileSize.width + spacing)))
        let rows = (tiles.count + columns - 1) / columns
        let height = rows == 0 ? 0 : CGFloat(rows) * (tileSize.height + spacing) - spacing
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if previousWidth != bounds.width {
            previousWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
        let columns = max(1, Int((bounds.width + spacing) / (tileSize.width + spacing)))
        for (index, tile) in tiles.enumerated() {
            tile.frame = CGRect(x: CGFloat(index % columns) * (tileSize.width + spacing),
                                y: CGFloat(index / columns) * (tileSize.height + spacing),
                                width: tileSize.width, height: tileSize.height)
        }
    }
}

private final class ArtworkTileView: UIView {
    private let imageView: UIImageView
    private let caption = UILabel()
    private let imageRect = CGRect(x: 2, y: 2, width: 64, height: 64)

    init(name: String, image: UIImage) {
        imageView = UIImageView(image: image)
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        imageView.contentMode = .scaleToFill
        imageView.layer.magnificationFilter = .nearest
        imageView.layer.minificationFilter = .nearest
        imageView.frame = imageRect
        addSubview(imageView)
        caption.text = name.replacingOccurrences(of: "_", with: " ")
        caption.font = .systemFont(ofSize: 10)
        caption.textColor = .secondaryLabel
        caption.textAlignment = .center
        caption.numberOfLines = 2
        caption.frame = CGRect(x: 0, y: 70, width: 68, height: 24)
        addSubview(caption)
        isAccessibilityElement = true
        accessibilityLabel = caption.text
        accessibilityTraits = .image
    }

    required init?(coder: NSCoder) { fatalError("Programmatic artwork tile") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        // The one-point black/white dots are wholly outside the artwork, with a one-point gap.
        context.setShouldAntialias(false)
        let border = imageRect.insetBy(dx: -2, dy: -2)
        for x in stride(from: border.minX, to: border.maxX, by: 1) {
            context.setFillColor((Int(x - border.minX) % 2 == 0 ? UIColor.white : UIColor.black).cgColor)
            context.fill(CGRect(x: x, y: border.minY, width: 1, height: 1))
            context.fill(CGRect(x: x, y: border.maxY - 1, width: 1, height: 1))
        }
        for y in stride(from: border.minY + 1, to: border.maxY - 1, by: 1) {
            context.setFillColor((Int(y - border.minY) % 2 == 0 ? UIColor.white : UIColor.black).cgColor)
            context.fill(CGRect(x: border.minX, y: y, width: 1, height: 1))
            context.fill(CGRect(x: border.maxX - 1, y: y, width: 1, height: 1))
        }
    }
}
