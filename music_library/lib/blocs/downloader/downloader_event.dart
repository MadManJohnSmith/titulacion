import 'package:music_library/models/track.dart';

abstract class DownloaderEvent {}

class FetchMetadataEvent extends DownloaderEvent {
  final String url;

  FetchMetadataEvent(this.url);
}

class DownloadTrackEvent extends DownloaderEvent {
  final Track track;

  DownloadTrackEvent(this.track);
}

class CancelDownloadEvent extends DownloaderEvent {}
