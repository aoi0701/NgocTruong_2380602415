import 'package:flutter/material.dart';

class UnitConverterScreen extends StatefulWidget {
  final bool showAppBar;
  const UnitConverterScreen({super.key, this.showAppBar = true});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  final TextEditingController _controller = TextEditingController();
  double? _convertedValue;
  bool _isMetersToFeet = true;

  void _convertUnits() {
    setState(() {
      final input = double.tryParse(_controller.text);
      if (input != null) {
        if (_isMetersToFeet) {
          _convertedValue = input * 3.28084; // M -> Ft
        } else {
          _convertedValue = input / 3.28084; // Ft -> M
        }
        _isMetersToFeet = !_isMetersToFeet;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Chuyển đổi đơn vị đo'),
              backgroundColor: Colors.deepOrange,
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Nhập giá trị:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Nhập giá trị',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _convertedValue == null
                  ? 'Kết quả sẽ hiển thị ở đây'
                  : _isMetersToFeet
                  ? 'Giá trị đổi sang feet là: ${_convertedValue!.toStringAsFixed(2)} ft'
                  : 'Giá trị đổi sang mét là: ${_convertedValue!.toStringAsFixed(2)} m',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _convertUnits,
        child: const Icon(Icons.swap_horiz),
      ),
    );
  }
}