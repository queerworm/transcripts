import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

class ServeCommand extends Command {
  final name = 'serve';
  final description = 'Runs a web server for the build directory';

  @override
  final argParser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080')
    ..addOption('host', abbr: 'H', defaultsTo: '0.0.0.0');

  run() {
    var port = int.parse(argResults!['port']);
    var host = argResults!['host'] as String;

    var handler = createStaticHandler('build', defaultDocument: 'index.html');
    io.serve(handler, host, port);
    print('Hosting build directory at $host:$port');
  }
}
