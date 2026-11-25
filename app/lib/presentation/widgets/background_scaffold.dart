import 'package:flutter/material.dart';

class BackgroundScaffold extends StatelessWidget {

  final Widget child;
  final String backgroundImage;
  final AppBar? appBar;

  const BackgroundScaffold({
    super.key,
    required this.child,
    required this.backgroundImage,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar,

      body: Stack(
        children: [

          /// Fondo
          Positioned.fill(
            child: Image.asset(
              backgroundImage,
              fit: BoxFit.cover,
            ),
          ),

          /// Contenido
          SafeArea(
            child: child,
          ),

        ],
      ),
    );
  }
} 