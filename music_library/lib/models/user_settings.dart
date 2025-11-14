class UserSettings {
  final String downloadQuality;
  final String libraryLocation;
  final String? proxyAddress;

  UserSettings({
    required this.downloadQuality,
    required this.libraryLocation,
    this.proxyAddress,
  });
}
