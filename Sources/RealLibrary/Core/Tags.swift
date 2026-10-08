/// Controlled tag vocabulary. Tests reject tags outside it, so `realityhd list <tag>` and
/// `Catalog.ids(tag:)` stay useful as the library grows. Add a tag here in the same PR that first uses it.
public enum AssetTag {
    /// `tags[0]` of every asset. Also picks the source folder: Nature/, Props/, Structures/.
    public static let kinds: [String] = ["nature", "prop", "structure"]

    public static let vocabulary: Set<String> = Set(kinds).union([
        // nature
        "tree", "deciduous", "conifer", "palm", "foliage", "flower", "grass", "rock", "ground", "terrain", "water",
        "plant", "fungus",
        // material families
        "wood", "metal", "concrete", "stone", "brick", "plastic", "glass", "ceramic", "fabric", "paper", "rubber",
        // settings
        "urban", "street", "road", "park", "outdoor", "interior", "kitchen", "office", "garden", "farm", "camp",
        "beach", "desert", "snow", "harbor", "rail", "construction", "industrial", "playground", "sports",
        // function
        "container", "furniture", "light", "sign", "barrier", "fence", "wall", "vehicle", "tool", "food", "decor",
        // RealityHD 3
        "leather", "workshop", "travel", "antique",
        // RealityHD 4
        "door", "window", "electronics", "book", "building", "articulated",
        // RealityHD 5: hospital interiors; `handheld` assets are grabbable by default
        "medical", "surgical", "hospital", "handheld",
        // ceiling-mounted: authored in place below a ceiling at y = mount height; y = 0 is the floor under it
        "ceiling",
        // RealityHD 6: kitchen and cooking
        "appliance", "cookware",
        // landscaping: yard props, hardscape, planting
        "landscaping",
        // architecture: facade openings and building elements sized per bay by building generators
        "architecture", "facade", "roof",
    ])

    /// Scene tags: any vocabulary tag plus these.
    public static let sceneExtras: Set<String> = ["forest", "test", "showcase"]
}
