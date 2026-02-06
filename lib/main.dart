import 'package:flutter/material.dart';

void main() {
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String display = '';
  bool _lastWasResult = false;


  void onButtonPressed(String value) {
    setState(() {
      // Limpiar si hay error y se presiona un número, punto o operador
      // Si el último fue resultado y se presiona número/punto → nueva operación
      if (_lastWasResult) {
        if (RegExp(r'[0-9.]').hasMatch(value)) {
          display = '';
        }
        _lastWasResult = false;
      }


      if (display == 'Error') {
        if (value == 'C' || value == '⌫' || value == '=') {
          // Permitir estos
        } else if (_isOperator(value)) {
          return;  // Ignorar operadores después de Error
        } else {
          display = '';  // Limpiar para números o punto
        }
      }

      if (value == 'C') {
        display = '';
        return;
      }

      if (value == '⌫') {  // Borrar último carácter
        if (display.isNotEmpty) {
          display = display.substring(0, display.length - 1);
        }
        return;
      }

      if (value == '=') {
        try {
          double result = evaluateExpression(display);
          display = result
              .toStringAsFixed(8)
              .replaceAll(RegExp(r'\.?0+$'), '');

          _lastWasResult = true; // marcar resultado
        } catch (e) {
          display = 'Error';
          _lastWasResult = false;
        }
        return;
      }


      // Evitar ceros líderes en números
      if (value == '0') {
        String currentNum = _getCurrentNumber(display);
        if (currentNum.startsWith('0') && !currentNum.contains('.')) {
          return;  // No agregar si ya empieza con 0 y no decimal
        }
      }

      // Evitar puntos duplicados o inválidos
      if (value == '.') {
        if (display.isEmpty || _lastTokenIsOperator(display)) {
          display += '0.';  // Agregar 0. si empieza con punto
          return;
        }
        String currentNum = _getCurrentNumber(display);
        if (currentNum.contains('.')) {
          return;  // No permitir . duplicado en el número actual
        }
      }

      // Evitar operadores consecutivos (excepto después de paréntesis)
      if (_isOperator(value)) {
        if (display.isEmpty && value != '-') return;

        if (display.isNotEmpty &&
            _isOperator(display[display.length - 1]) &&
            value != '-') return;
      }


      // Manejar paréntesis balanceados
      if (value == ')') {
        if (!_canCloseParenthesis(display)) {
          return;  // No permitir ')' si no hay '(' abierto
        }
      }

      if (display.isNotEmpty) {
        String last = display[display.length - 1];

        // Bloquear paréntesis vacío: "()"
        if (value == ')' && last == '(') {
          return;
        }

        // Bloquear iniciar con ")"
        if (value == ')' && display.isEmpty) {
          return;
        }
      }

      // Reemplazar 0 líder con dígito no cero
      if (RegExp(r'[1-9]').hasMatch(value) && !display.isEmpty && !_lastTokenIsOperator(display) && _currentNumberHasLeadingZero(display)) {
        // Reemplazar el 0 líder con el nuevo dígito (ej: 0 -> 3, no 03)
        int lastOpIndex = display.lastIndexOf(RegExp(r'[+\-*/()]')) + 1;
        display = display.substring(0, lastOpIndex) + value;
        return;
      }

      // Agregar el valor (números, operadores, paréntesis)
      if (display == '0' && !_isOperator(value) && value != '.' && value != '(' && value != ')') {
        display = value;  // Reemplazar 0 inicial con número
      } else {
        display += value;
      }
    });
  }

  bool _isOperator(String char) {
    return char == '+' || char == '-' || char == '*' || char == '/';
  }

  bool _lastTokenIsOperator(String str) {
    if (str.isEmpty) return false;
    String last = str[str.length - 1];
    return _isOperator(last) || last == '(' || last == ')';
  }

  bool _currentNumberHasLeadingZero(String str) {
    // Verificar si el número actual empieza con 0 y no es decimal
    String currentNum = _getCurrentNumber(str);
    return currentNum.startsWith('0') && !currentNum.contains('.') && currentNum.isNotEmpty;
  }

  String _getCurrentNumber(String str) {
    int lastOpIndex = str.lastIndexOf(RegExp(r'[+\-*/()]'));
    return str.substring(lastOpIndex + 1);
  }

  bool _canCloseParenthesis(String str) {
    int openCount = 0;
    for (int i = 0; i < str.length; i++) {
      if (str[i] == '(') openCount++;
      if (str[i] == ')') openCount--;
    }
    return openCount > 0;
  }

  double evaluateExpression(String expression) {
    List<String> tokens = _tokenizeWithImplicitMultiplication(expression);
    List<String> rpn = _toRPN(tokens);

    return _evaluateRPN(rpn);
  }

  List<String> _tokenizeWithImplicitMultiplication(String expression) {
    List<String> tokens = [];
    String currentNumber = '';

    for (int i = 0; i < expression.length; i++) {
      String char = expression[i];

      if (RegExp(r'[0-9.]').hasMatch(char)) {
        currentNumber += char;
        continue;
      }

      if (char == '-') {
        bool isUnary =
            i == 0 ||
            expression[i - 1] == '(' ||
            _isOperator(expression[i - 1]);

        if (isUnary) {
          currentNumber += '-';  
          continue;
        }
      }

      if (currentNumber.isNotEmpty) {
        tokens.add(currentNumber);
        currentNumber = '';
      }

      if (tokens.isNotEmpty) {
        String last = tokens.last;

        if (char == '(' &&
            (RegExp(r'^[0-9.\-]+$').hasMatch(last) || last == ')')) {
          tokens.add('*');
        }
      }
      tokens.add(char);
    }

    if (currentNumber.isNotEmpty) {
      tokens.add(currentNumber);
    }

    return tokens;
  }

  
  List<String> _toRPN(List<String> tokens) {
    Map<String, int> precedence = {'+': 1, '-': 1, '*': 2, '/': 2};
    List<String> output = [];
    List<String> operators = [];

    for (String token in tokens) {
      if (RegExp(r'^-?[0-9.]+$').hasMatch(token)) {
        output.add(token);
      } else if (token == '(') {
        operators.add(token);
      } else if (token == ')') {
        while (operators.isNotEmpty && operators.last != '(') {
          output.add(operators.removeLast());
        }
        if (operators.isNotEmpty) operators.removeLast();  // Quitar '('
      } else if (precedence.containsKey(token)) {
        while (operators.isNotEmpty && operators.last != '(' && precedence[operators.last]! >= precedence[token]!) {
          output.add(operators.removeLast());
        }
        operators.add(token);
      }
    }
    while (operators.isNotEmpty) {
      output.add(operators.removeLast());
    }
    return output;
  }

  double _evaluateRPN(List<String> rpn) {
    List<double> stack = [];
    for (String token in rpn) {
      if (RegExp(r'^-?[0-9.]+$').hasMatch(token)) {
        stack.add(double.parse(token));
      } else {
        if (stack.length < 2) throw Exception('Invalid expression');
        double b = stack.removeLast();
        double a = stack.removeLast();
        switch (token) {
          case '+':
            stack.add(a + b);
            break;
          case '-':
            stack.add(a - b);
            break;
          case '*':
            stack.add(a * b);
            break;
          case '/':
            if (b == 0) throw Exception('Division by zero');
            stack.add(a / b);
            break;
        }
      }
    }
    if (stack.length != 1) throw Exception('Invalid expression');
    return stack.first;
  }

  Widget buildButton(String text, {bool isLarge = false, bool isRed = false}) {
    return ElevatedButton(
      onPressed: () => onButtonPressed(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: isLarge ? Colors.green : (isRed ? Colors.red : Colors.grey[800]),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: EdgeInsets.zero,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: isLarge ? 40 : 34,
            color: Colors.white,
            fontWeight: isLarge ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget verticalLayout() {
    return Column(
      children: [
        buildDisplay(flex: 2),
        buildToolbar(),
        buildButtonsGrid(crossAxisCount: 4),
      ],
    );
  }

  Widget horizontalLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        buildDisplay(flex: 3),
        buildToolbar(),
        buildButtonsGridH(crossAxisCount: 8),
      ],
    );
  }

  Widget buildDisplay({required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        color: const Color.fromARGB(255, 14, 14, 14),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Text(
            display.isEmpty ? '0' : display,
            style: const TextStyle(fontSize: 50, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget buildToolbar() {
    return Container(
      height: 50,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerRight,
      child: IconButton(
        onPressed: () => onButtonPressed('⌫'),
        icon: const Icon(
          Icons.backspace,
          color: Colors.pinkAccent,
          size: 30,
        ),
      ),
    );
  }

  Widget buildButtonsGrid({required int crossAxisCount}) {
    return Expanded(
      flex: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildButton('C', isRed: true)),  // Rojo
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('(')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton(')')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('/')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildButton('7')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('8')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('9')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('*')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildButton('4')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('5')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('6')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('-')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildButton('1')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('2')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('3')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('+')),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildButton('0')),
                  const SizedBox(width: 14),
                  Expanded(child: buildButton('.')),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: buildButton('=', isLarge: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildButtonsGridH({required int crossAxisCount}) {
    return Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildButton('C', isRed: true)),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('7')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('8')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('9')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('/')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('(')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton(')')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildButton('.')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('4')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('5')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('6')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('-')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('*')),
                  const SizedBox(width: 12),
                  Expanded(child: const SizedBox()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildButton('0')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('1')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('2')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('3')),
                  const SizedBox(width: 12),
                  Expanded(child: buildButton('+')),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: buildButton('=', isLarge: true),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: OrientationBuilder(
        builder: (context, orientation) {
          return orientation == Orientation.portrait
              ? verticalLayout()
              : horizontalLayout();
        },
      ),
    );
  }
}

