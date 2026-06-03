import 'tool_registry.dart';

class UnitConverterTool extends AiTool {
  @override
  String get name => 'convert_units';

  @override
  String get description =>
      '进行单位转换。支持长度、重量、温度、面积、体积、速度等常用单位。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'value': {
            'type': 'number',
            'description': '需要转换的数值',
          },
          'from_unit': {
            'type': 'string',
            'description':
                '源单位，如 "km"、"m"、"mile"、"kg"、"lb"、"celsius"、"fahrenheit"',
          },
          'to_unit': {
            'type': 'string',
            'description': '目标单位',
          },
        },
        'required': ['value', 'from_unit', 'to_unit'],
      };

  static final Map<String, double> _lengthToMeter = {
    'm': 1.0,
    'km': 1000.0,
    'cm': 0.01,
    'mm': 0.001,
    'mile': 1609.344,
    'yard': 0.9144,
    'foot': 0.3048,
    'inch': 0.0254,
  };

  static final Map<String, double> _weightToKg = {
    'kg': 1.0,
    'g': 0.001,
    'mg': 0.000001,
    'lb': 0.45359237,
    'oz': 0.0283495,
  };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final value = (args['value'] as num?)?.toDouble();
      if (value == null) return '错误: 请提供有效的数值';
      final fromUnit = (args['from_unit']?.toString() ?? '').toLowerCase();
      final toUnit = (args['to_unit']?.toString() ?? '').toLowerCase();
      if (fromUnit.isEmpty || toUnit.isEmpty) return '错误: 请提供源单位和目标单位';

      double result;

      if (fromUnit == 'celsius' && toUnit == 'fahrenheit') {
        result = value * 9 / 5 + 32;
      } else if (fromUnit == 'fahrenheit' && toUnit == 'celsius') {
        result = (value - 32) * 5 / 9;
      } else if (fromUnit == 'celsius' && toUnit == 'kelvin') {
        result = value + 273.15;
      } else if (fromUnit == 'kelvin' && toUnit == 'celsius') {
        result = value - 273.15;
      } else if (_lengthToMeter.containsKey(fromUnit) &&
          _lengthToMeter.containsKey(toUnit)) {
        result =
            value * _lengthToMeter[fromUnit]! / _lengthToMeter[toUnit]!;
      } else if (_weightToKg.containsKey(fromUnit) &&
          _weightToKg.containsKey(toUnit)) {
        result = value * _weightToKg[fromUnit]! / _weightToKg[toUnit]!;
      } else {
        return '不支持的单位转换: $fromUnit -> $toUnit';
      }

      return '$value $fromUnit = ${result.toStringAsFixed(4)} $toUnit';
    } catch (e) {
      return '单位转换错误: $e';
    }
  }
}
