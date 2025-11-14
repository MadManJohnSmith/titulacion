import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_library/blocs/downloader/downloader_bloc.dart';
import 'package:music_library/blocs/downloader/downloader_event.dart';
import 'package:music_library/blocs/downloader/downloader_state.dart';
import 'package:music_library/database/database_helper.dart';
import 'package:music_library/utils/process_manager.dart';
import 'package:path_provider/path_provider.dart';

class DownloaderScreen extends StatelessWidget {
  const DownloaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DownloaderBloc(
        databaseHelper: DatabaseHelper(),
        processManager: ProcessManager(),
      ),
      child: const DownloaderView(),
    );
  }
}

class DownloaderView extends StatelessWidget {
  const DownloaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Enter URL',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<DownloaderBloc>().add(FetchMetadataEvent(controller.text));
              },
              child: const Text('Fetch Metadata'),
            ),
            const SizedBox(height: 16),
            BlocBuilder<DownloaderBloc, DownloaderState>(
              builder: (context, state) {
                if (state is DownloaderLoading) {
                  return const CircularProgressIndicator();
                } else if (state is MetadataFetched) {
                  return Column(
                    children: [
                      Text('Title: ${state.track.title}'),
                      Text('Artist: ${state.track.artist}'),
                      Text('Album: ${state.track.album}'),
                      ElevatedButton(
                        onPressed: () async {
                          final directory = await getApplicationDocumentsDirectory();
                          final track = state.track.copyWith(
                            filePath: '${directory.path}/${state.track.id}',
                          );
                          context.read<DownloaderBloc>().add(DownloadTrackEvent(track));
                        },
                        child: const Text('Download'),
                      ),
                    ],
                  );
                } else if (state is DownloaderSuccess) {
                  return const Text('Download successful!');
                } else if (state is DownloaderFailure) {
                  return Text('Download failed: ${state.error}');
                } else {
                  return Container();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
