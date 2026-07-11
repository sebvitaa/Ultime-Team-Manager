import 'package:flutter/material.dart';

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int clickCounter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contador Matón')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$clickCounter',
              style: TextStyle(
                fontSize: 160,
                fontWeight: FontWeight.w100,
                color: clickCounter >= 10 ? Colors.blue : Colors.black,
              ),
            ),
            Text(
              'Ve${clickCounter == 1 ? 'z presionado' : 'ces presionado'}',
              style: const TextStyle(fontSize: 25),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CustomButton(
            icon: Icons.refresh_rounded,
            color: Colors.cyan,
            onPressed: () {
              clickCounter = 0;
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contador reiniciado')),
              );
            },
          ),
          SizedBox(height: clickCounter > 0 ? 10 : 0),
          CustomButton(
            icon: Icons.exposure_minus_1_outlined,
            color: Colors.purple,
            visible: clickCounter > 0 ? true : false,
            onPressed: () {
              if (clickCounter == 0) return;
              clickCounter--;
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          CustomButton(
            icon: Icons.plus_one,
            color: Colors.green,
            onPressed: () {
              clickCounter++;
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          CustomButton(
            icon: Icons.forward_10,
            color: Colors.amber,
            onPressed: () {
              clickCounter+=10;
              setState(() {});
            },
          ),  //Botón para +10
        ],
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool visible;

  const CustomButton({super.key, required this.icon, this.onPressed, this.color, this.visible = true});

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      child: FloatingActionButton(
        elevation: 5,
        onPressed: onPressed,
        backgroundColor: color,
        child: Icon(icon),
      ),
    );
  }
}