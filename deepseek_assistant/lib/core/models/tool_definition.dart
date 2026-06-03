class ToolDefinition {
  final String type;
  final FunctionDefinition function;

  ToolDefinition({this.type = 'function', required this.function});

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'function': {
        'name': function.name,
        'description': function.description,
        'parameters': function.parameters,
      },
    };
  }
}

class FunctionDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  FunctionDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });
}
