
import 'package:gnesys_as/presentation/screens/configuration/configuration_screen.dart';
import 'package:gnesys_as/presentation/screens/screens.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/models.dart';
import '../../data/enums/enums.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      
      path: '/',
      builder: (context, state) => const HomeScreen(),),
    
    GoRoute(
      path: '/sales',
      builder: (context, state) {
        final pos = state.extra as int;
        return SaleScreen(
          posicion: pos,
        );
      },
    ),
    
    GoRoute(
      path: '/positions',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        final customer = extra['customer'] as CustomerModel;
        return PositionsScreen(customer: customer);
      },
    ),
    // GoRoute(
    //   path: '/transactions',
    //   builder: (context, state) => const TransactionScreen(),),

    GoRoute(
      path: '/identification',
      builder: (context, state) => const CustomerIdentificationScreen(),),

    GoRoute(
      path: '/configuration',
      builder: (context, state) => const ConfigScreen(),),

    GoRoute(
      path: '/preset',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;

        final hose = extra['hose'] as ProductHose;
        final speedDialList = extra['speedDial'] as List<SpeedDial>;
        final methodPaymentList = extra['methodPayments'] as List<MethodPayment>;
        final customer = extra['customer'] as CustomerModel;

        return PresetScreen(
          hose: hose,
          speedDialList: speedDialList,
          methodPaymentList: methodPaymentList,
          customer: customer,
        );
      },
    ),

    GoRoute(
      path: '/partial_payment',
      builder: (context, state) {
        // Extraemos el mapa que enviamos desde el modal
        final extras = state.extra as Map<String, dynamic>;
        
        return PartialPaymentScreen(
          totalValue: extras['totalValue'] as double,
          hose: extras['hose'] as ProductHose,
          programmingType: extras['programmingType'] as ProgrammingType,
          methodPaymentList: extras['methodPaymentList'] as List<MethodPayment>,
          customer: extras['customer'] as CustomerModel,
        );
      },
    ),

    GoRoute(
      path: '/custom-keypad',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        
        return CustomKeypadScreen(
          hose: extra['hose'] as ProductHose,
          isMoneyMode: extra['isMoneyMode'] as bool,
          maxValue: extra['maxValue'] as double? ?? 999999.0,
        );
      },
    ),

    GoRoute(
      path: '/payment',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return PaymentScreen(
          hose: extra['hose'] as ProductHose,
          programmingId: extra['programmingId'] as int,
          programmingValue: extra['programmingValue'] as double,
          programmingType: extra['programmingType'] as ProgrammingType,
          methodPayments: extra['methodPayments'] as List<MethodPayment>,
          customer: extra['customer'] as CustomerModel,
          amountAlreadyPaid: (extra['amountAlreadyPaid'] as double?) ?? 0.0,
        );
      },
    ),
 
    GoRoute(
      path: '/instructions',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>;
        return InstructionsScreen(
          payload: extras['payload'], // El JSON del socket
          hose: extras['hose'] as ProductHose,
          customer: extras['customer'] as CustomerModel,
          programmingValue: extras['programmingValue'] as double?,
          programmingType: extras['programmingType'] as ProgrammingType?,
        );
      },
    ),
    GoRoute(
      path: '/dispensing',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>;
        return DispensingScreen(
          hose: extras['hose'] as ProductHose,
          customer: extras['customer'] as CustomerModel,
          programmingValue: extras['programmingValue'] as double?,
          programmingType: extras['programmingType'] as ProgrammingType?,
        );
      },
    ),
    GoRoute(
      path: '/sale-summary',
      builder: (context, state) {
        final extras = state.extra as Map<String, dynamic>;
        return TransactionScreen(
          sale: extras['sale'] as Map<String, dynamic>,
          customer: extras['customer'] as CustomerModel?,
          hose: extras['hose'] as ProductHose?,
        );
      },
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return TransactionScreen(
          sale: extra['sale'] as Map<String, dynamic>,
          customer: extra['customer'] as CustomerModel?,
          hose: extra['hose'] as ProductHose?,
        );
      },
    ),
    GoRoute(
      path: '/pending-auth',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return PendingAuthScreen(
          customer: extra['customer'] as CustomerModel,
          authorization: extra['authorization'] as Map<String, dynamic>,
        );
      },
    ),

    // Vendedor de paso (dispensadores hibridos)
    GoRoute(
      path: '/seller/login',
      builder: (context, state) => const SellerLoginScreen(),
    ),
    GoRoute(
      path: '/seller/menu',
      builder: (context, state) => const SellerMenuScreen(),
    ),
    GoRoute(
      path: '/seller/sale',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return SellerSaleScreen(credit: extra?['credit'] as SellerCredit?);
      },
    ),
    GoRoute(
      path: '/seller/dispensing',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return SellerDispensingScreen(
          isCredit: extra['isCredit'] as bool? ?? false,
          presetId: extra['presetId'] as int,
          positionId: extra['positionId'] as int,
          nsxPositionId: extra['nsxPositionId'] as int,
          product: extra['product'] as String,
          hoseColor: extra['hoseColor'] as String,
          programmed: extra['programmed'] as String,
          programmingType: extra['programmingType'] as int,
          programmedValue: extra['programmedValue'] as double,
        );
      },
    ),
    GoRoute(
      path: '/seller/summary',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return SellerSaleSummaryScreen(
          presetNsxId: extra['presetNsxId'] as int,
          product: extra['product'] as String,
          hoseColor: extra['hoseColor'] as String,
          nsxPositionId: extra['nsxPositionId'] as int,
          openInvoice: extra['openInvoice'] as bool? ?? false,
          isCredit: extra['isCredit'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: '/seller/credit',
      builder: (context, state) => const SellerCreditScreen(),
    ),
    GoRoute(
      path: '/seller/sales',
      builder: (context, state) => const SellerSalesScreen(),
    ),
    GoRoute(
      path: '/seller/payments',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return SellerPaymentsScreen(
          saleId: extra['saleId'] as int,
          total: extra['total'] as int,
          nsxPositionId: extra['nsxPositionId'] as int,
          saved: extra['saved'] as List<SellerPayLine>,
        );
      },
    ),
    GoRoute(
      path: '/seller/payments/add',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return SellerAddPaymentScreen(
          remaining: extra['remaining'] as int,
          usedCodes: (extra['usedCodes'] as List<String>?) ?? const [],
        );
      },
    ),
    GoRoute(
      path: '/seller/options',
      builder: (context, state) => const SellerOptionsScreen(),
    ),
  ]
);
