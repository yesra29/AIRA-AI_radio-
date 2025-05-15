import 'package:AIRA/models/radio.dart';
import 'package:AIRA/utils/ai_utils.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:velocity_x/velocity_x.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MyRadio> radios = [];
  MyRadio? _selectedRadio;
  Color? _selectedColor;
  bool _isPlaying = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    fetchRadios();

    _audioPlayer.onPlayerStateChanged.listen((event) {
      _isPlaying = event == PlayerState.playing;
      setState(() {});
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
      });
    });

    // Handle errors through the state change event
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.stopped) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  Future<void> fetchRadios() async {
    final radioJson = await rootBundle.loadString("assets/radio.json");
    radios = MyRadioList.fromJson(radioJson).radios;

    setState(() {});
  }

  Future<void> _playMusic(String url) async {
    try {
      _selectedRadio = radios.firstWhere((element) => element.url == url);
      setState(() {});
      
      try {
        await _audioPlayer.stop();
        final source = UrlSource(url);
        await _audioPlayer.setSource(source);
        await Future.delayed(Duration(milliseconds: 500));
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.setReleaseMode(ReleaseMode.stop);
        await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
        

        await _audioPlayer.resume();
      } catch (playError) {
        setState(() {
          _isPlaying = false;
        });
      }
    } catch (e) {
      setState(() {
        _isPlaying = false;
      });
    }
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
                  colors: [AIColors.primaryColor2, _selectedColor??AIColors.primaryColor1],
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
                  final colorHex =radios[index].color;
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
                            child:
                                VxBox(
                                      child:
                                          rad.category.text.uppercase.white
                                              .make()
                                              .px16(),
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
                              Icon(
                                CupertinoIcons.play_circle,
                                color: Colors.white,
                              ),
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
                          onError: (exception, stackTrace) {
                            // colorFilter: ColorFilter.mode(
                            //   Colors.black.withOpacity(0.3),
                            //   BlendMode.darken,
                            // ),
                          },
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
              : Center(
                child: CircularProgressIndicator(backgroundColor: Colors.white),
              ),
          Align(
            alignment: Alignment.bottomCenter,
            child: VStack([
              if (_isPlaying && _selectedRadio != null)
                Text(
                  "Playing Now -${_selectedRadio?.name} FM",
                ).text.white.makeCentered(),
              Icon(
                _isPlaying
                    ? CupertinoIcons.stop_circle
                    : CupertinoIcons.play_circle,
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
