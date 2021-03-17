import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import '../utils.dart';

final _matcher = RegExp(r"curl '(https://.*/\?o=.*)'");

class FilterCommand extends Command {
  final name = 'filter';
  final description = 'Filters curl commands from DevTools into relevant URLs';

  Stream<String> filterCurl(Stream<String> lines) async* {
    await for (var line in lines) {
      var match = _matcher.firstMatch(line);
      if (match != null) {
        yield match.group(1)!;
      }
    }
  }

  @override
  final argParser = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('output', abbr: 'o');

  run() async {
    String? input = argResults!['input'];
    String? output = argResults!['output'];
    Stream<List<int>> inputStream;
    if (input != null) {
      inputStream = File(input).openRead();
    } else {
      inputStream = stdin;
    }
    var filtered = filterCurl(inputStream.toLines());
    if (output != null) {
      var sink = File(output).openWrite();
      await filtered.writeTo(sink);
      await sink.close();
    } else {
      await filtered.writeTo(stdout);
    }
  }
}
