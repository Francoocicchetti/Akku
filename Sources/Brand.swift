import AppKit

enum BrandAssets {
    static let logo: NSImage = {
        guard let url = Bundle.main.url(forResource: "AkkuLogo", withExtension: "png"), let image = NSImage(contentsOf: url) else { return NSImage() }
        return image
    }()
}
