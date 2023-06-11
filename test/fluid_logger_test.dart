import 'package:fluid_logger/fluid_logger.dart';
import 'package:flutter_test/flutter_test.dart';

const log = FluidLogger(
  debugLevel: DebugLevel.debug,
  track: 'TEST',
  packageName: 'fluid_logger',
);

void main() {
  test('prints', () async {
    log.start();
    log.debug('debug');
    log.info('info');
    log.warning('warning');
    log.success('success');
    log.error('error');
    await Future.delayed(const Duration(seconds: 1));
  });
}
