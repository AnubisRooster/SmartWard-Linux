import Foundation
#if canImport(Accelerate)
import Accelerate
#endif

/// Pure cosine-similarity math, isolated so `VectorIndex`'s ranking is
/// unit-testable independent of any embedding provider.
public enum CosineSimilarity {
    /// Cosine similarity in `[-1, 1]`. Returns `0` for empty, mismatched-length,
    /// or zero-magnitude vectors rather than propagating NaN from a division
    /// by zero.
    public static func score(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot: Float = 0
        var sumSquaresA: Float = 0
        var sumSquaresB: Float = 0
        #if canImport(Accelerate)
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        vDSP_svesq(a, 1, &sumSquaresA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &sumSquaresB, vDSP_Length(b.count))
        #else
        for i in 0..<a.count {
            dot += a[i] * b[i]
            sumSquaresA += a[i] * a[i]
            sumSquaresB += b[i] * b[i]
        }
        #endif

        let denominator = (sumSquaresA * sumSquaresB).squareRoot()
        guard denominator > 0 else { return 0 }
        return dot / denominator
    }
}
