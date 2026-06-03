import 'tool_registry.dart';

class CalculatorTool extends AiTool {
  @override
  String get name => 'calculate';

  @override
  String get description =>
      '执行数学计算。支持加(+)、减(-)、乘(*)、除(/)、幂(^)、取模(%)、括号等基本运算。';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'expression': {
            'type': 'string',
            'description': '要计算的数学表达式，如 "(2+3)*4" 或 "2^10"',
          },
        },
        'required': ['expression'],
      };

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    try {
      final expression = args['expression']?.toString() ?? '';
      if (expression.isEmpty) return '错误: 表达式为空';
      final sanitized =
          expression.replaceAll(RegExp(r'[^0-9+\-*/().%\s]'), '');
      if (sanitized.isEmpty) return '错误: 无效的表达式';
      final result = _evaluate(sanitized);
      if (result.isNaN) return '错误: 除数不能为零';
      return '计算结果: $expression = $result';
    } catch (e) {
      return '计算错误: $e';
    }
  }

  double _evaluate(String expr) {
    expr = expr.replaceAll(' ', '');
    return _parseExpression(expr);
  }

  double _parseExpression(String expr) {
    final tokens = <double>[];
    final ops = <String>[];
    int i = 0;

    while (i < expr.length) {
      final ch = expr[i];
      if (ch == ' ') {
        i++;
        continue;
      }
      if (_isDigit(ch) || ch == '.') {
        final start = i;
        while (i < expr.length && (_isDigit(expr[i]) || expr[i] == '.')) {
          i++;
        }
        tokens.add(double.parse(expr.substring(start, i)));
        continue;
      }
      if (ch == '(') {
        ops.add(ch);
      } else if (ch == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          _applyOp(tokens, ops.removeLast());
        }
        if (ops.isNotEmpty) ops.removeLast();
      } else if (_isOperator(ch)) {
        while (ops.isNotEmpty && _precedence(ops.last) >= _precedence(ch)) {
          _applyOp(tokens, ops.removeLast());
        }
        ops.add(ch);
      }
      i++;
    }

    while (ops.isNotEmpty) {
      _applyOp(tokens, ops.removeLast());
    }

    return tokens.isNotEmpty ? tokens.first : 0;
  }

  bool _isDigit(String ch) =>
      ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
  bool _isOperator(String ch) => '+-*/^%'.contains(ch);

  int _precedence(String op) {
    switch (op) {
      case '+':
      case '-':
        return 1;
      case '*':
      case '/':
      case '%':
        return 2;
      case '^':
        return 3;
      default:
        return 0;
    }
  }

  void _applyOp(List<double> values, String op) {
    if (values.length < 2) return;
    final b = values.removeLast();
    final a = values.removeLast();
    switch (op) {
      case '+':
        values.add(a + b);
      case '-':
        values.add(a - b);
      case '*':
        values.add(a * b);
      case '/':
        values.add(b != 0 ? a / b : double.nan);
      case '^':
        values.add(_pow(a, b));
      case '%':
        values.add(a % b);
    }
  }

  double _pow(double a, double b) {
    if (b == 0) return 1;
    double result = 1;
    for (int i = 0; i < b.toInt(); i++) {
      result *= a;
    }
    return result;
  }
}
