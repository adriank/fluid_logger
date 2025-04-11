// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:developer';

import 'package:fluid_logger/src/colorify.dart';

class LogMessageData {
  const LogMessageData({
    required this.timestamp,
    required this.track,
    required this.fileRelativePath,
    required this.fileLink,
    required this.functionName,
    required this.lineNumber,
    required this.columnNumber,
    required this.message,
    required this.level,
  });

  final DateTime timestamp;
  final String? track;
  final String fileRelativePath;
  final String fileLink;
  final String functionName;
  final int lineNumber;
  final String message;
  final DebugLevel level;
  final int columnNumber;
}

String defaultMessageFormatter(LogMessageData message, LogMessageData? previousLogMessage) => '''
[${message.track}] ${message.timestamp.toString().split(' ')[1]} fn:${message.functionName} ${message.fileLink}
[${message.track}] ${message.message}''';

enum DebugLevel {
  debug,
  info,
  start,
  success,
  warning,
  error,
  off;

  @override
  String toString() => switch (this) {
        debug => 'DBG',
        info => 'INF',
        start => ' FN',
        success => 'SCC',
        warning => 'WRN',
        error => 'ERR',
        off => '',
      };

  String Function(String text) get colorify => switch (this) {
        debug => blue,
        info => cyan,
        start => white,
        success => green,
        warning => yellow,
        error => red,
        off => (String s) => s,
      };
}

enum Printer {
  developerLog,
  print,
  stdOut,
}

class FluidLogger {
  const FluidLogger({
    this.debugLevel = DebugLevel.error,
    this.cutAfter = 800,
    this.messageFormatter = globalMessageFormatter,
    this.track,
    this.forceDebugMessages = false,
    this.packageName = 'lib',
    this.kIsWeb = false,
    this.printer = Printer.print,
    this.kDebugMode = true,
  });

  static String pretty(dynamic object, {int indent = 2}) => JsonEncoder.withIndent(' ' * indent).convert(json);

  /// Provide package name from pubspec.yaml to get relative file paths.
  final String packageName;
  final Printer printer;

  final DebugLevel debugLevel;

  /// Cut long messages.
  final int? cutAfter;

  /// Set non-standard message formatter globally. Default is defined in [defaultMessageFormatter].
  /// WARNING! The line that contains fileLink shouldn't be too long. Otherwise console will not generate a clickable link.
  static const String Function(LogMessageData message, LogMessageData? previousLogMessage) globalMessageFormatter = defaultMessageFormatter;

  /// Set non-standard message formatter for this [track]. Default is defined in [defaultMessageFormatter].
  /// WARNING! The line that contains fileLink shouldn't be too long. Otherwise console will not generate a clickable link.
  final String Function(LogMessageData message, LogMessageData? previousLogMessage) messageFormatter;

  /// Used to distinguish between different loggers. E.g. 'Routing', 'UserRepository'.
  final String? track;

  /// This can be useful on web where no debug symbols from Flutter are available as of now.
  final bool forceDebugMessages;
  final bool kIsWeb;
  final bool kDebugMode;

  void _print(String Function() messageFn, {DebugLevel level = DebugLevel.debug}) {
    if (!shouldPrintDebug(level)) {
      return;
    }
    // If we're in production, there is no trace to read from.
    // if (!kDebugMode) {
    //   if (forceDebugMessages) {
    //     print(messageFn());
    //   }
    //   return;
    // }

    final (trace, previousTrace) = _getTraceData();
    final message = switch (level) {
      DebugLevel.start => '${trace.functionName}(${messageFn()})',
      _ => messageFn(),
    };
    final shouldCut = cutAfter != null && cutAfter! < message.length;
    final logMessage = LogMessageData(
      timestamp: DateTime.now(),
      track: track,
      fileRelativePath: (trace.fileName.split(packageName)..removeAt(0)).join(packageName),
      fileLink: trace.link,
      functionName: trace.functionName,
      lineNumber: trace.lineNumber,
      columnNumber: trace.columnNumber,
      message: (shouldCut ? '${message.substring(0, cutAfter)}...(cut)' : message).trim(),
      level: level,
    );
    final previousLogMessage = previousTrace == null
        ? null
        : LogMessageData(
            timestamp: DateTime.now(),
            track: track,
            fileRelativePath: (previousTrace.fileName.split(packageName)..removeAt(0)).join(packageName),
            fileLink: previousTrace.link,
            functionName: previousTrace.functionName,
            lineNumber: previousTrace.lineNumber,
            columnNumber: previousTrace.columnNumber,
            message: (shouldCut ? '${message.substring(0, cutAfter)}...(cut)' : message).trim(),
            level: level,
          );
    final toPrint = messageFormatter(logMessage, previousLogMessage);
    if (kDebugMode) {
      // TODO refactor ifs

      for (var e in toPrint.split('\n')) {
        if (e.contains(logMessage.fileLink)) {
          e = e.replaceAll(logMessage.fileLink, '');
          // if (e.length + logMessage.fileLink.length > 1500) {
          //   log(
          //     level.colorify(e),
          //     level: 0,
          //     name: level.toString(),
          //   );
          //   log(
          //     logMessage.fileLink,
          //     level: 0,
          //     name: level.toString(),
          //   );
          //   continue;
          // }
          // final printString = '[${level.colorify(level.toString())}] ${level.colorify(e)} ${logMessage.fileLink}';
          final printString = '${level.colorify(e)} ${logMessage.fileLink}';
          switch (printer) {
            case Printer.print:
              print(printString);
            case _:
              log(
                printString,
                name: level.colorify(level.toString()),
                time: DateTime.now(),
                // sequenceNumber: r * 2,
              );
          }
        } else {
          // final printString = '[${level.colorify(level.toString())}] ${level.colorify(e)}';
          final printString = level.colorify(e);
          switch (printer) {
            case Printer.print:
              print(printString);
            case _:
              log(
                printString,
                name: level.colorify(level.toString()),
                time: DateTime.now(),
                // sequenceNumber: r * 2,
              );
          }
        }
      }
    } else {
      print(toPrint);
    }
  }

  (_Frame current, _Frame? previous) _getTraceData() {
    final s = StackTrace.current;
    return (
      _CustomTrace.fromStackTrace(s, kIsWeb: kIsWeb, kDebugMode: kDebugMode).currentCall,
      _CustomTrace.fromStackTrace(s, kIsWeb: kIsWeb, kDebugMode: kDebugMode).previousCall,
    );
  }

  /// Print information about current function. Takes a list of function arguments. The log message level is 'info'.
  void start([List<dynamic>? arguments]) => _print(
        () => (arguments ?? []).map((e) => e.toString()).join(', \n'),
        level: DebugLevel.start,
      );

  /// The most granular messages. Should be printed only when feature needs to be thoughtfully debugged.
  void debug(String Function() message) => _print(message);

  /// Information that is more general than debug level.
  void info(String Function() message) => _print(message, level: DebugLevel.info);

  /// Message that requires attention of a developer.
  void warning(String Function() message) => _print(message, level: DebugLevel.warning);

  /// Indicates success of an operation. Should be used after successful data retrieval from server, database etc.
  void success(String Function() message) => _print(message, level: DebugLevel.success);

  /// Indicates error of an operation. Should be used after unsuccessful data retrieval from server, database etc.
  void error(String Function() message) => _print(message, level: DebugLevel.error);

  /// Whether log message. Checks for forceDebugMessages, kDebugMode, and log level.
  bool shouldPrintDebug(DebugLevel level) => (forceDebugMessages || kDebugMode) && DebugLevel.values.indexOf(level) >= DebugLevel.values.indexOf(debugLevel);
}

class _Frame {
  const _Frame({
    required this.fileName,
    required this.link,
    required this.functionName,
    required this.columnNumber,
    required this.lineNumber,
  });

  final String fileName;
  final String link;
  final String functionName;
  final int lineNumber;
  final int columnNumber;

  @override
  String toString() => '''
fileName: $fileName
link: $link
functionName: $functionName
lineNumber: $lineNumber
columnNumber: $columnNumber
''';
}

class _CustomTrace {
  _CustomTrace({
    required this.currentCall,
    this.previousCall,
  });

  factory _CustomTrace.fromStackTrace(StackTrace trace, {bool kIsWeb = false, required bool kDebugMode}) {
    // print('start _CustomTrace.fromStackTrace');
    final frames = trace.toString().split('\n');
    // print('frames:');
    // frames.indexed.forEach(print);
    final startIndex = switch ((kIsWeb, kDebugMode)) {
      (true, false) => 6,
      (true, true) => 4,
      _ => 3,
    };
    return _CustomTrace(
      currentCall: _readFrame(
        frames[startIndex],
        kIsWeb: kIsWeb,
        kDebugMode: kDebugMode,
      ),
      previousCall: (frames.length >= startIndex + 1)
          ? _readFrame(
              frames[startIndex + 1],
              kIsWeb: kIsWeb,
              kDebugMode: kDebugMode,
            )
          : null,
    );
  }

  _Frame currentCall;
  _Frame? previousCall;

  static _Frame _readFrame(
    String frame, {
    bool kIsWeb = false,
    required bool kDebugMode,
  }) {
    // print('start _CustomTrace._readFrame, $frame');
    if (frame == '<asynchronous suspension>') {
      return const _Frame(
        fileName: '?',
        link: '',
        lineNumber: 0,
        functionName: '?',
        columnNumber: 0,
      );
    }
    final parts = frame.replaceAll('<anonymous closure>', 'anonymous').replaceAll('<anonymous, closure>', 'anonymous').split(' ').where((element) => element.isNotEmpty && element != 'new').toList();
    // print('parts: $parts');
    // print('kIsWeb: $kIsWeb, kDebugMode: $kDebugMode');
    if (kIsWeb) {
      try {
        final [int line, int column] = switch (kDebugMode) {
          true => parts[2].substring(1, parts[2].length - 1).split(':').reversed.take(2).map<int>(int.parse).toList().reversed.toList(),
          false => parts[1].split(':').map<int>(int.parse).toList(),
        };
        // print('line: ${parts[0]}:${parts[1]}');
        return _Frame(
          fileName: parts[0],
          link: '${parts[0]}:${parts[1]}',
          lineNumber: line,
          functionName: parts[2].split('.anony')[0].split('(')[0].replaceAll('<fn>', 'anonymous fn'),
          columnNumber: column,
        );
      } catch (e) {
        // print(e);
        return const _Frame(
          fileName: '?',
          link: '',
          lineNumber: 0,
          functionName: '?',
          columnNumber: 0,
        );
      }
    }
    List<String> listOfInfos = ['', '', '0', '0'];

    try {
      final temp = parts[2].replaceAll('(', '').replaceAll(')', '').split(':');
      if (temp.length == listOfInfos.length) {
        listOfInfos = temp;
      } else {
        listOfInfos[0] = parts[2];
      }
    } catch (_) {}

    return _Frame(
      fileName: listOfInfos[1],
      link: parts[2],
      lineNumber: int.parse(listOfInfos[2]),
      functionName: parts[1].split('.anony')[0].split('(')[0],
      columnNumber: int.parse(listOfInfos[3].replaceFirst(')', '')),
    );
  }
}
