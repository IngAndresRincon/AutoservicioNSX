import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gnesys_as/data/models/models.dart';
import 'package:gnesys_as/services/pump_service.dart';
import 'package:go_router/go_router.dart';

extension ProductoStyle on String {
  Color get color {
    switch (toLowerCase()) {
      case 'corriente': return const Color(0xFFD32F2F); // Rojo
      case 'diesel':    return const Color(0xFFF9A825); // Amarillo
      case 'extra_biomax':     return const Color(0xFF1565C0); // Azul
      case 'gas':       return const Color(0xFF2E7D32); // Verde
      default:          return const Color(0xFF424242);
    }
  }

  String get imagePath {
    final nombre = toLowerCase() + '_biomax.png';
    return 'assets/images/$nombre';
  }
}

class SaleScreen extends StatefulWidget {
  final int posicion;
  const SaleScreen ({
    super.key,
    required this.posicion
    });

  @override
  State<SaleScreen> createState() => _SaleScreenState();
}
  
class _SaleScreenState extends State<SaleScreen>{

  List<Mapeo> mapeos = [];
  bool loading = true;


  @override
  void initState(){
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    cargarMapeo();

  }

  Future<void> cargarMapeo() async {

    final data = await PumpService.getMapeo();

    setState(() {

      mapeos = data
          .where((m) => m.posicion == widget.posicion)
          .toList();

      loading = false;

    });
  }
    Future<void> loadMapping() async {

    //final data = await PumpService.getMappingWithFallback();

  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color.fromRGBO(0,131,62,1),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Color.fromRGBO(0,131,62,1),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildStepIndicator(),
            Expanded(child: _buildProductGrid()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }
  

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            ),
          ),
          const Spacer(),
          // Decoración top-right como en el diseño
          Container(
            width: 100,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(60),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Center(
              child: Text(
                '1',
                style: TextStyle(
                  color: Color(0xFFF9A825),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Elige',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'el producto.',
                style: TextStyle(
                  color: Color(0xFFF9A825),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
  return ListView.builder(
    itemCount: mapeos.length,
    itemBuilder: (context, index) 
    {
      debugPrint(jsonEncode(mapeos));
      return GestureDetector(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          margin: EdgeInsets.symmetric(vertical: 10, horizontal: 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.amber,
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10,vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white),
                child: Text('15.500',style: const TextStyle(
                              fontFamily: 'Digital7',
                              fontSize: 40,
                              color: Colors.black87,
                              letterSpacing: 5,
                            ),),
              ),
              const SizedBox(height: 10,),
              Text(mapeos[index].nombreProducto,style: TextStyle(
                fontSize: 30,
                color: Colors.blue,
        
              ),),
            ],),
        ),
      );
    },
    // builder: (context, constraints) {
    //   // Altura disponible dividida entre el número de productos
    //   return 
    //   // final cardHeight = (constraints.maxHeight - (mapeos.length - 1) * 16) / mapeos.length;
  
    //   // return Padding(
    //   //   padding: const EdgeInsets.symmetric(horizontal: 20),
    //   //   child: List.generate(mapeos.length, (index) {
    //   //       return Padding(
    //   //         padding: EdgeInsets.only(
    //   //           bottom: index < mapeos.length - 1 ? 16 : 0,
    //   //         ),
    //   //         child: SizedBox(
    //   //           height: cardHeight.clamp(100, 200), // Mínimo 100, máximo 200
    //   //           child: _buildProductCard(mapeos[index]),
    //   //         ),
    //   //       );
    //   //     }),
    //   // );
    // },
  );
}

  Widget _buildProductCard(Mapeo m) {
    final precio = '15.500'; // Precio predefinido por ahora

    return GestureDetector(
      onTap: () => context.push('/program', extra: m),
    child: Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: AssetImage(m.nombreProducto.imagePath), // 👈 Imagen de fondo
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        // Overlay oscuro para que el texto se lea bien
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.05),
          ),
          child: Row(
            children: [
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Display 7 segmentos
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        
                      ),
                      child: Text(
                        precio,
                        style: const TextStyle(
                          fontFamily: 'Digital7',
                          fontSize: 40,
                          color: Colors.black87,
                          letterSpacing: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1A237E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset('assets/images/logo_biomax_1.png', height: 45),
          const Text(
            'EDS QA INSEPET',
            style: TextStyle(
              color: Color(0xFF69F0AE),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Image.asset('assets/images/logo_insepet_blanco.png', height: 45),
        ],
      ),
    );
  }
}