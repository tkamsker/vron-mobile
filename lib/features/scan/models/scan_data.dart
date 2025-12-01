/// Scan session data model
///
/// Represents an active or completed scan session
class ScanData {
  /// Unique identifier for this scan session
  final String id;

  /// Name/label for the scanned room
  final String? roomName;

  /// Project ID this scan belongs to (null for guest mode)
  final String? projectId;

  /// Scan start timestamp
  final DateTime startedAt;

  /// Scan completion timestamp
  final DateTime? completedAt;

  /// Number of points collected
  final int pointsCollected;

  /// Scan duration in seconds
  final double durationSeconds;

  /// Path to the scene GLB file (null until saved)
  final String? sceneGlbPath;

  /// Path to the navmesh GLB file (null until saved)
  final String? navmeshGlbPath;

  /// Scene file size in bytes
  final int? sceneFileSize;

  /// Navmesh file size in bytes
  final int? navmeshFileSize;

  /// Whether this is a guest mode scan
  final bool isGuestMode;

  /// Current scan status
  final ScanStatus status;

  const ScanData({
    required this.id,
    this.roomName,
    this.projectId,
    required this.startedAt,
    this.completedAt,
    this.pointsCollected = 0,
    this.durationSeconds = 0,
    this.sceneGlbPath,
    this.navmeshGlbPath,
    this.sceneFileSize,
    this.navmeshFileSize,
    this.isGuestMode = false,
    this.status = ScanStatus.ready,
  });

  /// Create a new scan session
  factory ScanData.newSession({
    required String id,
    String? projectId,
    bool isGuestMode = false,
  }) {
    return ScanData(
      id: id,
      projectId: projectId,
      startedAt: DateTime.now(),
      isGuestMode: isGuestMode,
      status: ScanStatus.ready,
    );
  }

  /// Copy with modifications
  ScanData copyWith({
    String? id,
    String? roomName,
    String? projectId,
    DateTime? startedAt,
    DateTime? completedAt,
    int? pointsCollected,
    double? durationSeconds,
    String? sceneGlbPath,
    String? navmeshGlbPath,
    int? sceneFileSize,
    int? navmeshFileSize,
    bool? isGuestMode,
    ScanStatus? status,
  }) {
    return ScanData(
      id: id ?? this.id,
      roomName: roomName ?? this.roomName,
      projectId: projectId ?? this.projectId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      pointsCollected: pointsCollected ?? this.pointsCollected,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sceneGlbPath: sceneGlbPath ?? this.sceneGlbPath,
      navmeshGlbPath: navmeshGlbPath ?? this.navmeshGlbPath,
      sceneFileSize: sceneFileSize ?? this.sceneFileSize,
      navmeshFileSize: navmeshFileSize ?? this.navmeshFileSize,
      isGuestMode: isGuestMode ?? this.isGuestMode,
      status: status ?? this.status,
    );
  }

  /// Get scan progress (0.0 to 1.0)
  double get progress {
    // Target is 100,000 points for a complete scan
    const targetPoints = 100000;
    return (pointsCollected / targetPoints).clamp(0.0, 1.0);
  }

  /// Check if scan is complete
  bool get isComplete => status == ScanStatus.completed;

  /// Check if scan is in progress
  bool get isScanning => status == ScanStatus.scanning;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ScanData &&
        other.id == id &&
        other.roomName == roomName &&
        other.projectId == projectId &&
        other.startedAt == startedAt &&
        other.completedAt == completedAt &&
        other.pointsCollected == pointsCollected &&
        other.durationSeconds == durationSeconds &&
        other.sceneGlbPath == sceneGlbPath &&
        other.navmeshGlbPath == navmeshGlbPath &&
        other.sceneFileSize == sceneFileSize &&
        other.navmeshFileSize == navmeshFileSize &&
        other.isGuestMode == isGuestMode &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      roomName,
      projectId,
      startedAt,
      completedAt,
      pointsCollected,
      durationSeconds,
      sceneGlbPath,
      navmeshGlbPath,
      sceneFileSize,
      navmeshFileSize,
      isGuestMode,
      status,
    );
  }

  @override
  String toString() {
    return 'ScanData(id: $id, roomName: $roomName, status: $status, points: $pointsCollected)';
  }
}

/// Scan status enum
enum ScanStatus {
  /// Ready to start scanning
  ready,

  /// Currently scanning
  scanning,

  /// Scan paused
  paused,

  /// Scan completed
  completed,

  /// Scan failed
  failed,

  /// Processing scan data
  processing,

  /// Saving to database
  saving,
}

/// Extension on ScanStatus for display strings
extension ScanStatusExtension on ScanStatus {
  String get displayName {
    switch (this) {
      case ScanStatus.ready:
        return 'Ready to scan';
      case ScanStatus.scanning:
        return 'Scanning...';
      case ScanStatus.paused:
        return 'Paused';
      case ScanStatus.completed:
        return 'Scan complete';
      case ScanStatus.failed:
        return 'Scan failed';
      case ScanStatus.processing:
        return 'Processing...';
      case ScanStatus.saving:
        return 'Saving...';
    }
  }
}
