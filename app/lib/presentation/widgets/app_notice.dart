import 'dart:async';

import 'package:flutter/material.dart';

enum NoticeKind { success, error, info, loading }

OverlayEntry? _entry;
Timer? _timer;

/// Cierra el aviso que este en pantalla (por ejemplo el de "procesando" cuando llega el resultado).
void hideAppNotice() {
  _timer?.cancel();
  _timer = null;
  _entry?.remove();
  _entry = null;
}

/// Aviso grande arriba de la pantalla, en lugar del snackbar de abajo que no se nota.
/// Exito en verde, error en rojo, informacion en el color [accent] y "procesando" con una rueda que queda hasta que llegue otro aviso.
/// Se cierra solo (5 s exito/info, 8 s error) o al tocarlo.
void showAppNotice(
  BuildContext context,
  String message, {
  String? title,
  NoticeKind kind = NoticeKind.success,
  Color? accent,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  hideAppNotice();

  final Color color;
  final IconData icon;
  switch (kind) {
    case NoticeKind.success:
      color = const Color(0xFF2E9E5B);
      icon = Icons.check_circle_rounded;
    case NoticeKind.error:
      color = const Color(0xFFD32F2F);
      icon = Icons.error_rounded;
    case NoticeKind.info:
      color = accent ?? const Color(0xFF1565C0);
      icon = Icons.info_rounded;
    case NoticeKind.loading:
      color = accent ?? const Color(0xFF455A64);
      icon = Icons.hourglass_top_rounded;
  }

  _entry = OverlayEntry(
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      // Crece con la pantalla (400 de ancho = 1) para que en tablets grandes se vea de lejos
      final f = (media.size.width / 400).clamp(1.0, 1.5);
      return Positioned(
        top: media.padding.top + 10 * f,
        left: 14 * f,
        right: 14 * f,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: kind == NoticeKind.loading ? null : hideAppNotice,
            child: Container(
              padding: EdgeInsets.fromLTRB(20 * f, 18 * f, 16 * f, 18 * f),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(22 * f),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, spreadRadius: 1, offset: const Offset(0, 8))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (kind == NoticeKind.loading)
                    SizedBox(width: 44 * f, height: 44 * f, child: const CircularProgressIndicator(strokeWidth: 4.5, color: Colors.white))
                  else
                    Icon(icon, color: Colors.white, size: 52 * f),
                  SizedBox(width: 16 * f),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null)
                          Text(title, style: TextStyle(color: Colors.white, fontSize: 24 * f, fontWeight: FontWeight.w900, height: 1.2)),
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withOpacity(title != null ? 0.95 : 1),
                            fontSize: (title != null ? 19 : 22) * f,
                            fontWeight: title != null ? FontWeight.w600 : FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (kind != NoticeKind.loading) Icon(Icons.close_rounded, color: Colors.white70, size: 30 * f),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(_entry!);

  if (kind != NoticeKind.loading) {
    _timer = Timer(Duration(seconds: kind == NoticeKind.error ? 8 : 5), hideAppNotice);
  }
}
