// ignore_for_file: avoid_print
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'package:fluid_logger/src/colorify.dart';

@immutable
class LogMessage {
  const LogMessage({
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

String defaultMessageFormatter(LogMessage message) => '[${message.track}] ${message.timestamp.toString().split(' ')[1]} ${message.fileRelativePath}:${message.functionName}:${message.lineNumber} (${message.fileLink}:${message.lineNumber}:${message.columnNumber})\n${message.message}';

enum DebugLevel {
  debug,
  info,
  success,
  warning,
  error,
  off;

  @override
  String toString() => switch (this) {
        debug => 'DBG',
        info => 'INF',
        success => 'SCC',
        warning => 'WRN',
        error => 'ERR',
        off => '',
      };

  String Function(String text) get colorify => switch (this) {
        debug => blue,
        info => white,
        success => green,
        warning => yellow,
        error => red,
        off => (String s) => s,
      };
}

@immutable
class FluidLogger {
  const FluidLogger({
    this.debugLevel = DebugLevel.error,
    this.cutAfter = 800,
    this.messageFormatter = globalMessageFormatter,
    this.track,
    this.forceDebugMessages = false,
    this.packageName = 'lib',
  });

  /// Provide package name from pubspec.yaml to get relative files paths.
  final String packageName;

  final DebugLevel debugLevel;

  /// Cut long messages.
  final int? cutAfter;

  /// Set non-standard message formatter globally. Default is defined in [defaultMessageFormatter].
  static const String Function(LogMessage message) globalMessageFormatter = defaultMessageFormatter;

  /// Set non-standard message formatter for this [track]. Default is defined in [defaultMessageFormatter].
  final String Function(LogMessage message) messageFormatter;

  /// Used to distinguish between different loggers. E.g. 'Routing', 'UserRepository'.
  final String? track;

  /// This can be useful on web where no debug symbols from Flutter are available as of now.
  final bool forceDebugMessages;

  void _print(String message, {DebugLevel level = DebugLevel.debug}) {
    if (!shouldPrintDebug(level)) {
      return;
    }
    if (kIsWeb) {
      _printWeb();
      return;
    }
    final trace = _getTraceData();
    final shouldCut = cutAfter == null ? false : cutAfter! < message.length;
    final logMessage = LogMessage(
      timestamp: DateTime.now(),
      track: track,
      fileRelativePath: (trace.fileName.split(packageName)..removeAt(0)).join(packageName),
      fileLink: 'file:${trace.fileName}',
      functionName: trace.functionName,
      lineNumber: trace.lineNumber,
      columnNumber: trace.columnNumber,
      message: ((shouldCut ? '${message.substring(0, cutAfter)}...(cut)' : message)).trim(),
      level: level,
    );
    final toPrint = messageFormatter(logMessage);
    if (kDebugMode) {
      debugPrint(toPrint.split('\n').map((e) => level.colorify(e)).join('\n'));
      // log(
      //   toPrint.split('\n').map((e) => level.colorify(e)).join('\n'),
      //   level: 0,
      //   name: level.toString(),
      // );
    } else {
      print(toPrint);
    }
  }

  void _printWeb() {
    try {
      throw Exception();
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  _Frame _getTraceData() {
    try {
      throw Exception();
    } catch (e, s) {
      return _CustomTrace.fromStackTrace(s).currentCall;
    }
  }

  /// Print information about current function. Takes a list of function arguments. The log message level is 'info'.
  start([List<dynamic>? arguments]) => _print('with: ${arguments?.map((e) => e.toString()).join(', ') ?? '(no arguments)'}', level: DebugLevel.info);

  /// The most granular messages. Should be printed only when feature needs to be thoughtfully debugged.
  debug(String message) => _print(message, level: DebugLevel.debug);

  /// Information that is more general than debug level.
  info(String message) => _print(message, level: DebugLevel.info);

  /// Message that requires attention of a developer.
  warning(String message) => _print(message, level: DebugLevel.warning);

  /// Indicates success of an operation. Should be used after successful data retrieval from server, database etc.
  success(String message) => _print(message, level: DebugLevel.success);

  /// Indicates error of an operation. Should be used after unsuccessful data retrieval from server, database etc.
  error(String message) => _print(message, level: DebugLevel.error);

  /// Whether log message. Checks for forceDebugMessages, kDebugMode, and log level.
  bool shouldPrintDebug(DebugLevel level) => forceDebugMessages || kDebugMode && DebugLevel.values.indexOf(level) >= DebugLevel.values.indexOf(debugLevel);
}

class _Frame {
  _Frame({
    required this.fileName,
    required this.functionName,
    required this.columnNumber,
    required this.lineNumber,
  });
  late String fileName;
  late String functionName;
  late int lineNumber;
  late int columnNumber;
}

class _CustomTrace {
  _Frame currentCall;
  _Frame? previousCall;

  _CustomTrace({required this.currentCall, this.previousCall});

  factory _CustomTrace.fromStackTrace(StackTrace trace) {
    final frames = trace.toString().split('\n');
    return _CustomTrace(
      currentCall: _readFrame(frames[3]),
      previousCall: (frames.length >= 4) ? _readFrame(frames[4]) : null,
    );
  }

  static _Frame _readFrame(String frame) {
    if (frame == '<asynchronous suspension>') {
      return _Frame(
        fileName: '?',
        lineNumber: 0,
        functionName: '?',
        columnNumber: 0,
      );
    }
    final parts = frame.replaceAll(r'<anonymous closure>', 'anonymous').replaceAll(r'<anonymous, closure>', 'anonymous').split(' ').where((element) => element.isNotEmpty && element != 'new').toList();
    // print(parts);
    List<String> listOfInfos = ['', '', '0', '0'];
    try {
      listOfInfos = parts[2].split(':');
    } catch (_) {}
    return _Frame(
      fileName: listOfInfos[1],
      lineNumber: int.parse(listOfInfos[2]),
      functionName: parts[1].split('.anony')[0].split('(')[0],
      columnNumber: int.parse(listOfInfos[3].replaceFirst(')', '')),
    );
  }
}
