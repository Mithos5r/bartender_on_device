import 'package:flutter/widgets.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterEdgeAi.initialize(
    maxDownloadRetries: 5,
    inferenceEngines: const [LiteRtLmEngine()],
    webStorageMode: WebStorageMode.streaming,
  );

  runApp(const BartenderApp());
}
