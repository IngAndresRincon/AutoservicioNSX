
import 'package:flutter/material.dart';

class MenuItem {
  final String tittle;
  final String link;
  final IconData icon;

  const MenuItem({
    required this.tittle,
    required this.icon,
    required this.link
  });
}

const appMenuItems = <MenuItem>[
  MenuItem(
    tittle: 'Programar Venta ',
    icon: Icons.local_gas_station_outlined,
    link: '/positions', 
    ),
    

  MenuItem(
    tittle: 'Ventas',
    icon: Icons.webhook_rounded,
    link: '/transactions',  ),

];