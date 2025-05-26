import 'package:flutter/material.dart';

import 'cupertino/cupertino_controls.dart';

class CustomAdaptiveControls extends StatelessWidget {
  const CustomAdaptiveControls({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CustomCupertinoControls(
      backgroundColor: Color.fromRGBO(41, 41, 41, 0.7),
      iconColor: Color.fromARGB(255, 200, 200, 200),
    );
  }
}
