import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'filter.dart';
import 'manifest.dart';
import 'rip.dart';
import 'srt.dart';
import '../utils.dart';

class ImportCommand extends Command {
  final name = 'import';
  final description = 'All-in-one command for importing a new show';

  @override
  final argParser = ArgParser()
    ..addOption('show', abbr: 's', help: "The show's Netflix ID")
    ..addOption('path',
        abbr: 'p',
        help: "The path to import the show to (generally srt/<name>)")
    ..addOption('episodes',
        abbr: 'e',
        help: 'The codes for each episode in order. '
            'See CONTRIBUTING.md for format.')
    ..addOption('urls', abbr: 'u', help: 'The URLs to rip subtitles from.')
    ..addOption('curl',
        abbr: 'c',
        help: 'A log of curl commands from DevTools to look for '
            'subtitle URLs in.')
    ..addFlag('save-xml',
        help: 'Save the raw XML subtitles from Netflix '
            '(for debugging the SRT converter).');

  run() async {
    var show = argResults!['show'] ?? (throw Exception('--show is required'));
    var path = argResults!['path'] ?? (throw Exception('--path is required'));
    var episodes =
        argResults!['episodes'] ?? (throw Exception('--episodes is required'));
    var urlsArg = argResults!['urls'];
    var curl = argResults!['curl'];
    var saveXml = argResults!['save-xml'] as bool;

    if ((urlsArg != null && curl != null) ||
        (urlsArg == null && curl == null)) {
      throw Exception('Pass exactly one of --urls or --curl, not both');
    }

    var directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('$path created.');
    }

    var codes = ManifestCommand().evaluateCodes(episodes);
    var manifest = await ManifestCommand().makeManifest(show, codes);

    var prettyJson = JsonEncoder.withIndent('  ');

    await File('$path/manifest.json')
        .writeAsString(prettyJson.convert(manifest));
    print('manifest.json created.');

    Stream<String> urls;
    if (urlsArg != null) {
      print('Ripping subtitles from URLs in $urlsArg...');
      urls = File(urlsArg).openLines();
    } else {
      print('Ripping subtitles from curl log in $curl...');
      urls = FilterCommand().filterCurl(File(curl!).openLines());
    }
    var count = 0;
    var srt = SrtCommand();
    stdout.write('Ripped $count/${codes.length} subtitles');
    var codesCopy = codes.toList();
    await for (var sub in RipCommand().getSubtitles(urls)) {
      var code = codesCopy.removeAt(0);
      if (saveXml) await File('$path/$code.xml').writeAsString(sub);
      var sink = File('$path/$code.srt').openWrite();
      srt.convert(sub, sink);
      await sink.close();
      stdout.write('\rRipped ${++count}/${codes.length} subtitles      ');
      await stdout.flush();
    }
    stdout.writeln();
    print('Done! Run `transcripts build` to re-build the website.');
  }
}
