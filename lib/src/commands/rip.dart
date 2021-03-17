import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

import 'filter.dart';
import 'manifest.dart';
import '../utils.dart';

class RipCommand extends Command {
  final name = 'rip';
  final description = 'Downloads subtitles from Netflix';

  Stream<String> getSubtitles(Stream<String> urls) async* {
    await for (var url in urls) {
      yield (await http.get(Uri.parse(url))).body;
    }
  }

  Future<void> ripToFiles(
      Stream<String> urls, Directory output, List<String> codes) async {
    var writes = <Future>[];
    codes = codes.toList();
    await for (var sub in getSubtitles(urls)) {
      writes
          .add(File('${output.path}/${codes.removeAt(0)}').writeAsString(sub));
    }
    await Future.wait(writes);
  }

  @override
  final argParser = ArgParser()
    ..addOption('urls', abbr: 'u')
    ..addOption('curl', abbr: 'c')
    ..addOption('directory', abbr: 'd');

  run() async {
    String? urlsArg = argResults!['urls'];
    String? curl = argResults!['curl'];
    String? dirPath = argResults!['directory'];
    var output = dirPath == null ? Directory.current : Directory(dirPath);

    if (urlsArg != null && curl != null) {
      throw Exception('Pass only one of --urls or --curl, not both');
    }

    Stream<String> urls;
    if (urlsArg != null) {
      urls = File(urlsArg).openLines();
    } else if (curl != null) {
      urls = FilterCommand().filterCurl(File(curl).openLines());
    } else {
      urls = stdin.toLines();
    }
    ripToFiles(urls, output,
        ManifestCommand().evaluateCodes(argResults!.rest.join(' ')));
  }
}
