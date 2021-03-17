import 'package:args/command_runner.dart';

import 'commands/build.dart';
import 'commands/filter.dart';
import 'commands/import.dart';
import 'commands/manifest.dart';
import 'commands/rip.dart';
import 'commands/serve.dart';
import 'commands/srt.dart';

class TranscriptsRunner extends CommandRunner {
  TranscriptsRunner() : super('transcripts', 'Various tools') {
    addCommand(BuildCommand());
    addCommand(FilterCommand());
    addCommand(ImportCommand());
    addCommand(ManifestCommand());
    addCommand(RipCommand());
    addCommand(ServeCommand());
    addCommand(SrtCommand());
  }
}
