import 'package:args/command_runner.dart';

import 'commands/build.dart';

class TranscriptsRunner extends CommandRunner {
  TranscriptsRunner() : super('transcripts', 'Various tools') {
    addCommand(Build());
  }
}
