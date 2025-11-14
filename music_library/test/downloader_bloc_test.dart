import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:music_library/blocs/downloader/downloader_bloc.dart';
import 'package:music_library/blocs/downloader/downloader_event.dart';
import 'package:music_library/blocs/downloader/downloader_state.dart';
import 'package:music_library/database/database_helper.dart';
import 'package:music_library/models/track.dart';
import 'package:music_library/utils/process_manager.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:file/memory.dart';

import 'downloader_bloc_test.mocks.dart';
import 'fake_process.dart';

@GenerateMocks([DatabaseHelper, ProcessManager, Process])
void main() {
  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    // Set the database factory to the FFI factory
    databaseFactory = databaseFactoryFfi;
  });

  group('DownloaderBloc', () {
    late DownloaderBloc downloaderBloc;
    late MockDatabaseHelper mockDatabaseHelper;
    late MockProcessManager mockProcessManager;
    late MockProcess mockProcess;
    late MemoryFileSystem fileSystem;

    setUp(() {
      mockDatabaseHelper = MockDatabaseHelper();
      mockProcessManager = MockProcessManager();
      downloaderBloc = DownloaderBloc(
        databaseHelper: mockDatabaseHelper,
        processManager: mockProcessManager,
      );
      mockProcess = MockProcess();
      fileSystem = MemoryFileSystem();
    });

    final track = Track(
      id: '123',
      title: 'Test Track',
      artist: 'Test Artist',
      album: 'Test Album',
      duration: 180,
      quality: 'High',
      source: 'https://example.com/track.mp3',
      filePath: '/tmp/track.mp3',
    );

    test('emits [DownloaderLoading, DownloaderSuccess] when download is successful', () async {
      when(mockDatabaseHelper.trackExists(any)).thenAnswer((_) async => false);
      when(mockDatabaseHelper.getUserSettings()).thenAnswer((_) async => null);
      when(mockProcessManager.start(any, any)).thenAnswer((_) async => mockProcess);
      when(mockProcess.exitCode).thenAnswer((_) async => 0);
      when(mockProcessManager.run(any, any)).thenAnswer((_) async => ProcessResult(1, 0, '', ''));
      fileSystem.file('/tmp/track.mp3.tmp').createSync(recursive: true);

      final expected = [
        DownloaderLoading(),
        DownloaderSuccess(),
      ];

      expectLater(downloaderBloc.stream, emitsInOrder(expected));

      downloaderBloc.add(DownloadTrackEvent(track));
    });

    test('emits [DownloaderLoading, DownloaderFailure] when track already exists', () async {
      when(mockDatabaseHelper.trackExists(any)).thenAnswer((_) async => true);
      when(mockDatabaseHelper.getUserSettings()).thenAnswer((_) async => null);

      final expected = [
        DownloaderLoading(),
        const DownloaderFailure('Track already exists'),
      ];

      expectLater(downloaderBloc.stream, emitsInOrder(expected));

      downloaderBloc.add(DownloadTrackEvent(track));
    });

    test('emits [DownloaderLoading, DownloaderFailure] when download fails', () async {
      when(mockDatabaseHelper.trackExists(any)).thenAnswer((_) async => false);
      when(mockDatabaseHelper.getUserSettings()).thenAnswer((_) async => null);
      when(mockProcessManager.start(any, any)).thenAnswer((_) async => mockProcess);
      when(mockProcess.exitCode).thenAnswer((_) async => 1);

      final expected = [
        DownloaderLoading(),
        const DownloaderFailure('Download failed'),
      ];

      expectLater(downloaderBloc.stream, emitsInOrder(expected));

      downloaderBloc.add(DownloadTrackEvent(track));
    });
  });
}
