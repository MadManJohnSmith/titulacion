import 'dart:io';

class ProcessManager {
  Future<Process> start(String executable, List<String> arguments, {String? workingDirectory}) {
    return Process.start(executable, arguments, workingDirectory: workingDirectory);
  }

  Future<ProcessResult> run(String executable, List<String> arguments, {String? workingDirectory}) {
    return Process.run(executable, arguments, workingDirectory: workingDirectory);
  }
}
