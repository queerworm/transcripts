import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class ManifestCommand extends Command {
  final name = 'manifest';
  final description = 'Generate a manifest.json for a Netflix show';
  final usage = 'manifest <netflix id> <episode codes>';

  Future<Map<String, dynamic>> makeManifest(
      String id, List<String> codes) async {
    codes = codes.toList();
    var response = await http.get(
        Uri.parse('http://api.netflix.com/catalog/titles/series/$id/episodes'));
    var document = XmlDocument.parse(response.body);
    Map<String, dynamic>? manifest;
    var episodes = <String, Map<String, String?>>{};
    var titles = document.rootElement.findElements('catalog_title');
    if (codes.length != titles.length) {
      throw Exception('Mismatch between number of codes (${codes.length}) '
          'and number of episodes (${titles.length})');
    }
    for (var catalogTitle in titles) {
      if (manifest == null) {
        manifest = {
          'title': catalogTitle
              .findElements('link')
              .firstWhere((el) =>
                  el.getAttribute('rel') ==
                  'http://schemas.netflix.com/catalog/titles.series')
              .getAttribute('title'),
          'netflix': id,
          'episodes': episodes
        };
      }
      episodes[codes.removeAt(0)] = {
        'title': catalogTitle.getElement('title')?.getAttribute('regular'),
        'netflix': catalogTitle.getElement('id')?.text.split('/').last
      };
    }
    return manifest!;
  }

  run() async {
    var args = argResults?.rest ?? [];
    if (args.length < 1) throw Exception('Needs at least one argument');
    var manifest =
        await makeManifest(args[0], evaluateCodes(args.skip(1).join(' ')));
    print(json.encode(manifest));
  }

  List<String> evaluateCodes(String expr) {
    var codes = <String>[];
    int? season = 0;
    for (var arg in expr.split(RegExp(r'\s+'))) {
      if (arg.startsWith(':')) {
        if (season == null) {
          throw Exception("Can't use :# syntax after a non-numerical code");
        }
        var seasons = 1;
        var x = arg.indexOf('x');
        if (x != -1) {
          seasons = int.parse(arg.substring(x + 1));
          arg = arg.substring(0, x);
        }
        for (var j = 0; j < seasons; j++) {
          season = season! + 1;
          var count = int.parse(arg.substring(1));
          if (count > 99) throw Exception("Max 99 episodes per season");
          for (var i = 1; i <= count; i++) {
            codes.add((season * 100 + i).toString());
          }
        }
      } else if (RegExp(r'^\d+...\d+$').hasMatch(arg)) {
        var pieces = arg.split('...');
        var start = int.parse(pieces[0]);
        var end = int.parse(pieces[1]);
        season = end ~/ 100;
        for (var i = start; i <= end; i++) {
          codes.add('$i');
        }
      } else {
        codes.add(arg);
        var parsed = int.tryParse(arg);
        if (parsed != null) {
          season = parsed ~/ 100;
        } else {
          season = null;
        }
      }
    }
    return codes;
  }
}
