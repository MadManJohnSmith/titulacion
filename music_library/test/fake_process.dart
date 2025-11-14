import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mockito/mockito.dart';

class FakeProcess extends Fake implements Process {
  final int _exitCode;
  final String _stdout;
  final String _stderr;

  FakeProcess({int exitCode = 0, String stdout = '', String stderr = ''})
      : _exitCode = exitCode,
        _stdout = stdout,
        _stderr = stderr;

  @override
  Future<int> get exitCode => Future.value(_exitCode);

  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(_stdout));

  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(_stderr));

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return true;
  }

  @override
  int get pid => 123;

  @override
  IOSink get stdin => throw UnimplementedError();
}
