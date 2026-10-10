import RealCore

/// Colors of one bird as sRGB hex. Each region becomes a material colour or a position in a plumage
/// map, see `FaunaMaterials`.
public struct Plumage: Sendable, Hashable {
    /// Crown and upper head.
    public var crown: UInt32
    /// Cheek and ear coverts.
    public var cheek: UInt32
    /// Mask around the bill and eye, or the throat bib, depending on the extents below.
    public var mask: UInt32
    public var back: UInt32
    public var belly: UInt32
    /// Breast patch that fades into the belly.
    public var breast: UInt32
    /// Wing coverts.
    public var wing: UInt32
    /// Flight feathers (primaries and secondaries).
    public var flight: UInt32
    /// Pale edging on flight feathers and covert tips: the wing bars.
    public var wingEdge: UInt32
    public var tail: UInt32
    public var tailEdge: UInt32
    public var beak: UInt32
    public var leg: UInt32
    public var eye: UInt32
    /// Ring of bare skin or pale feathers around the eye. Equal to `cheek` hides it.
    public var eyeRing: UInt32

    /// Fraction of the body length (from the front) the breast patch covers, 0 for none.
    public var breastExtent: Float
    /// Fraction of the half circumference from the back where upperparts end.
    public var flankLine: Float
    /// Dark spots or streaks on the underparts, 0...1.
    public var spotting: Float
    /// Crown boundary on the head, fraction of the half circumference from the crown midline.
    public var crownLine: Float
    /// Throat or chin patch extent along the head, 0 for none.
    public var throatExtent: Float
    /// Face mask extent along the head, 0 for none.
    public var maskExtent: Float
    /// Bar strength on tail and wing feathers, 0...1.
    public var barring: Float
    /// Width of the pale fringe at feather tips, 0...1.
    public var fringe: Float
    /// Rows of body feathers along the body.
    public var featherRows: Float = 30
    /// Metallic sheen on the back (hummingbirds), 0...1.
    public var iridescence: Float = 0

    public init(crown: UInt32, cheek: UInt32, mask: UInt32, back: UInt32, belly: UInt32, breast: UInt32, wing: UInt32,
                flight: UInt32, wingEdge: UInt32, tail: UInt32, tailEdge: UInt32, beak: UInt32, leg: UInt32 = 0x3A332E,
                eye: UInt32 = 0x0C0A09, eyeRing: UInt32? = nil, breastExtent: Float = 0, flankLine: Float = 0.5,
                spotting: Float = 0, crownLine: Float = 0.5, throatExtent: Float = 0, maskExtent: Float = 0,
                barring: Float = 0, fringe: Float = 0.25, featherRows: Float = 30, iridescence: Float = 0) {
        self.crown = crown; self.cheek = cheek; self.mask = mask; self.back = back; self.belly = belly; self.breast = breast
        self.wing = wing; self.flight = flight; self.wingEdge = wingEdge; self.tail = tail; self.tailEdge = tailEdge
        self.beak = beak; self.leg = leg; self.eye = eye; self.eyeRing = eyeRing ?? cheek
        self.breastExtent = breastExtent; self.flankLine = flankLine; self.spotting = spotting; self.crownLine = crownLine
        self.throatExtent = throatExtent; self.maskExtent = maskExtent; self.barring = barring; self.fringe = fringe
        self.featherRows = featherRows; self.iridescence = iridescence
    }
}
