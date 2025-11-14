import 'dart:convert';

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final String quality;
  final String source;
  final String filePath;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.quality,
    required this.source,
    required this.filePath,
  });

  factory Track.fromJson(Map<String, dynamic> json, String filePath) {
    return Track(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      album: json['album'],
      duration: json['duration'],
      quality: 'High',
      source: json['url'],
      filePath: filePath,
    );
  }

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? quality,
    String? source,
    String? filePath,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      quality: quality ?? this.quality,
      source: source ?? this.source,
      filePath: filePath ?? this.filePath,
    );
  }
}
