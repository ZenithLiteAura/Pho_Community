import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

final logger = LoggerService();

class LoggerService {
  final List<String> _logs = [];

  void addLog(String log) {
    DateFormat format = DateFormat("yyyy-MM-dd HH:mm:ss");
    final logStr = "[${format.format(DateTime.now())}] $log";
    _logs.add(logStr);
    print(logStr);
  }

  List<String> get logs => _logs;

  // Future<void> downloadLogs() async {
  //   final logs = _logs.join('\n');
  //   final directory = await getApplicationDocumentsDirectory();
  //   final file = File('${directory.path}/log.txt');
  //   await file.writeAsString(logs);
  // }
}

class LoggerRoute extends StatefulWidget {
  const LoggerRoute({Key? key}) : super(key: key);

  @override
  _LoggerRouteState createState() => _LoggerRouteState();
}

class _LoggerRouteState extends State<LoggerRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final logs = logger.logs.join('\n');
              await Clipboard.setData(ClipboardData(text: logs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: logger.logs.length,
        itemBuilder: (context, index) {
          return Container(
            padding: EdgeInsets.fromLTRB(10, 1, 10, 1),
            child: Text(logger.logs[index]),
          );
        },
      ),
    );
  }
}
