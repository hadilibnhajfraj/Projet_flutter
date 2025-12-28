


import 'package:dash_master_toolkit/dashboard/sales/sales_imports.dart';

class SalesDashboardController extends GetxController {

  final visitors = <VisitorData>[
    VisitorData(0, 300, 280, 310),
    VisitorData(1, 290, 260, 330),
    VisitorData(2, 280, 220, 340),
    VisitorData(3, 270, 200, 330),
    VisitorData(4, 280, 230, 310),
    VisitorData(5, 320, 290, 300),
    VisitorData(6, 350, 360, 290), // July (highlighted)
    VisitorData(7, 310, 330, 310),
    VisitorData(8, 270, 250, 330),
    VisitorData(9, 240, 210, 320),
    VisitorData(10, 220, 190, 300),
    VisitorData(11, 200, 180, 280),
  ].obs;

  final topProductData = <ProductData>[
    ProductData(name: 'Home Decor Range', popularity: 70, sales:45 ,color: '0195FF'),
    ProductData(name: 'Disney Princess Pink Bag', popularity: 60, sales:29, color: '18E2A0'),
    ProductData(name: 'Bathroom Essentials', popularity: 50, sales:18 ,color: '884DFF'),
    ProductData(name: 'Apple Smartwatch', popularity:20 , sales:25, color: 'FF8F0E')
  ].obs;

  final List<MapData> countrySales = [
    MapData('United States of America', Colors.orange),
    MapData('Brazil', Colors.redAccent),
    MapData('China', Colors.deepPurple),
    MapData('Indonesia', Colors.green),
    MapData('India', Colors.teal),
    MapData('Niger', Colors.blueAccent),
  ];
}
