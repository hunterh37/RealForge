/// Fixed, built elements: fences, walls, stairs, sheds, shelters, bridges. Larger budgets than props
/// (up to ~25k tris). Modular pieces should snap on a 0.5 m grid so scenes can tile them.
public enum Structures {
    public static let all: [any RealAsset.Type] = [
        JerseyBarrier.self,
        ConstructionFence.self,
        ScaffoldBay.self,
        RailFence.self,
        // realforge:structure
    ]
}
