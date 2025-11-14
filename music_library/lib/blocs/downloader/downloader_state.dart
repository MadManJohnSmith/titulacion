import 'package:equatable/equatable.dart';
import 'package:music_library/models/track.dart';

abstract class DownloaderState extends Equatable {
  const DownloaderState();

  @override
  List<Object> get props => [];
}

class DownloaderInitial extends DownloaderState {}

class DownloaderLoading extends DownloaderState {}

class MetadataFetched extends DownloaderState {
  final Track track;

  const MetadataFetched(this.track);

  @override
  List<Object> get props => [track];
}

class DownloaderSuccess extends DownloaderState {}

class DownloaderFailure extends DownloaderState {
  final String error;

  const DownloaderFailure(this.error);

  @override
  List<Object> get props => [error];
}
