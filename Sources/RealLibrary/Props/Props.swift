/// Movable objects under ~3 m: furniture, containers, street furniture, tools. Each prop is one file
/// in a theme subfolder (Containers/, Furniture/, Industrial/, Street/, ...) and is listed below.
public enum Props {
    public static let all: [any RealAsset.Type] = [
        WoodenCrate.self, Barrel.self, OilDrum.self, ParkBench.self, PicnicTable.self, StreetLamp.self,
        TrafficCone.self, FireHydrant.self, Bollard.self, Pallet.self, Mailbox.self, TrashCan.self,
        Sawhorse.self,
        Wheelbarrow.self,
        CementMixer.self,
        RebarBundle.self,
        Sandbag.self,
        CableSpool.self,
        TrafficBarrel.self,
        Dumpster.self,
        RoundHayBale.self,
        SquareHayBale.self,
        WaterTrough.self,
        // realforge:prop
    ]
}
