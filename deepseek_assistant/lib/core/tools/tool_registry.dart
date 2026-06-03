import '../models/tool_definition.dart';

abstract class AiTool {
  String get name;
  String get description;
  Map<String, dynamic> get parameters;

  Future<String> execute(Map<String, dynamic> args);

  ToolDefinition toDefinition() {
    return ToolDefinition(
      function: FunctionDefinition(
        name: name,
        description: description,
        parameters: parameters,
      ),
    );
  }
}

class ToolRegistry {
  final Map<String, AiTool> _tools = {};

  static final ToolRegistry instance = ToolRegistry._();
  ToolRegistry._();

  void registerAll(List<AiTool> tools) {
    for (final tool in tools) {
      _tools[tool.name] = tool;
    }
  }

  AiTool? getTool(String name) => _tools[name];

  List<ToolDefinition> getDefinitions() {
    return _tools.values.map((t) => t.toDefinition()).toList();
  }

  bool get hasTools => _tools.isNotEmpty;
}
