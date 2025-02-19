import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hevaral_bluetooth_demo/constants/blueturm.dart';
import 'package:hevaral_bluetooth_demo/model/device_beacon.dart';
import 'package:permission_handler/permission_handler.dart';

class ScaningPage extends StatefulWidget {
  const ScaningPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ScaningPageState();
  }
}

class _ScaningPageState extends State<ScaningPage> {
  StreamSubscription? _subscription;
  final List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_isScanning) {
      return;
    }
    _isScanning = true;
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    // 检查是否已授予权限
    var locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      print("位置权限被拒绝");
      return;
    }

    var bluetoothScanStatus = await Permission.bluetoothScan.request();
    if (!bluetoothScanStatus.isGranted) {
      print("蓝牙扫描权限被拒绝");
      return;
    }
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    if (!bluetoothConnectStatus.isGranted) {
      print("蓝牙连接权限被拒绝");
      return;
    }
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) async {
      if (state == BluetoothAdapterState.on) {
        if (_subscription != null) {
          _subscription?.cancel();
          _scanResults.clear();
        }
        // usually start scanning, connecting, etc
        // 设置监听
        _subscription = FlutterBluePlus.onScanResults.listen((results) {
          if (results.isNotEmpty) {
            ScanResult r = results.last;
            var manufactureData = r.advertisementData.manufacturerData;
            if (manufactureData.isEmpty) {
              // 厂商数据不存在
              return;
            }
            if (!manufactureData.containsKey(MANUFACTURER_ID)) {
              return;
            }
            var data = Uint8List.fromList(manufactureData[MANUFACTURER_ID]!);
            final deviceBeacon = DeviceBeacon(data);
            if (deviceBeacon.brandId == (BRAND_ID >> 16)) {
              if (!deviceBeacon.isConnected) {
                var index = _scanResults.indexWhere(
                  (element) => element.device.remoteId == r.device.remoteId,
                );
                if (index != -1) {
                  _scanResults[index] = r;
                } else if (r.advertisementData.advName.isNotEmpty) {
                  _scanResults.add(r);
                }
              }
            }

            setState(() {});
          }
        }, onError: (e) => print(e));

        print("开始扫描");
        // 设置扫描时间为5秒
        await FlutterBluePlus.startScan();
        print("扫描结束");
      } else {
        // show an error to the user, etc
      }
    });
  }

  Future<void> _stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    setState(() {});
  }

  Future<void> _connect(ScanResult r) async {
    BluetoothDevice device = r.device;
    var subscription = device.connectionState.listen((
      BluetoothConnectionState state,
    ) async {
      if (state == BluetoothConnectionState.disconnected) {
        // 1. typically, start a periodic timer that tries to
        //    reconnect, or just call connect() again right now
        // 2. you must always re-discover services after disconnection!
        print(
          "${device.disconnectReason?.code} ${device.disconnectReason?.description}",
        );
      }
      print('设备连接状态: $state');
    });

    device.cancelWhenDisconnected(subscription, delayed: true, next: true);
    await device.connect();

    print('连接成功');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('扫描'),
        actions: [
          _isScanning
              ? TextButton(
                onPressed: _stopScan,
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(),
                    ),
                    SizedBox(width: 10),
                    Text('暂停'),
                  ],
                ),
              )
              : TextButton(onPressed: _startScan, child: Text('扫描')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                var r = _scanResults.reversed.toList()[index];
                var name = r.advertisementData.advName;
                if (name.isEmpty) {
                  name = r.device.platformName;
                }

                var deviceBeacon = DeviceBeacon(
                  Uint8List.fromList(
                    r.advertisementData.manufacturerData[MANUFACTURER_ID]!,
                  ),
                );

                return Container(
                  height: 66,
                  padding: EdgeInsets.all(8),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('设备名称: $name', style: TextStyle(fontSize: 16)),
                          Text(
                            '设备地址: ${deviceBeacon.btAddress}',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),

                      FilledButton(
                        onPressed: () {
                          _connect(r);
                        },
                        child: Text('连接'),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) {
                return const SizedBox(height: 10);
              },
            ),
          ),
        ],
      ),
    );
  }
}
