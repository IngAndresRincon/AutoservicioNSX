import 'package:flutter/material.dart';

const colorList = <Color>[
  Colors.black,
  Colors.tealAccent,
  Color.fromRGBO(0,131,62,1),
  Color.fromRGBO(0,174,66,1),
  Color.fromRGBO(118,188,33,1),
];

class AppTheme {
  final int selectedColor;

  AppTheme({
    this.selectedColor = 0
  }):assert(selectedColor >= 0,'Selected color is not avaliable'),
  assert(selectedColor < colorList.length - 1,'Selected color is not avaliable');

  ThemeData getAppTheme() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
        seedColor: colorList[selectedColor],
      ),

      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
  );
}