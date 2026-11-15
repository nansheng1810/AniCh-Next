import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xs/src/pages/local_media/storage.dart';

/// 本地视频播放页：支持续播、键盘快捷键与全屏。
class LocalVideoPage extends StatefulWidget {
  const LocalVideoPage({
    required this.path,
    required this.title,
    super.key,
  });

  final String path;
  final String title;

  @override
  State<LocalVideoPage> createState() => _LocalVideoPageState();
}

class _LocalVideoPageState extends State<LocalVideoPage> {
  late final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<String>? _errorSub;
  Timer? _saveTimer;
  Timer? _hideTimer;

  int _position = 0;
  int _duration = 0;
  bool _controls = true;
  bool _buffering = true;
  bool _restored = false;
  bool _fullscreen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _positionSub = _player.stream.position.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() => _position = position.inMilliseconds);
    });
    _durationSub = _player.stream.duration.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() => _duration = duration.inMilliseconds);
      _restoreProgress(duration.inMilliseconds);
    });
    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() => _buffering = buffering);
      }
    });
    _errorSub = _player.stream.error.listen((error) {
      if (mounted) {
        setState(() => _error = error);
      }
    });
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _save());
    _open();
    _restartHideTimer();
  }

  Future<void> _open() async {
    try {
      await _player.open(Media(widget.path), play: true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  void _restoreProgress(int duration) {
    if (_restored || duration <= 0) {
      return;
    }
    _restored = true;
    final saved = LocalMediaStorage.progressOf(widget.path);
    if (saved != null &&
        saved.hasProgress &&
        saved.position < duration - 3000) {
      _player.seek(Duration(milliseconds: saved.position));
    }
  }

  void _save() {
    if (_duration <= 0) {
      return;
    }
    if (_position >= _duration * 0.95) {
      LocalMediaStorage.clearProgress(widget.path);
      return;
    }
    LocalMediaStorage.saveProgress(widget.path, _position, _duration);
  }

  void _togglePlay() {
    if (_player.state.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    _showControls();
  }

  void _seekBy(int milliseconds) {
    final target = (_position + milliseconds).clamp(0, _duration);
    _player.seek(Duration(milliseconds: target));
    _showControls();
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) {
      _restartHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _showControls() {
    if (!_controls) {
      setState(() => _controls = true);
    }
    _restartHideTimer();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing) {
        setState(() => _controls = false);
      }
    });
  }

  Future<void> _back() async {
    _save();
    if (_fullscreen) {
      await windowManager.setFullScreen(false);
    }
    Get.back();
  }

  Future<void> _toggleFullscreen() async {
    if (!Platform.isWindows) {
      return;
    }
    _fullscreen = !_fullscreen;
    await windowManager.setFullScreen(_fullscreen);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekBy(-5000);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _seekBy(5000);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _player.setVolume((_player.state.volume + 10).clamp(0, 100));
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _player.setVolume((_player.state.volume - 10).clamp(0, 100));
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _format(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _save();
    _saveTimer?.cancel();
    _hideTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    WakelockPlus.disable();
    if (_fullscreen) {
      windowManager.setFullScreen(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = _duration > 0 ? _duration.toDouble() : 1.0;
    final value = _position.toDouble().clamp(0.0, max);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onHover: (_) => _showControls(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Video(
                    controller: _videoController,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                  ),
                ),
                if (_buffering)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '无法播放该文件\n$_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                AnimatedOpacity(
                  opacity: _controls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      bottom: 24,
                      left: 8,
                      right: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _back,
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '全屏（F）',
                          onPressed: _toggleFullscreen,
                          icon: Icon(
                            _fullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  left: 0,
                  right: 0,
                  bottom: _controls ? 0 : -120,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                      top: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: value,
                            max: max,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white24,
                            onChanged: (next) {
                              _player
                                  .seek(Duration(milliseconds: next.toInt()));
                              setState(() => _position = next.toInt());
                            },
                            onChangeEnd: (_) => _save(),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _togglePlay,
                              icon: Icon(
                                _player.state.playing
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_format(_position)} / ${_format(_duration)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              '空格 播放/暂停 · ← → 快进退 · F 全屏',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
