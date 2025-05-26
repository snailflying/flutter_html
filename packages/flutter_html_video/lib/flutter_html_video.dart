library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_video/adaptive_controls.dart';
import 'package:html/dom.dart' as dom;
import 'package:video_player/video_player.dart';

import 'chewie.dart';

/// [VideoHtmlExtension] adds support for the <video> tag to the flutter_html
/// library.
class VideoHtmlExtension extends HtmlExtension {
  final VideoControllerCallback? videoControllerCallback;

  const VideoHtmlExtension({
    this.videoControllerCallback,
  });

  @override
  Set<String> get supportedTags => {"video"};

  @override
  InlineSpan build(ExtensionContext context) {
    return WidgetSpan(
        child: VideoWidget(
      context: context,
      callback: videoControllerCallback,
    ));
  }

  @override
  void onDispose() {
    super.onDispose();
  }
}

typedef VideoControllerCallback = void Function(dom.Element?, CustomChewieController, VideoPlayerController);

/// A VideoWidget for displaying within the HTML tree.
class VideoWidget extends StatefulWidget {
  final ExtensionContext context;
  final VideoControllerCallback? callback;
  final List<DeviceOrientation>? deviceOrientationsOnEnterFullScreen;
  final List<DeviceOrientation> deviceOrientationsAfterFullScreen;

  const VideoWidget({
    super.key,
    required this.context,
    this.callback,
    this.deviceOrientationsOnEnterFullScreen,
    this.deviceOrientationsAfterFullScreen = DeviceOrientation.values,
  });

  @override
  State<StatefulWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> with AutomaticKeepAliveClientMixin {
  CustomChewieController? _chewieController;
  VideoPlayerController? _videoController;
  double? _width;
  double? _height;

  //modify by 大强 横竖比修正[Start]
  double? _widthVideo;
  double? _heightVideo;

  //modify by 大强 横竖比修正[End]
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final attributes = widget.context.attributes;

    final sources = <String?>[
      if (attributes['src'] != null) attributes['src'],
      ...ReplacedElement.parseMediaSources(widget.context.node.children),
    ];

    final givenWidth = double.tryParse(attributes['width'] ?? "");
    final givenHeight = double.tryParse(attributes['height'] ?? "");

    if (sources.isNotEmpty && sources.first != null) {
      _width = givenWidth ?? (givenHeight ?? 150) * 2;
      _height = givenHeight ?? (givenWidth ?? 300) / 2;
      Uri sourceUri = Uri.parse(sources.first!);
      switch (sourceUri.scheme) {
        case 'asset':
          _videoController = VideoPlayerController.asset(sourceUri.path);
          break;
        case 'file':
          _videoController =
              VideoPlayerController.file(File.fromUri(sourceUri));
          break;
        default:
          _videoController = VideoPlayerController.networkUrl(sourceUri);
          break;
      }
      _chewieController = CustomChewieController(
        videoPlayerController: _videoController!,
        placeholder: attributes['poster'] != null && attributes['poster']!.isNotEmpty
            ? Image.network(attributes['poster']!)
            : Container(color: Colors.black),
        autoPlay: attributes['autoplay'] != null,
        looping: attributes['loop'] != null,
        showControls: attributes['controls'] != null,
        autoInitialize: true,
        customControls: const CustomAdaptiveControls(),
        aspectRatio: _widthVideo == null || _heightVideo == null ? null : _widthVideo! / _heightVideo!,
        deviceOrientationsOnEnterFullScreen: widget.deviceOrientationsOnEnterFullScreen,
        deviceOrientationsAfterFullScreen: widget.deviceOrientationsAfterFullScreen,
      );
      _videoController?.addListener(() {
        try {
          setState(() {
            if (_videoController?.value.isInitialized == true) {
              _widthVideo = _videoController?.value.size.width.toDouble();
              _heightVideo = _videoController?.value.size.height.toDouble();
              _chewieController = _chewieController?.copyWith(
                  aspectRatio: _widthVideo == null || _heightVideo == null || _heightVideo == 0
                      ? null
                      : _widthVideo! / _heightVideo!);
            }
          });
        } catch (e) {}
      });
      widget.callback?.call(
        widget.context.element,
        _chewieController!,
        _videoController!,
      );
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext bContext) {
    //fix:解决视频跳动问题(有时候展示，有时候隐藏)
    //if (_chewieController == null || _videoController?.value.isInitialized != true) {
    if (_chewieController == null) {
      return const SizedBox(height: 0, width: 0);
    }

    return AspectRatio(
      aspectRatio: _width! / _height!,
      child: CustomChewie(
        controller: _chewieController!,
      ),
    );
  }
}
