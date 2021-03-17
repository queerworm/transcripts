import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:xml/xml.dart';

class SrtCommand extends Command {
  final name = 'srt';
  final description = 'Converts Netflix subtitles to SRT';

  String convertString(String netflixSubs) {
    var buffer = StringBuffer();
    convert(netflixSubs, buffer);
    return buffer.toString();
  }

  void convert(String netflixSubs, StringSink output) {
    var document = XmlDocument.parse(netflixSubs);
    var count = 1;
    var italicized = {
      for (var el in document.findAllElements('style'))
        if (el.getAttribute('tts:fontStyle') == 'italic')
          el.getAttribute('xml:id')
    };
    for (var p in document.findAllElements('p')) {
      if (count != 1) output.writeln();
      var line = '';
      for (var child in p.children) {
        if (child is XmlText) {
          line += child.text;
        } else if (child is XmlElement) {
          if (child.name.local == 'br') {
            line += '\n';
          } else if (child.name.local == 'span' &&
              italicized.contains(child.getAttribute('style'))) {
            line += '<i>${child.text}</i>';
          } else {
            line += child.text;
          }
        }
      }
      if (italicized.contains(p.getAttribute('style'))) {
        line = '<i>$line</i>';
      }
      var start = _timestamp(p.getAttribute('begin')!);
      var end = _timestamp(p.getAttribute('end')!);
      output.writeln(count++);
      output.writeln('$start --> $end');
      output.writeln(line);
    }
  }

  String _timestamp(String netflix) {
    var time = int.parse(netflix.substring(0, netflix.length - 5));
    var ms = _intStr(time % 1000, 3);
    var s = _intStr((time ~/ 1000) % 60, 2);
    var m = _intStr((time ~/ 60000) % 60, 2);
    var h = _intStr(time ~/ 3600000, 2);
    return '$h:$m:$s,$ms';
  }

  String _intStr(int input, int digits) {
    var str = '$input';
    return '0' * (digits - str.length) + str;
  }

  @override
  final argParser = ArgParser()
    ..addOption('input', abbr: 'i')
    ..addOption('output', abbr: 'o');

  run() async {
    String? input = argResults!['input'];
    String? output = argResults!['output'];
    String inText;
    if (input != null) {
      inText = await File(input).readAsString();
    } else {
      inText = await utf8.decodeStream(stdin);
    }
    if (output != null) {
      var sink = File(output).openWrite();
      convert(inText, sink);
      await sink.close();
    } else {
      convert(inText, stdout);
    }
  }
}
