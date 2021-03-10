import 'dart:convert';
import 'dart:io';

main() async {
  var build = Directory('build');
  if (await build.exists()) {
    await build.delete(recursive: true);
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
      await Directory('build/$showId').create();
      manifests[showId] = Manifest.fromFile(File('srt/$showId/manifest.json'));
    }
  }

  await File('templates/index.html').copy('build/index.html');

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
            .replaceAll('{{episode}}', episode.title)
            .replaceAll('{{show}}', manifest.title)
            .replaceAll('{{netflix}}',
                'https://www.netflix.com/watch/${episode.netflixId}?t=0')
            .replaceAll('{{transcript}}', srtToHtml(srt, episode));
        await File('build/$showId/${episode.code}.html').writeAsString(html);
      }
    }
    var index = showTemplate
        .replaceAll('{{show}}', manifest.title)
        .replaceAll('{{episodes}}', makeEpisodeList(manifest, available));
    await File('build/$showId/index.html').writeAsString(index);
  }
}

final manifests = <String, Manifest>{};

class Manifest {
  final String title;
  final String netflixId;
  final List<Episode> episodes;

  Manifest._(this.title, this.netflixId, this.episodes);

  factory Manifest(dynamic json) {
    var episodes = json['episodes'] as Map<String, dynamic>? ?? {};
    return Manifest._(json['title'], json['netflix'], [
      for (var entry in episodes.entries)
        Episode(entry.key, entry.value, json['netflix_offset'] ?? 0)
    ]);
  }

  factory Manifest.fromFile(File manifest) {
    return Manifest(json.decode(manifest.readAsStringSync()));
  }
}

class Episode {
  final String code;
  final String title;
  final int season;
  final int episode;
  final String netflixId;
  final int netflixOffset;

  Episode._(this.code, this.title, this.season, this.episode, this.netflixId,
      this.netflixOffset);

  factory Episode(String code, dynamic json, int globalOffset) {
    int season =
        json['season'] ?? int.parse(code.substring(0, code.length - 2));
    int episode = json['episode'] ?? int.parse(code.substring(code.length - 2));
    return Episode._(code, json['title'], season, episode, json['netflix'],
        json['netflix_offset'] ?? globalOffset);
  }
}

bool combineLowercaseWithPrevious = true;

String srtToHtml(File srt, Episode episode) {
  var lines = srt.readAsLinesSync();
  var html = <String>[];
  var expect = 'counter';
  for (var line in lines) {
    switch (expect) {
      case 'counter':
        expect = 'time';
        break;
      case 'time':
        html.add(timeToLink(line.split('-->')[0].trim(), episode));
        html.add('<p>');
        expect = 'firsttext';
        break;
      default:
        // If the first text starts with a lowercase letter, assume it's a
        // continuation of the previous line (this doesn't work for all-caps
        // lines, but oh well)
        if (expect == 'firsttext' &&
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

String timeToLink(String timeString, Episode episode) {
  var intTime = timeString.split(',').first;
  var pieces = intTime.split(':');
  var time = int.parse(pieces[0]) * 60 * 60 +
      int.parse(pieces[1]) * 60 +
      int.parse(pieces[2]);
  var adj = time + episode.netflixOffset;
  return '<a href="https://www.netflix.com/watch/${episode.netflixId}?t=$adj" '
      'class="timestamp" target="_blank" data-time="$time">$intTime</a>\n';
}

String makeEpisodeList(Manifest manifest, Set<String> available) {
  var html = '';
  var seasons = <int, List<Episode>>{};
  for (var episode in manifest.episodes) {
    seasons.putIfAbsent(episode.season, () => []).add(episode);
  }
  for (var entry in seasons.entries) {
    var season = entry.key;
    html += '<h4>Season ${season}</h4>\n';
    for (var episode in entry.value) {
      var text = 'Episode ${episode.episode} - ${episode.title}';
      if (available.contains(episode.code)) {
        text = '<a href="${episode.code}.html">$text</a>';
      }
      html += '$text<br/>\n';
    }
  }
  return html;
}
