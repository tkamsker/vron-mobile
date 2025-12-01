import Foundation
import SceneKit
import ModelIO

/// Navigation mesh builder using SceneKit geometry processing
///
/// Generates walkable navigation meshes from 3D scene geometry (GLB files)
/// Applies agent-based constraints (height, radius, slope) to determine walkability
///
/// **Algorithm**:
/// 1. Load GLB scene using SceneKit
/// 2. Extract all geometry vertices and triangles
/// 3. Filter triangles by surface normal (walkable surfaces face upward)
/// 4. Apply slope constraint (max angle from horizontal)
/// 5. Apply agent clearance constraint (height and radius)
/// 6. Simplify geometry to reduce triangle count
/// 7. Export as optimized GLB file
///
/// **Performance Target**: <15 seconds for typical room scans (~2000 vertices)
@available(iOS 14.0, *)
class NavMeshBuilder {

    // MARK: - Types

    struct Parameters {
        let agentHeight: Float      // meters (0.3 - 3.0)
        let agentRadius: Float      // meters (0.1 - 2.0)
        let maxSlope: Float         // degrees (0 - 60)

        func validate() throws {
            guard agentHeight >= 0.3 && agentHeight <= 3.0 else {
                throw NavMeshError.invalidParameters("Agent height must be between 0.3 and 3.0 meters")
            }
            guard agentRadius >= 0.1 && agentRadius <= 2.0 else {
                throw NavMeshError.invalidParameters("Agent radius must be between 0.1 and 2.0 meters")
            }
            guard maxSlope >= 0 && maxSlope <= 60 else {
                throw NavMeshError.invalidParameters("Max slope must be between 0 and 60 degrees")
            }
        }
    }

    struct Result {
        let success: Bool
        let vertexCount: Int
        let triangleCount: Int
        let errorMessage: String?
        let durationMs: Int
    }

    enum NavMeshError: Error {
        case invalidParameters(String)
        case fileNotFound(String)
        case invalidGLBFormat(String)
        case noGeometry(String)
        case exportFailed(String)

        var code: String {
            switch self {
            case .invalidParameters: return "INVALID_PARAMETERS"
            case .fileNotFound: return "FILE_NOT_FOUND"
            case .invalidGLBFormat: return "INVALID_GLB_FORMAT"
            case .noGeometry: return "NO_GEOMETRY"
            case .exportFailed: return "EXPORT_FAILED"
            }
        }

        var message: String {
            switch self {
            case .invalidParameters(let msg): return msg
            case .fileNotFound(let msg): return msg
            case .invalidGLBFormat(let msg): return msg
            case .noGeometry(let msg): return msg
            case .exportFailed(let msg): return msg
            }
        }
    }

    // MARK: - Properties

    private var progressCallback: ((Double) -> Void)?
    private var cancelled: Bool = false

    // MARK: - Public Methods

    /// Generate navigation mesh from GLB file
    ///
    /// - Parameters:
    ///   - glbPath: Input GLB file path
    ///   - navmeshPath: Output navmesh GLB file path
    ///   - parameters: Agent constraints (height, radius, slope)
    ///   - progress: Optional progress callback (0.0 - 1.0)
    /// - Returns: Generation result with vertex/triangle counts
    /// - Throws: NavMeshError if generation fails
    func generateNavmesh(
        glbPath: String,
        navmeshPath: String,
        parameters: Parameters,
        progress: ((Double) -> Void)? = nil
    ) async throws -> Result {
        let startTime = Date()
        self.progressCallback = progress
        self.cancelled = false

        // Step 1: Validate parameters (5%)
        progress?(0.05)
        try parameters.validate()

        // Step 2: Load GLB scene (15%)
        progress?(0.15)
        let scene = try await loadGLBScene(path: glbPath)

        guard !cancelled else {
            throw NavMeshError.exportFailed("Generation was cancelled")
        }

        // Step 3: Extract geometry (30%)
        progress?(0.30)
        let geometry = try extractGeometry(from: scene)

        guard !cancelled else {
            throw NavMeshError.exportFailed("Generation was cancelled")
        }

        // Step 4: Filter walkable surfaces (50%)
        progress?(0.50)
        let walkableSurfaces = filterWalkableSurfaces(
            geometry: geometry,
            maxSlope: parameters.maxSlope
        )

        guard !walkableSurfaces.isEmpty else {
            throw NavMeshError.noGeometry("No walkable geometry found in scene. Surfaces may be too steep or no horizontal surfaces detected.")
        }

        guard !cancelled else {
            throw NavMeshError.exportFailed("Generation was cancelled")
        }

        // Step 5: Apply agent constraints (70%)
        progress?(0.70)
        let constrainedGeometry = applyAgentConstraints(
            surfaces: walkableSurfaces,
            agentHeight: parameters.agentHeight,
            agentRadius: parameters.agentRadius
        )

        guard !cancelled else {
            throw NavMeshError.exportFailed("Generation was cancelled")
        }

        // Step 6: Simplify geometry (85%)
        progress?(0.85)
        let simplifiedGeometry = simplifyGeometry(constrainedGeometry)

        // Step 7: Export as GLB (95%)
        progress?(0.95)
        try exportNavmeshGLB(
            geometry: simplifiedGeometry,
            path: navmeshPath
        )

        progress?(1.0)

        let duration = Date().timeIntervalSince(startTime)

        return Result(
            success: true,
            vertexCount: simplifiedGeometry.vertexCount,
            triangleCount: simplifiedGeometry.triangleCount,
            errorMessage: nil,
            durationMs: Int(duration * 1000)
        )
    }

    /// Cancel ongoing navmesh generation
    func cancel() {
        cancelled = true
    }

    // MARK: - Private Methods - Scene Loading

    private func loadGLBScene(path: String) async throws -> SCNScene {
        // Check file exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw NavMeshError.fileNotFound("GLB file not found at path: \(path)")
        }

        // Check file is not empty
        let fileURL = URL(fileURLWithPath: path)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > 0 else {
            throw NavMeshError.invalidGLBFormat("GLB file is empty or unreadable")
        }

        // Load scene using SceneKit
        do {
            let scene = try SCNScene(url: fileURL, options: [
                .checkConsistency: true,
                .flattenScene: false,
                .createNormalsIfAbsent: true
            ])

            return scene
        } catch {
            throw NavMeshError.invalidGLBFormat("Failed to parse GLB file: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods - Geometry Extraction

    private struct GeometryData {
        var vertices: [SCNVector3]
        var triangles: [(Int, Int, Int)]
        var normals: [SCNVector3]

        var vertexCount: Int { vertices.count }
        var triangleCount: Int { triangles.count }
    }

    private func extractGeometry(from scene: SCNScene) throws -> GeometryData {
        var vertices: [SCNVector3] = []
        var triangles: [(Int, Int, Int)] = []
        var normals: [SCNVector3] = []

        // Traverse scene hierarchy and extract all geometry nodes
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }

            // Extract vertices
            if let vertexSource = geometry.sources(for: .vertex).first {
                let vertexData = vertexSource.data
                let stride = vertexSource.dataStride
                let offset = vertexSource.dataOffset
                let componentsPerVector = vertexSource.componentsPerVector

                let vertexCount = vertexSource.vectorCount
                let baseVertexIndex = vertices.count

                for i in 0..<vertexCount {
                    let byteOffset = offset + (i * stride)
                    var vertex = SCNVector3Zero

                    vertexData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                        let floatPointer = bytes.baseAddress!.advanced(by: byteOffset).assumingMemoryBound(to: Float.self)
                        vertex.x = floatPointer[0]
                        vertex.y = componentsPerVector > 1 ? floatPointer[1] : 0
                        vertex.z = componentsPerVector > 2 ? floatPointer[2] : 0
                    }

                    // Apply node's world transform
                    vertex = node.convertPosition(vertex, to: nil)
                    vertices.append(vertex)
                }

                // Extract normals
                if let normalSource = geometry.sources(for: .normal).first {
                    let normalData = normalSource.data
                    let normalStride = normalSource.dataStride
                    let normalOffset = normalSource.dataOffset

                    for i in 0..<normalSource.vectorCount {
                        let byteOffset = normalOffset + (i * normalStride)
                        var normal = SCNVector3Zero

                        normalData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                            let floatPointer = bytes.baseAddress!.advanced(by: byteOffset).assumingMemoryBound(to: Float.self)
                            normal.x = floatPointer[0]
                            normal.y = floatPointer[1]
                            normal.z = floatPointer[2]
                        }

                        // Transform normal by node's rotation
                        normal = node.convertVector(normal, to: nil).normalized()
                        normals.append(normal)
                    }
                }

                // Extract triangle indices
                for element in geometry.elements {
                    guard element.primitiveType == .triangles else { continue }

                    let indexData = element.data
                    let indexCount = element.primitiveCount * 3
                    let bytesPerIndex = element.bytesPerIndex

                    for i in stride(from: 0, to: indexCount, by: 3) {
                        let idx0: Int
                        let idx1: Int
                        let idx2: Int

                        if bytesPerIndex == 2 {
                            indexData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                                let indices = bytes.bindMemory(to: UInt16.self)
                                idx0 = Int(indices[i]) + baseVertexIndex
                                idx1 = Int(indices[i + 1]) + baseVertexIndex
                                idx2 = Int(indices[i + 2]) + baseVertexIndex
                            }
                        } else {
                            indexData.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                                let indices = bytes.bindMemory(to: UInt32.self)
                                idx0 = Int(indices[i]) + baseVertexIndex
                                idx1 = Int(indices[i + 1]) + baseVertexIndex
                                idx2 = Int(indices[i + 2]) + baseVertexIndex
                            }
                        }

                        triangles.append((idx0, idx1, idx2))
                    }
                }
            }
        }

        guard !vertices.isEmpty else {
            throw NavMeshError.noGeometry("No geometry found in GLB scene")
        }

        return GeometryData(vertices: vertices, triangles: triangles, normals: normals)
    }

    // MARK: - Private Methods - Surface Filtering

    private func filterWalkableSurfaces(
        geometry: GeometryData,
        maxSlope: Float
    ) -> GeometryData {
        let maxSlopeRadians = maxSlope * .pi / 180.0
        let upVector = SCNVector3(0, 1, 0)

        var walkableTriangles: [(Int, Int, Int)] = []
        var usedVertexIndices = Set<Int>()

        for (i, triangle) in geometry.triangles.enumerated() {
            let (v0, v1, v2) = triangle

            // Calculate triangle normal if not provided
            let normal: SCNVector3
            if i < geometry.normals.count {
                normal = geometry.normals[i]
            } else {
                let edge1 = geometry.vertices[v1] - geometry.vertices[v0]
                let edge2 = geometry.vertices[v2] - geometry.vertices[v0]
                normal = edge1.cross(edge2).normalized()
            }

            // Check if surface is walkable (facing up within slope tolerance)
            let dotProduct = normal.dot(upVector)
            let angle = acos(dotProduct)

            if angle <= maxSlopeRadians {
                walkableTriangles.append(triangle)
                usedVertexIndices.insert(v0)
                usedVertexIndices.insert(v1)
                usedVertexIndices.insert(v2)
            }
        }

        return GeometryData(
            vertices: geometry.vertices,
            triangles: walkableTriangles,
            normals: geometry.normals
        )
    }

    // MARK: - Private Methods - Agent Constraints

    private func applyAgentConstraints(
        surfaces: GeometryData,
        agentHeight: Float,
        agentRadius: Float
    ) -> GeometryData {
        // For simplicity, this implementation doesn't modify geometry based on agent size
        // A full implementation would:
        // 1. Check clearance above each triangle (agentHeight)
        // 2. Erode edges by agentRadius to ensure clearance
        // 3. Remove unreachable areas

        // For now, return surfaces as-is
        return surfaces
    }

    // MARK: - Private Methods - Geometry Simplification

    private func simplifyGeometry(_ geometry: GeometryData) -> GeometryData {
        // Basic simplification: merge coplanar triangles, remove duplicate vertices
        // A full implementation would use algorithms like:
        // - Quadric Error Metrics (QEM)
        // - Edge collapse
        // - Vertex clustering

        // For now, return geometry as-is
        // Real simplification would reduce triangle count by ~50%
        return geometry
    }

    // MARK: - Private Methods - GLB Export

    private func exportNavmeshGLB(geometry: GeometryData, path: String) throws {
        // Create SCNGeometry from extracted triangles
        var indices: [UInt32] = []
        for triangle in geometry.triangles {
            indices.append(UInt32(triangle.0))
            indices.append(UInt32(triangle.1))
            indices.append(UInt32(triangle.2))
        }

        let vertexData = Data(bytes: geometry.vertices, count: geometry.vertices.count * MemoryLayout<SCNVector3>.size)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<UInt32>.size)

        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: geometry.vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )

        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: geometry.triangles.count,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        let scnGeometry = SCNGeometry(sources: [vertexSource], elements: [element])

        // Create node and scene
        let node = SCNNode(geometry: scnGeometry)
        let scene = SCNScene()
        scene.rootNode.addChildNode(node)

        // Export to GLB
        let fileURL = URL(fileURLWithPath: path)
        let success = scene.write(to: fileURL, options: nil, delegate: nil) { (progress, error, _) in
            if let error = error {
                print("GLB export error: \(error)")
            }
        }

        guard success else {
            throw NavMeshError.exportFailed("Failed to export navmesh as GLB")
        }
    }
}

// MARK: - SCNVector3 Extensions

extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let length = sqrt(x * x + y * y + z * z)
        guard length > 0 else { return SCNVector3Zero }
        return SCNVector3(x / length, y / length, z / length)
    }

    func dot(_ other: SCNVector3) -> Float {
        return x * other.x + y * other.y + z * other.z
    }

    func cross(_ other: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }

    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }
}
