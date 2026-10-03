/// Trees, rocks, ground and grass. New nature assets go in a subfolder here and are listed below.
public enum Nature {
    public static let all: [any RealAsset.Type] = [
        OakTree.self, BirchTree.self, SpruceTree.self, Shrub.self, Tree.self,
        Boulder.self, Pebbles.self, GroundPatch.self, GrassClump.self,
        TerrainHill.self, DirtPath.self, Puddle.self, MudPatch.self, GravelPatch.self, SnowDrift.self,
        // realforge:nature
    ]
}
