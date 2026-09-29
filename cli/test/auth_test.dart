import 'dart:io';
import 'dart:convert';
import 'package:test/test.dart';
import '../src/auth.dart';
import '../bin/portfolio.dart' show parser;

void main() {
  test('credential state is private and atomically replaceable', () async {
    final dir = await Directory.systemTemp.createTemp('portfolio-cli-test-');
    addTearDown(() => dir.delete(recursive: true));
    final state = LocalState('${dir.path}/state');
    await state.write('auth', {'refresh_token': 'fake-old'});
    await state.write('auth', {'refresh_token': 'fake-new'});
    expect((await state.read('auth'))['refresh_token'], 'fake-new');
    expect(await state.directory.list().length, 1);
    if (!Platform.isWindows) {
      expect((await state.directory.stat()).mode & 0x1ff, 0x1c0);
      expect((await state.file('auth').stat()).mode & 0x1ff, 0x180);
    }
  });
  test('web OAuth client is rejected before starting login', () async {
    final dir = await Directory.systemTemp.createTemp('portfolio-cli-auth-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/client.json');
    await file.writeAsString(
      jsonEncode({
        'web': {'client_id': 'test'},
      }),
    );
    await expectLater(
      GoogleAuth(LocalState('${dir.path}/state')).login(file.path),
      throwsFormatException,
    );
    expect(await Directory('${dir.path}/state').exists(), false);
  });
  test('parser rejects misspelled write flags and delete field edits', () {
    expect(
      () => parser().parse(['trade', 'add', '--aply']),
      throwsFormatException,
    );
    expect(
      () => parser().parse(['trade', 'delete', '--price', '1']),
      throwsFormatException,
    );
    final args = parser().parse(['trade', 'add', '--quantity', '1', '--apply']);
    expect(args.command!.command!['apply'], true);
  });
}
