import 'package:bloc/bloc.dart';
import 'package:music_library/blocs/downloader/downloader_event.dart';
import 'package:music_library/blocs/downloader/downloader_state.dart';
import 'package:music_library/database/database_helper.dart';
import 'package:music_library/models/track.dart';
import 'package:music_library/utils/process_manager.dart';
import 'dart:convert';
import 'dart:io';

class DownloaderBloc extends Bloc<DownloaderEvent, DownloaderState> {
  final DatabaseHelper databaseHelper;
  final ProcessManager processManager;
  Process? _process;

  DownloaderBloc({required this.databaseHelper, required this.processManager}) : super(DownloaderInitial()) {
    on<FetchMetadataEvent>((event, emit) async {
      emit(DownloaderLoading());
      try {
        final result = await processManager.run('rip', ['metadata', event.url, '--json']);
        if (result.exitCode == 0) {
          final json = jsonDecode(result.stdout);
          final track = Track.fromJson(json, '');
          emit(MetadataFetched(track));
        } else {
          emit(DownloaderFailure(result.stderr));
        }
      } catch (e) {
        emit(DownloaderFailure(e.toString()));
      }
    });

    on<DownloadTrackEvent>((event, emit) async {
      emit(DownloaderLoading());
      try {
        final userSettings = await databaseHelper.getUserSettings();
        final bool exists = await databaseHelper.trackExists(event.track.id);
        if (exists) {
          emit(const DownloaderFailure('Track already exists'));
          return;
        }

        final args = ['url', event.track.source, '--path', event.track.filePath];
        if (userSettings?.proxyAddress != null) {
          args.addAll(['--proxy', userSettings!.proxyAddress!]);
        }

        _process = await processManager.start('rip', args);
        final exitCode = await _process!.exitCode;

        if (exitCode == 0) {
          await databaseHelper.insertTrack(event.track);
          emit(DownloaderSuccess());
        } else {
          emit(const DownloaderFailure('Download failed'));
        }
      } catch (e) {
        emit(DownloaderFailure(e.toString()));
      }
    });

    on<CancelDownloadEvent>((event, emit) {
      _process?.kill();
      emit(DownloaderInitial());
    });
  }
}
