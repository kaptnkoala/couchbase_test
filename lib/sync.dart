import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:cbl_flutter_ee/cbl_flutter_ee.dart';
import 'package:path_provider/path_provider.dart';

Future<void> testSync() async {
  CblFlutterEe.registerWith();
  await CouchbaseLiteFlutter.init();
  Database.log.custom = DartConsoleLogger(LogLevel.verbose);

  final appDir = await getApplicationSupportDirectory();
  final db = await Database.openAsync(
    'test',
    DatabaseConfiguration(directory: appDir.path),
  );

  /*final repl = await db.createReplicator(ReplicatorConfiguration(
    endpoint: UrlEndpoint(Uri.parse('wss://4pics-db-prod.lotum.com/user')),
    authenticator: BasicAuthenticator(username: 'test_user', password: 'Q9ECh2Z7RP6LqzFr'),
    channels: ['user:677482'],
  ));

  var doc = MutableDocument();

  await for (final i in Stream.periodic(const Duration(seconds: 2), (i) => i)) {
    doc.properties['i'] = i;
    doc = (await db.saveDocument(doc)).mutableCopy();
    await repl.start();
  }*/
}
