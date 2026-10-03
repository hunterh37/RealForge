/// Movable objects under ~3 m: furniture, containers, street furniture, tools. Each prop is one file
/// in a theme subfolder (Containers/, Furniture/, Industrial/, Street/, ...) and is listed below.
public enum Props {
    public static let all: [any RealAsset.Type] = [
        WoodenCrate.self, Barrel.self, OilDrum.self, ParkBench.self, PicnicTable.self, StreetLamp.self,
        TrafficCone.self, FireHydrant.self, Bollard.self, Pallet.self, Mailbox.self, TrashCan.self,
        FirewoodStack.self,
        CampfireRing.self,
        DomeTent.self,
        CampChair.self,
        Cooler.self,
        CampLantern.self,
        Canoe.self,
        // realforge:prop
    ]
}
