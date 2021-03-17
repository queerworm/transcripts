import 'dart:io';
import 'dart:convert';

extension StreamConversion on Stream<List<int>> {
  Stream<String> toLines() =>
      this.transform(utf8.decoder).transform(LineSplitter());
}

extension WriteLines on Stream<String> {
  Future<void> writeTo(StringSink output) async {
    await for (var line in this) {
      output.writeln(line);
    }
  }
}

extension OpenLines on File {
  Stream<String> openLines() => this.openRead().toLines();
}
