import 'package:AIRA/models/radio.dart';
import 'package:AIRA/utils/ai_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:velocity_x/velocity_x.dart';
import 'dart:typed_data';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const MethodChannel _platform = MethodChannel('cheetah_transcription');
  List<MyRadio> radios = [];
  MyRadio? _selectedRadio;
  Color? _selectedColor;
  bool _isPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  PorcupineManager? _porcupineManager;
  late stt.SpeechToText _speech;
  bool _isSpeechAvailable = false;
  String _cheetahTranscript = "";
  static const platform = MethodChannel("com.example.cheetah/stt");

  @override
  void initState() {
    super.initState();
    fetchRadios();
    initAudioPlayer();
    initSpeech();
    initPorcupine();
    initCheetah();
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'onTranscript') {
        final transcript = call.arguments as String;
        print("Transcript from Cheetah: $transcript");
        setState(() {
          _cheetahTranscript += transcript + " ";
        });
        if (transcript.toLowerCase().contains("play music")) {
          if (!_isPlaying && _selectedRadio != null) {
            _playMusic(_selectedRadio!.url);
          }
        } else if (transcript.toLowerCase().contains("stop")) {
          _audioPlayer.stop();
        }
      }
    });
  }

  Future<void> initCheetah() async {
    try {
      final result = await platform.invokeMethod("initCheetah");
      print("Cheetah Init: \$result");
    } catch (e) {
      print("Failed to init Cheetah: \$e");
    }
  }

  Future<void> startCheetahTranscription() async {
    try {
      await _platform.invokeMethod('startTranscription');
    } on PlatformException catch (e) {
      print("Failed to start transcription: ${e.message}");
    }
  }

  Future<void> stopCheetahTranscription() async {
    try {
      await _platform.invokeMethod('stopTranscription');
    } on PlatformException catch (e) {
      print("Failed to stop transcription: ${e.message}");
    }
  }


  Future<String> transcribeWithCheetah(Uint8List audioBytes) async {
    try {
      final result = await platform.invokeMethod("transcribeAudio", audioBytes);
      return result;
    } catch (e) {
      print("Cheetah transcription error: \$e");
      return "";
    }
  }

  Future<void> fetchRadios() async {
    final radioJson = await rootBundle.loadString("assets/radio.json");
    radios = MyRadioList.fromJson(radioJson).radios;
    setState(() {});
  }

  void initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((event) {
      _isPlaying = event == PlayerState.playing;
      setState(() {});
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  void initSpeech() async {
    _speech = stt.SpeechToText();
    _isSpeechAvailable = await _speech.initialize();
  }

  Future<void> initPorcupine() async {
    try {
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
          "PgugZ5fBW4wJwZepkKSzxyPhLW6kavyZC84zK5zDejCqTzHu/xHwlQ==",
          ['assets/wake_words/Hello-AIRA_en_android_v3_0_0.ppn'],
          _wakeWordCallback
      );

      await _porcupineManager?.start();
    } on PorcupineException catch (err) {
      print("Porcupine Init Error: \$err");
    }
  }

  void _wakeWordCallback(int keywordIndex) async {
    print("Wake word detected!");
    startCheetahTranscription();
    if (_isSpeechAvailable) {
      await _speech.listen(
        onResult: (result) async {
          final command = result.recognizedWords.toLowerCase();
          print("Recognized command: \$command");

          if (command.contains("play music")) {
            if (!_isPlaying && _selectedRadio != null) {
              _playMusic(_selectedRadio!.url);
            }
          } else if (command.contains("stop")) {
            _audioPlayer.stop();
          }

          // Optional: simulate audio byte input for Cheetah
          // Uint8List fakeAudio = ...;
          // final cheetahTranscript = await transcribeWithCheetah(fakeAudio);
          // print("Cheetah transcript: \$cheetahTranscript");
        },
        listenFor: Duration(seconds: 5),
        pauseFor: Duration(seconds: 2),
        localeId: "en_US",
        cancelOnError: true,
        partialResults: false,
      );
    }
  }

  Future<void> _playMusic(String url) async {
    try {
      _selectedRadio = radios.firstWhere((element) => element.url == url);
      setState(() {});
      await _audioPlayer.stop();
      final source = UrlSource(url);
      await _audioPlayer.setSource(source);
      await Future.delayed(Duration(milliseconds: 500));
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _audioPlayer.resume();
    } catch (e) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _porcupineManager?.stop();
    _porcupineManager?.delete();
    _speech.stop();
    platform.invokeMethod("releaseCheetah");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          VxAnimatedBox()
              .size(context.screenWidth, context.screenHeight)
              .withGradient(
            LinearGradient(
              colors: [AIColors.primaryColor2, _selectedColor ?? AIColors.primaryColor1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          )
              .make(),
          AppBar(
            title: "AI Radio".text.xl4.bold.white.make().shimmer(
              primaryColor: Vx.purple300,
              secondaryColor: Colors.white,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ).h(100).p16(),
          radios.isNotEmpty
              ? VxSwiper.builder(
            itemCount: radios.length,
            aspectRatio: 1.0,
            onPageChanged: (index) {
              final colorHex = radios[index].color;
              _selectedColor = Color(int.parse(colorHex));
            },
            enlargeCenterPage: true,
            itemBuilder: (context, index) {
              final rad = radios[index];
              return VxBox(
                child: ZStack([
                  Positioned(
                    top: 0.0,
                    right: 0.0,
                    child: VxBox(
                      child: rad.category.text.uppercase.white.make().px16(),
                    )
                        .height(40)
                        .black
                        .alignCenter
                        .withRounded(value: 10.0)
                        .make(),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: VStack([
                      rad.name.text.xl3.white.bold.make(),
                      5.heightBox,
                      rad.tagline.text.sm.white.semiBold.make(),
                    ], crossAlignment: CrossAxisAlignment.center),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: VStack([
                      Icon(CupertinoIcons.play_circle, color: Colors.white),
                      10.heightBox,
                      "Double tap to play".text.gray300.make(),
                    ]),
                  ),
                ]),
              )
                  .clip(Clip.antiAlias)
                  .bgImage(
                DecorationImage(
                  image: NetworkImage(rad.image),
                  fit: BoxFit.cover,
                ),
              )
                  .border(color: Colors.black, width: 5.0)
                  .withRounded(value: 60.0)
                  .make()
                  .onInkDoubleTap(() {
                _playMusic(rad.url);
              })
                  .p16();
            },
          ).centered()
              : Center(child: CircularProgressIndicator(backgroundColor: Colors.white)),
          Align(
            alignment: Alignment.bottomCenter,
            child: VStack([
              if (_isPlaying && _selectedRadio != null)
                Text("Playing Now - \${_selectedRadio?.name} FM").text.white.makeCentered(),
              Icon(
                _isPlaying ? CupertinoIcons.stop_circle : CupertinoIcons.play_circle,
                color: Colors.white,
                size: 50.0,
              ).onInkTap(() {
                if (_isPlaying) {
                  _audioPlayer.stop();
                } else if (_selectedRadio != null) {
                  _playMusic(_selectedRadio!.url);
                }
              }),
            ]).pOnly(bottom: context.percentHeight * 12),
          ),
        ],
      ),
    );
  }
}