import 'dart:io';
import 'package:flutter/material.dart';
import 'package:img_syncer/asset.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';

class VideoRoute extends StatefulWidget {
  const VideoRoute({
    Key? key,
    this.asset,
    this.filePath,
  }) : super(key: key);
  final Asset? asset;
  final String? filePath;

  @override
  _VideoRouteState createState() => _VideoRouteState();
}

class _VideoRouteState extends State<VideoRoute> {
  late VideoPlayerController videoPlayerController;
  late ChewieController chewieController;
  bool isInitialized = false;
  String? _tempFilePath;

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  @override
  void dispose() {
    chewieController.dispose();
    videoPlayerController.dispose();
    if (_tempFilePath != null) {
      File(_tempFilePath!).delete().ignore();
    }
    super.dispose();
  }

  Future<void> initializePlayer() async {
    bool initialized = false;
    if (widget.filePath != null) {
      videoPlayerController = VideoPlayerController.file(File(widget.filePath!));
      _tempFilePath = widget.filePath;
    } else if (widget.asset!.hasLocal) {
      final file = await widget.asset!.local!.originFile;
      videoPlayerController = VideoPlayerController.file(file!);
    } else if (widget.asset!.hasRemote) {
      var uri = widget.asset!.remote!.path;
      if (uri[0] != '/') {
        uri = "/$uri";
      }
      final url = "$httpBaseUrl$uri";
      videoPlayerController = VideoPlayerController.network(url);
      try {
        await videoPlayerController.initialize();
        initialized = true;
      } catch (e) {
        // 流式播放失败，回退到完整下载后播放
        final filePath = await widget.asset!.downloadToTmpFilePath();
        _tempFilePath = filePath;
        videoPlayerController.dispose();
        videoPlayerController = VideoPlayerController.file(File(filePath));
        await videoPlayerController.initialize();
        initialized = true;
        SnackBarManager.showSnackBar(l10n.streamFallbackDownload);
      }
    }
    if (!initialized) {
      await videoPlayerController.initialize();
    }
    Widget customControls = const MaterialControls();
    var controlsSafeAreaMinimum = const EdgeInsets.all(0);
    if (Platform.isIOS || Platform.isMacOS) {
      controlsSafeAreaMinimum = const EdgeInsets.fromLTRB(0, 30, 0, 20);
      customControls = const CupertinoControls(
          backgroundColor: AppColors.videoRouteBg,
          iconColor: Colors.white);
    }
    chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: true,
      looping: false,
      showControlsOnInitialize: false,
      showOptions: false,
      customControls: customControls,
      allowFullScreen: false,
      allowMuting: false,
      controlsSafeAreaMinimum: controlsSafeAreaMinimum,
    );
    if (mounted) {
      setState(() {
        isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: isInitialized
                  ? Chewie(
                      controller: chewieController,
                    )
                  : const CircularProgressIndicator(),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.transparent,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
            ),
          ],
        ));
  }
}
