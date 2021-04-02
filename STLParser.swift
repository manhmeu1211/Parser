import Foundation
import SceneKit

public enum BinarySTLParser {
    public enum STLError: Error {
        case fileTooSmall(size: Int)
        case unexpectedFileSize(expected: Int, actual: Int)
        case triangleCountMismatch(diff: Int)
    }
    
    public enum UnitScale: Float {
        case meter = 1.0
        case millimeter = 0.001
    }
    
    public static func fixSTLFile(at url: URL,
                                  unit scale: UnitScale = .meter,
                                  correctFor3DPrint: Bool = true) throws
    {
        let fileData = try Data(contentsOf: url, options: .alwaysMapped) // can cause rethrow
        var fixData = fileData
        guard fileData.count > 84 else {
            throw STLError.fileTooSmall(size: fileData.count)
        }
        
        let triangleBytes = MemoryLayout<Triangle>.size
        
        var needFixData = false
        for index in stride(from: 84, to: fileData.count, by: triangleBytes) {
            //            trianglesCounted += 1
            if index + triangleBytes > fileData.count { break }
            var triangleData = fileData.subdata(in: index..<index+triangleBytes)
            var triangle: Triangle = triangleData.withUnsafeMutableBytes { $0.pointee }
            // https://developer.apple.com/documentation/accelerate/working_with_vectors
            if (triangle.normal.x == 0 && triangle.normal.y == 0 && triangle.normal.z == 0) {
                let vertex1 = simd_float3(triangle.v1.x, triangle.v1.y, triangle.v1.z)
                let vertex2 = simd_float3(triangle.v2.x, triangle.v2.y, triangle.v2.z)
                let vertex3 = simd_float3(triangle.v3.x, triangle.v3.y, triangle.v3.z)
                let vector1 = vertex2 - vertex3
                let vector2 = vertex2 - vertex1
                let normal = simd_normalize(simd_cross(vector1, vector2))
                triangle.normal = SCNVector3.init(normal.x, normal.y, normal.z)
                let normalData = triangle.normal.unsafeData()
                fixData.replaceSubrange(index..<index+12, with: normalData)
                needFixData = true
            }
        }
        if needFixData {
            try fixData.write(to: url)
        }
    }
}

// The layout of this Triangle struct corresponds with the layout of bytes in the STL spec,
// as described at: http://www.fabbers.com/tech/STL_Format#Sct_binary
private struct Triangle {
    var normal: SCNVector3
    var v1: SCNVector3
    var v2: SCNVector3
    var v3: SCNVector3
    var attributes: UInt16
}

private extension SCNVector3 {
    mutating func unsafeData() -> Data {
        return Data(buffer: UnsafeBufferPointer(start: &self, count: 1))
    }
}

private extension Data {
    func scanValue<T>(start: Int, length: Int) -> T {
        return self.subdata(in: start..<start+length).withUnsafeBytes { $0.pointee }
    }
}


//do {
//    try BinarySTLParser.fixSTLFile(at: url, unit: .meter)
//    try autoreleasepool {
//        let stlScene = try SCNScene(url: url, options: nil)
//        for subNode in stlScene.rootNode.childNodes {
//            // to check this node is from stl data or not
//            subNode.name = "jaw"
//            subNode.geometry?.firstMaterial?.diffuse.contents = UIColor(displayP3Red: 144/255, green: 144/255, blue: 144/255, alpha: 1)
//            subNode.geometry?.firstMaterial?.roughness.intensity = 0.5
//            self.node.addChildNode(subNode.flattenedClone())
//        }
//    }
//} catch {
//
//}
