import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/storage/local_storage_service.dart';
import 'core/tools/tool_registry.dart';
import 'core/tools/tool_calculator.dart';
import 'core/tools/tool_weather.dart';
import 'core/tools/tool_translate.dart';
import 'core/tools/tool_unit_converter.dart';
import 'core/tools/tool_web_search.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalStorageService.init();

  ToolRegistry.instance.registerAll([
    CalculatorTool(),
    WeatherTool(),
    TranslateTool(),
    UnitConverterTool(),
    WebSearchTool(),
  ]);

  runApp(const ProviderScope(child: DeepSeekApp()));
}
