import 'dart:typed_data';

class ByteDataWrapper {
  late ByteData _byteData;
  int _position = 0;
  bool _isLittleEndian = false;

  ByteDataWrapper.wrap(Uint8List data) {
    _byteData = ByteData.view(data.buffer);
  }

  ByteDataWrapper setLittleEndian() {
    _isLittleEndian = true;
    return this;
  }

  int get position => _position;
  set position(int value) => _position = value;

  int getUint8() {
    final value = _byteData.getUint8(_position);
    _position += 1;
    return value;
  }

  int getUint16() {
    final value = _byteData.getUint16(
      _position,
      _isLittleEndian ? Endian.little : Endian.big,
    );
    _position += 2;
    return value;
  }

  Uint8List getBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _byteData.getUint8(_position + i);
    }
    _position += length;
    return bytes;
  }
}

enum DeviceConnectionState {
  disconnected(0),
  connected(1);

  final int value;
  const DeviceConnectionState(this.value);

  static DeviceConnectionState fromValue(int value) {
    return DeviceConnectionState.values.firstWhere((e) => e.value == value);
  }
}

class DeviceBeacon {
  static const int BEACON_LENGTH = 13;

  late ByteDataWrapper byteBuffer;
  final int beaconVersion;
  final int productId;
  late String btAddress;
  late bool needAuth;
  bool supportCTKD = false;
  late DeviceConnectionState connectionState;
  bool useCustomSppUuid = false;
  int brandId = 0;

  int get agentId => brandId >> 16;
  bool get isConnected => connectionState == DeviceConnectionState.connected;

  DeviceBeacon(Uint8List data)
    : beaconVersion = data[0] & 0xF,
      productId = ByteDataWrapper.wrap(data).setLittleEndian().getUint16() {
    if (data.length != BEACON_LENGTH || beaconVersion != 2) {
      throw FormatException('Invalid beacon data or version');
    }

    byteBuffer = ByteDataWrapper.wrap(data)..setLittleEndian();

    // Skip version and productId as they're already read
    byteBuffer.position = 3;

    // 读取蓝牙地址
    var ca = byteBuffer.getBytes(6);
    ca = _deobfuscateBtAddress(ca);
    btAddress = ca.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');

    // 读取特征掩码
    final featureMask = byteBuffer.getUint8();
    needAuth = (featureMask & (1 << 0)) != 0;
    supportCTKD = (featureMask & (1 << 1)) != 0;
    connectionState = DeviceConnectionState.fromValue((featureMask >> 2) & 3);
    useCustomSppUuid = (featureMask & (1 << 4)) != 0;

    // 读取品牌ID
    brandId =
        byteBuffer.getUint8() |
        (byteBuffer.getUint8() << 8) |
        (byteBuffer.getUint8() << 16);
  }

  Uint8List _deobfuscateBtAddress(Uint8List data) {
    return Uint8List.fromList(data.map((b) => b ^ 0xAD).toList());
  }

  static DeviceBeacon? fromData(Uint8List data) {
    try {
      return DeviceBeacon(data);
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'DeviceBeacon: beaconVersion=$beaconVersion, productId=$productId, '
        'brandId=$brandId, btAddress=$btAddress, supportCTKD=$supportCTKD, '
        'needAuth=$needAuth, connectionState=$connectionState';
  }
}
