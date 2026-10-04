/// Fixed, built elements: fences, walls, stairs, sheds, shelters, bridges. Larger budgets than props
/// (up to ~25k tris). Modular pieces should snap on a 0.5 m grid so scenes can tile them.
public enum Structures {
    public static let all: [any RealAsset.Type] = [
        JerseyBarrier.self,
        ConstructionFence.self,
        ScaffoldBay.self,
        RailFence.self,
        BarnWall.self,
        OfficeDoor.self,
        GlassDoor.self,
        ElevatorDoors.self,
        OfficeWindow.self,
        OfficeBlock.self,
        BaseballDiamond.self,
        OutfieldWall.self,
        FoulPole.self,
        Backstop.self,
        Dugout.self,
        Bleachers.self,
        LightTower.self,
        HospitalDoors.self,
        SurgicalLight.self,
        CeilingBoom.self,
        ScrubSink.self,
        PrivacyCurtain.self,
        Headwall.self,
        NurseStation.self,
        // realityhd:structure
    ]
}
