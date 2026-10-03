/// Trees, rocks, ground and grass. New nature assets go in a subfolder here and are listed below.
public enum Nature {
    public static let all: [any RealAsset.Type] = [
        OakTree.self, BirchTree.self, SpruceTree.self, Shrub.self, Tree.self,
        Boulder.self, Pebbles.self, GroundPatch.self, GrassClump.self,
        GrassTuft.self,
        TallGrass.self,
        DryGrass.self,
        LawnPatch.self,
        Fern.self,
        MeadowFlowers.self,
        CloverPatch.self,
        Dandelion.self,
        ReedClump.self,
        MushroomCluster.self,
        MossMound.self,
        IvyPatch.self,
        LeafLitter.self,
        // realforge:nature
    ]
}
