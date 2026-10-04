import Testing
import simd
@testable import RealCore

@Suite struct AnatomyTests {
    @Test func framesAreRightHandedAndOrthonormal() {
        for c in [Chirality.left, .right] {
            let f = HandFrames(HandPose.rest(c, curl: 0.4))
            for fr in f.bones.flatMap({ $0 }) + [f.palm, f.forearm] {
                #expect(abs(simd_length(fr.x) - 1) < 1e-3 && abs(simd_length(fr.y) - 1) < 1e-3 && abs(simd_length(fr.z) - 1) < 1e-3)
                #expect(simd_dot(simd_cross(fr.y, fr.z), fr.x) > 0.99)
            }
            #expect(abs(f.scale - 1) < 0.05)
        }
    }

    @Test func dorsalPointsUpForPalmDownHands() {
        for c in [Chirality.left, .right] {
            let f = HandFrames(HandPose.rest(c, distal: V3(0, 0, -1), dorsal: V3(0, 1, 0)))
            #expect(f.palm.z.y > 0.95)
            // Authored radial offsets land on the thumb side.
            let thumbSide = simd_dot(f.palmPoint(V3(0.02, 0, 0)) - f.palm.origin, f.palmPoint(V3(0.02, 0.01, -0.01)) - f.palm.origin)
            #expect(thumbSide > 0)
            let toThumb = HandPose.rest(c)[.thumbIntermediateBase] - HandPose.rest(c)[.wrist]
            #expect(simd_dot(f.palmPoint(V3(0.02, 0, 0)) - f.palm.origin, toThumb) > 0)
        }
    }

    @Test func bonesBuildWithCartilage() {
        let b = HandBones(detail: 0.6)
        #expect(b.digits.count == 5 && b.digits[0].count == 3 && b.digits[1].count == 4)
        for m in b.digits.flatMap({ $0 }) {
            #expect(m.triangleCount > 500)
            #expect(m.materials.contains(HandBones.boneKey))
        }
        #expect(b.digits[1][1].materials.contains(HandBones.cartilageKey))
        let posed = b.forHand(.right).posed(HandFrames(HandPose.rest(.right)))
        #expect(posed.triangleCount > 20_000)
    }

    @Test func softTissueTopologyIsStableAcrossPoses() {
        let st = HandSoftTissue(detail: 0.75)
        let a = st.build(HandFrames(HandPose.rest(.right, curl: 0)), layers: .anatomy)
        let b = st.build(HandFrames(HandPose.rest(.right, curl: 0.9)), layers: .anatomy)
        #expect(a.vertexCount == b.vertexCount && a.triangleCount == b.triangleCount)
        #expect(a.materials.count == 5)
        for s in a.surfaces { #expect(s.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) }
    }
}
