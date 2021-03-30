import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

void main() {
  runApp(ProviderScope(child: MyApp()));
}

// riverpod provider
final carProvider = FutureProvider((_) => _allCarSales());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends HookWidget {
  ScrollController _scrollController = ScrollController();
  final double itemExtentSize = 70.0;
  var _listSelectedIndex;
  @override
  Widget build(BuildContext context) {
    final _carProvider = useProvider(carProvider);
    _listSelectedIndex = useState<int>(-1);
    return Scaffold(
      appBar: AppBar(
        title: Text('Car Sales'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(20, 20, 15, 5),
            height: 200,
            child: _carProvider.when(
              data: (carList) => _buildLineChart(carList),
              loading: () => CircularProgressIndicator(),
              error: (_, __) => Text('Ooooopsss error'),
            ),
          ),
          Expanded(
            child: _carProvider.when(
              data: (carList) => _getSlidableCarList(carList, context),
              loading: () => CircularProgressIndicator(),
              error: (_, __) => Text('Ooopsss error'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<CarSales> carList) {
    var bpChartData = _BPChartData.build(carList);
    return SizedBox(
      key: UniqueKey(),
      width: 350,
      height: 200,
      child: LineChart(
        LineChartData(
          backgroundColor: Colors.white,
          lineTouchData: LineTouchData(
            enabled: true,
            touchCallback: (LineTouchResponse touchResponse) {
              if (touchResponse.lineBarSpots.isNotEmpty) {
                var posItemTouched = touchResponse.lineBarSpots[0].x;
                var scrollTo = _scrollTo(carList, posItemTouched);
                _scrollController.animateTo(scrollTo,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.linear);
              }
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: bpChartData.carPoints,
              isCurved: true,
              barWidth: 1.5,
              colors: [
                Colors.deepPurple,
              ],
              dotData: FlDotData(
                show: false,
              ),
            ),
          ],
          minY: bpChartData.minY.toDouble() - 100,
          maxY: bpChartData.maxY.toDouble() + 100,
          titlesData: FlTitlesData(
            bottomTitles: SideTitles(
                showTitles: true,
                interval: bpChartData.labelXInterval.toDouble(),
                rotateAngle: -15,
                getTextStyles: (value) =>
                    const TextStyle(fontSize: 10, color: Colors.deepPurple),
                getTitles: (value) {
                  return bpChartData.models[value.toInt()];
                }),
            leftTitles: SideTitles(
              showTitles: true,
              interval: bpChartData.labelYInterval.toDouble(),
              getTitles: (value) {
                return '$value';
              },
            ),
          ),
          gridData: FlGridData(
            show: false,
            horizontalInterval: 2,
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              left: BorderSide(color: Colors.deepPurple),
              top: BorderSide(color: Colors.transparent),
              bottom: BorderSide(color: Colors.deepPurple),
              right: BorderSide(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );
  }

  double _scrollTo(List<CarSales> carSalesList, double posItemTouched) {
    var result = 0.0;
    var posInList = carSalesList.length - posItemTouched - 1;
    var maxScrollExtent = _scrollController.position.maxScrollExtent;
    var posItemTouchedExt = posInList * itemExtentSize;
    result = posItemTouchedExt < maxScrollExtent
        ? posItemTouchedExt
        : maxScrollExtent;
    // the line below causes the issue but it's necessary to paint the selected row on the list.
    _listSelectedIndex.value = posInList.toInt();
    // even with delayed call it doesn't work properly.
    // Future.delayed(Duration(seconds: 1),
    //     () async => _listSelectedIndex.value = posInList.toInt());
    return result;
  }

  Widget _getSlidableCarList(List<CarSales> carList, BuildContext context) {
    return ListView.builder(
      itemExtent: itemExtentSize,
      itemCount: carList.length,
      controller: _scrollController,
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return Slidable(
            key: UniqueKey(),
            closeOnScroll: true,
            actionPane: SlidableDrawerActionPane(),
            child: ListTile(
              selectedTileColor: Colors.deepPurpleAccent[100],
              selected: index == _listSelectedIndex.value,
              title: Text('${carList[index].car}',
                  style: Theme.of(context).textTheme.headline5),
              subtitle: Text(
                '${carList[index].brand}',
                style: Theme.of(context).textTheme.subtitle1,
              ),
              trailing: Text('${carList[index].units} units'),
            ));
      },
    );
  }
}

class _BPChartData {
  List<FlSpot> carPoints;
  int maxY;
  int minY;
  List<String> models;
  int labelXInterval;
  int labelYInterval;

  _BPChartData.build(List<CarSales> carList) {
    carList = carList.reversed.toList(growable: false);
    carPoints = <FlSpot>[];
    models = <String>[];
    maxY = carList.map((c) => c.units).reduce(max).ceil();
    minY = carList.map((c) => c.units).reduce(min).floor();
    carList.asMap().forEach((index, car) {
      carPoints.add(FlSpot(index.toDouble(), car.units.toDouble()));
      models.add(car.car);
    });
    labelXInterval = 3;
    labelYInterval = 100;
  }
}

class CarSales {
  String brand;
  String car;
  int units;
  CarSales(this.brand, this.car, this.units);
}

Future<List<CarSales>> _allCarSales() async {
  var result = <CarSales>[];
  result
    ..add(CarSales('VW', 'Beetle', 251))
    ..add(CarSales('VW', 'Golf', 334))
    ..add(CarSales('VW', 'Passat', 121))
    ..add(CarSales('VW', 'Polo', 671))
    ..add(CarSales('VW', 'Tiguan', 251))
    ..add(CarSales('BMW', 'M5', 586))
    ..add(CarSales('BMW', 'Z3', 224))
    ..add(CarSales('BMW', 'Z4', 332))
    ..add(CarSales('BMW', 'M5', 524))
    ..add(CarSales('BMW', 'X1', 145))
    ..add(CarSales('Audi', 'Q3', 754))
    ..add(CarSales('Audi', 'A3', 864))
    ..add(CarSales('Audi', 'RS7', 254))
    ..add(CarSales('Mercedes', 'Maybach', 325))
    ..add(CarSales('Mercedes', 'S-Class', 755))
    ..add(CarSales('Mercedes', 'E-Class', 256))
    ..add(CarSales('Mercedes', 'A-Class Limo', 478))
    ..add(CarSales('Toyota', 'Aigo', 885))
    ..add(CarSales('Toyota', 'Corolla', 285))
    ..add(CarSales('Toyota', 'Yaris', 125))
    ..add(CarSales('Toyota', 'Prius', 814))
    ..add(CarSales('Tesla', 'Model X', 754))
    ..add(CarSales('Tesla', 'Model S', 356));

  return result;
}
