import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';

class BuildCommand extends Command {
  final name = "build";
  final description = "Builds the website (or part of it)";

  run() async {
    var args = argResults?.rest ?? [];
    var build = Directory('build');
    if (args.isEmpty) {
      if (await build.exists()) {
        await build.delete(recursive: true);
      }
    }
    await build.create();
    await Directory('build/assets').create();
    await for (var item in Directory('assets').list()) {
      if (item is File) {
        await item.copy('build/${item.path}');
      }
    }

    await for (var item in Directory('srt').list()) {
      if (item is Directory) {
        var showId = item.path.split('/').last;
        var showBuild = Directory('build/$showId');
        if (args.isEmpty) {
          await showBuild.create();
        } else if (args.contains(showId)) {
          if (await showBuild.exists()) await showBuild.delete(recursive: true);
          await showBuild.create();
        } else {
          continue;
        }
        manifests[showId] =
            _Manifest.fromFile(File('srt/$showId/manifest.json'));
      }
    }

    if (args.isEmpty) {
      var indexTemplate = await File('templates/index.html').readAsString();
      await File('build/index.html').writeAsString(indexTemplate.replaceAll(
          '{{shows}}',
          [
            for (var entry in manifests.entries.toList()..sort(_compareTitles))
              "<li><a href='${entry.key}'>${entry.value.title}</a></li>"
          ].join('\n  ')));
    }

    var template = await File('templates/transcript.html').readAsString();
    var showTemplate = await File('templates/show.html').readAsString();
    for (var entry in manifests.entries) {
      var showId = entry.key;
      var manifest = entry.value;
      var available = <String>{};
      for (var episode in manifest.episodes) {
        var srt = File('srt/$showId/${episode.code}.srt');
        if (await srt.exists()) {
          available.add(episode.code);
          var html = template
              .replaceAll(
                  '{{episode}}',
                  episode.title ??
                      "Season ${episode.season}, Episode ${episode.episode}")
              .replaceAll('{{show}}', manifest.title)
              .replaceAll('{{netflix}}',
                  'https://www.netflix.com/watch/${episode.netflixId}?t=0')
              .replaceAll('{{transcript}}', _srtToHtml(srt, episode));
          await File('build/$showId/${episode.code}.html').writeAsString(html);
        }
      }
      var index = showTemplate
          .replaceAll('{{show}}', manifest.title)
          .replaceAll('{{episodes}}', _makeEpisodeList(manifest, available));
      await File('build/$showId/index.html').writeAsString(index);
    }

    print('Build successful');
  }

  final manifests = <String, _Manifest>{};

  int _compareTitles(
      MapEntry<String, _Manifest> a, MapEntry<String, _Manifest> b) {
    var titleA = a.value.title;
    var titleB = b.value.title;
    if (titleA.startsWith('The ')) titleA = titleA.substring(4);
    if (titleB.startsWith('The ')) titleB = titleB.substring(4);
    return titleA.compareTo(titleB);
  }

  bool combineLowercaseWithPrevious = true;

  String _srtToHtml(File srt, _Episode episode) {
    var lines = srt.readAsLinesSync();
    var html = <String>[];
    var expect = 'counter';
    for (var line in lines) {
      switch (expect) {
        case 'counter':
          expect = 'time';
          break;
        case 'time':
          html.add(_timeToLink(line.split('-->')[0].trim(), episode));
          html.add('<p>');
          expect = 'firsttext';
          break;
        default:
          // If the first text starts with a lowercase letter, assume it's a
          // continuation of the previous line (this doesn't work for all-caps
          // lines, but oh well)
          if (html.length > 3 &&
              expect == 'firsttext' &&
              combineLowercaseWithPrevious &&
              line.startsWith(RegExp('[a-z]', caseSensitive: true))) {
            html.removeLast();
            html.removeLast();
            html.removeLast();
          }
          if (line.trim().isEmpty) {
            expect = 'counter';
            html.add('</p>');
          } else {
            expect = 'text';
            html.add('$line\n');
          }
          break;
      }
    }
    return html.join('\n');
  }

  String _timeToLink(String timeString, _Episode episode) {
    var intTime = timeString.split(',').first;
    var pieces = intTime.split(':');
    var time = int.parse(pieces[0]) * 60 * 60 +
        int.parse(pieces[1]) * 60 +
        int.parse(pieces[2]);
    var adj = time + episode.netflixOffset;
    return '<a href="https://www.netflix.com/watch/${episode.netflixId}?t=$adj" '
        'class="timestamp" target="_blank" data-time="$time">$intTime</a>\n';
  }

  String _makeEpisodeList(_Manifest manifest, Set<String> available) {
    var html = '';
    var seasons = <String, List<_Episode>>{};
    for (var episode in manifest.episodes) {
      seasons.putIfAbsent(episode.season, () => []).add(episode);
    }
    for (var entry in seasons.entries) {
      var season = entry.key;
      html += '<h4>$season</h4>\n';
      for (var episode in entry.value) {
        String text;
        if (episode.episode == null && episode.title == null) {
          throw Exception(
              'All episodes must have an episode number and/or a title.');
        } else if (episode.episode == null) {
          text = episode.title!;
        } else {
          text = 'Episode ${episode.episode}';
          if (episode.title != null) text += ' - ${episode.title}';
        }
        if (available.contains(episode.code)) {
          text = '<a href="${episode.code}.html">$text</a>';
        }
        html += '$text<br/>\n';
      }
    }
    return html;
  }
}

class _Manifest {
  final String title;
  final String netflixId;
  final List<_Episode> episodes;

  _Manifest._(this.title, this.netflixId, this.episodes);

  factory _Manifest(dynamic json) {
    var episodes = json['episodes'] as Map<String, dynamic>? ?? {};
    return _Manifest._(json['title'], json['netflix'], [
      for (var entry in episodes.entries)
        _Episode(entry.key, entry.value, json['netflix_offset'] ?? 0)
    ]);
  }

  factory _Manifest.fromFile(File manifest) {
    return _Manifest(json.decode(manifest.readAsStringSync()));
  }
}

class _Episode {
  final String code;
  final String? title;
  final String season;
  final int? episode;
  final String netflixId;
  final int netflixOffset;

  _Episode._(this.code, this.title, this.season, this.episode, this.netflixId,
      this.netflixOffset);

  factory _Episode(String code, dynamic json, int globalOffset) {
    var season =
        json['season'] ?? 'Season ${code.substring(0, code.length - 2)}';
    int? episode =
        json['episode'] ?? int.tryParse(code.substring(code.length - 2));
    return _Episode._(code, json['title'], season, episode, json['netflix'],
        json['netflix_offset'] ?? globalOffset);
  }
}
