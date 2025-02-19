import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hevaral_bluetooth_demo/model/speech_to_translate_result.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_sound/flutter_sound.dart';

class SocketPage extends StatefulWidget {
  const SocketPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _SocketPageState();
  }
}

class _SocketPageState extends State<SocketPage> {
  late IO.Socket _socket;

  String transcribeText = '';
  String translateText = '';

  final FlutterSoundPlayer _mPlayer = FlutterSoundPlayer();

  static const blockSize = 20480;

  @override
  void initState() {
    initSocket();
    super.initState();
  }

  initSocket() {
    var option =
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setExtraHeaders({'token': '123456'})
            .disableAutoConnect()
            .build();
    _socket = IO.io('http://dev.hevaral.com', option);
    _socket.onConnect((data) {
      print('连接成功');
      if (mounted) {
        setState(() {});
      }
    });
    _socket.onDisconnect((data) {
      print('断开连接: $data');
      if (mounted) {
        setState(() {});
      }
    });
    _socket.onError((data) {
      print('连接失败: $data');
      if (mounted) {
        setState(() {});
      }
    });

    _socket.on('speech-to-translate', (data) async {
      var result = SpeechToTranslateResult.fromJson(data);

      if (result.type == 'TRANSLATION') {
        if (result.reason == 'RECOGNIZING' || result.reason == 'RECOGNIZED') {
          if (result.text != null && result.text!.isNotEmpty) {
            transcribeText = result.text!;
          }
          if (result.translateText != null &&
              result.translateText!.isNotEmpty) {
            translateText = result.translateText!;
          }
        } else if (result.reason == 'SYNTHESIZING') {
          if (result.audio != null && result.audio!.isNotEmpty) {
            print('语音合成完毕');
            Uint8List audioData = base64Decode(result.audio!);
            await _mPlayer.openPlayer();
            await _mPlayer.startPlayerFromStream(
              codec: Codec.pcm16,
              numChannels: 1,
              sampleRate: 16000,
            );
            setState(() {});
            await feedHim(audioData);
            await _mPlayer.stopPlayer();
            setState(() {});
          }
        }
      } else if (result.type == 'ERROR') {
        print('翻译失败: ${result.reason}');
      }

      setState(() {});
      setState(() {});
    });
  }

  @override
  void dispose() {
    destory();
    super.dispose();
  }

  destory() {
    _socket.off('connect');
    _socket.off('error');
    _socket.clearListeners();
    _socket.disconnect();
    _socket.destroy();
  }

  _connect() {
    _socket.connect();
  }

  _disconnect() {
    _socket.disconnect();
  }

  Future<Uint8List> getAssetData(String path) async {
    var asset = await rootBundle.load(path);
    return asset.buffer.asUint8List();
  }

  Future<void> feedHim(Uint8List buffer) async {
    var lnData = 0;
    var totalLength = buffer.length;
    while (totalLength > 0 && !_mPlayer.isStopped) {
      var bsize = totalLength > blockSize ? blockSize : totalLength;
      await _mPlayer.feedFromStream(buffer.sublist(lnData, lnData + bsize));
      lnData += bsize;
      totalLength -= bsize;
    }
  }

  _onSourcePlay() async {
    await _mPlayer.openPlayer();

    await _mPlayer.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );
    setState(() {});
    var data = await getAssetData('assets/audios/output.pcm');
    await feedHim(data);
    await _mPlayer.stopPlayer();
    setState(() {});
  }

  _onTranslate() async {
    ByteData fileData = await rootBundle.load('assets/audios/output.pcm');
    Uint8List bytes = fileData.buffer.asUint8List();
    int chunkSize = 1024 * 32; // 32KB 每次发送的数据大小
    int totalChunks = (bytes.length / chunkSize).ceil();
    for (int i = 0; i < totalChunks; i++) {
      // 计算当前分片的起始和结束位置
      int start = i * chunkSize;
      int end = (i + 1) * chunkSize;
      if (end > bytes.length) {
        end = bytes.length;
      }
      // 获取当前分片数据
      Uint8List chunk = bytes.sublist(start, end);
      // 转换为 base64 字符串
      String base64Data = base64Encode(chunk);

      // 发送数据
      _socket.emit('speech-to-translate', {
        'audio-language': 'zh-CN',
        'translate-language': 'en-US',
        'audio': base64Data,
        'isLastChunk': i == totalChunks - 1, // 标记是否为最后一块数据
        'chunkIndex': i,
        'totalChunks': totalChunks,
      });
      print('总共:$totalChunks块数据， 发送第$i块数据');
      // 等待一小段时间，避免发送太快
      await Future.delayed(const Duration(milliseconds: 500));
    }

    print('文件发送完毕');
  }

  String get _socketConnectionState {
    return _socket.connected ? '连接成功' : '连接断开';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Socket测试')),
      body: SizedBox(
        width: double.maxFinite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('连接状态: $_socketConnectionState'),
                SizedBox(width: 20),
                FilledButton(
                  onPressed: () {
                    if (_socket.connected) {
                      _disconnect();
                    } else {
                      _connect();
                    }
                  },
                  child: Text(!_socket.connected ? '连接' : '断开'),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (_socket.connected)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  FilledButton(onPressed: _onSourcePlay, child: Text('音频播放')),
                  FilledButton(onPressed: _onTranslate, child: Text('开始翻译')),
                ],
              ),
            Container(
              width: double.maxFinite,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('语音识别结果: $transcribeText'),
                  SizedBox(height: 20),
                  Text('翻译结果: $translateText'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
