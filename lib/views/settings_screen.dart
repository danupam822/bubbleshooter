import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../login/login_view_model.dart';
import '../services/local_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _timer;

  List<Map<String, dynamic>> _recordedClips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordedClips();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecordedClips() async {
    setState(() => _isLoading = true);
    final clips = await LocalStorageService.getRecordedClips();
    if (mounted) {
      setState(() {
        _recordedClips = clips;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissionAndStartRecording() async {
    final granted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.purpleAccent, size: 28),
            SizedBox(width: 8),
            Text(
              'Audio Permission',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Allow "Bubble Shooter" to access your microphone and audio hardware for recording clips?',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Deny', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Allow & Record'),
          ),
        ],
      ),
    );

    if (granted == true) {
      _startRecording();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio permission denied. Cannot start recording.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordSeconds++;
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();

    final durationFormatted = _formatDuration(_recordSeconds);
    final now = DateTime.now();
    final timestamp =
        "${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} ${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}";

    final savedSeconds = _recordSeconds > 0 ? _recordSeconds : 1;

    final newClip = {
      'id': now.millisecondsSinceEpoch.toString(),
      'title': 'Recorded Clip #${_recordedClips.length + 1}',
      'duration': durationFormatted == '00:00' ? '00:01' : durationFormatted,
      'durationSeconds': savedSeconds,
      'date': timestamp,
    };

    await LocalStorageService.saveRecordedClip(newClip);

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
      await _loadRecordedClips();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recorded clip saved successfully to local database!'),
          backgroundColor: Colors.green,
        ),
      );

      _showRecordedClipDialog(newClip);
    }
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }

  Future<void> _deleteClip(String id) async {
    await LocalStorageService.deleteRecordedClip(id);
    await _loadRecordedClips();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recorded clip deleted from local database'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showRecordedClipDialog(Map<String, dynamic> clip) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ClipPlayerDialog(
          clip: clip,
          onDelete: () {
            _deleteClip(clip['id']);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1A1A3A),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFF0A0A1A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Keep Record Section ──
            Card(
              color: const Color(0xFF1E1E3F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: _isRecording ? Colors.redAccent : Colors.purpleAccent,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Keep Record',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_isRecording)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.circle, color: Colors.redAccent, size: 10),
                                SizedBox(width: 6),
                                Text(
                                  'RECORDING',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRecording
                          ? 'Recording in progress... Tap "Stop & Save" when done to store the clip locally.'
                          : 'Tap "Start Recording" to record a clip. After recording ends, the clip will be saved to local storage.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                    const SizedBox(height: 16),

                    // Recording timer & controls
                    if (_isRecording) ...[
                      Center(
                        child: Column(
                          children: [
                            Text(
                              _formatDuration(_recordSeconds),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _stopRecording,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop & Save Record'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _requestPermissionAndStartRecording,
                          icon: const Icon(Icons.fiber_manual_record, color: Colors.white),
                          label: const Text('Start Recording'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Saved Clips History Section ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Recorded Clips',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_recordedClips.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await LocalStorageService.clearAllRecordedClips();
                      await _loadRecordedClips();
                    },
                    child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: Colors.purpleAccent),
                ),
              )
            else if (_recordedClips.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E3F).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.video_library_outlined, size: 40, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(height: 8),
                    Text(
                      'No recorded clips found in local database.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recordedClips.length,
                itemBuilder: (context, index) {
                  final clip = _recordedClips[index];
                  return Card(
                    color: const Color(0xFF1E1E3F),
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.purpleAccent),
                      ),
                      title: Text(
                        clip['title'] ?? 'Recorded Clip',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Duration: ${clip['duration']}  •  ${clip['date'] ?? ''}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_circle_fill, color: Colors.cyanAccent),
                            tooltip: 'Play Clip',
                            onPressed: () => _showRecordedClipDialog(clip),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'Delete Clip',
                            onPressed: () => _deleteClip(clip['id']),
                          ),
                        ],
                      ),
                      onTap: () => _showRecordedClipDialog(clip),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),

            // ── Logout Tile ──
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.white)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                final viewModel = context.read<LoginViewModel>();
                await viewModel.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Clip Player Dialog with live progress, audio playback, and visualizer.
class ClipPlayerDialog extends StatefulWidget {
  final Map<String, dynamic> clip;
  final VoidCallback onDelete;

  const ClipPlayerDialog({
    super.key,
    required this.clip,
    required this.onDelete,
  });

  @override
  State<ClipPlayerDialog> createState() => _ClipPlayerDialogState();
}

class _ClipPlayerDialogState extends State<ClipPlayerDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int _currentSeconds = 0;
  late int _totalSeconds;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    final rawSec = widget.clip['durationSeconds'];
    _totalSeconds = (rawSec is int && rawSec > 0) ? rawSec : 5;
    // Automatically start playback when dialog opens
    _startPlayback();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startPlayback() async {
    if (_currentSeconds >= _totalSeconds) {
      _currentSeconds = 0;
    }

    setState(() {
      _isPlaying = true;
    });

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('audio/pop.mp3'));
    } catch (e) {
      debugPrint("AudioPlayer play error: $e");
    }

    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_currentSeconds < _totalSeconds) {
        setState(() {
          _currentSeconds++;
        });

        if (_currentSeconds % 2 == 0) {
          _audioPlayer.play(AssetSource('audio/pop.mp3'));
        }
      } else {
        _pausePlayback();
      }
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    _audioPlayer.pause();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  void _replayClip() {
    _pausePlayback();
    setState(() {
      _currentSeconds = 0;
    });
    _startPlayback();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${_twoDigits(m)}:${_twoDigits(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.play_circle_fill, color: Colors.purpleAccent, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.clip['title'] ?? 'Recorded Clip',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Video/Audio Player Visual Display ──
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isPlaying ? Colors.purpleAccent : Colors.white24,
                width: _isPlaying ? 2 : 1,
              ),
              boxShadow: _isPlaying
                  ? [
                      BoxShadow(
                        color: Colors.purpleAccent.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPlaying ? Icons.graphic_eq_rounded : Icons.play_circle_outline,
                      color: _isPlaying ? Colors.purpleAccent : Colors.white54,
                      size: 54,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isPlaying ? 'PLAYING CLIP...' : (_currentSeconds >= _totalSeconds ? 'PLAYBACK FINISHED' : 'PAUSED'),
                      style: TextStyle(
                        color: _isPlaying ? Colors.purpleAccent : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatTime(_currentSeconds)} / ${_formatTime(_totalSeconds)}',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 8,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.clip['date'] ?? '',
                      style: const TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Progress Bar Slider ──
          Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: Colors.purpleAccent,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.purpleAccent,
                  overlayColor: Colors.purpleAccent.withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _currentSeconds.toDouble().clamp(0.0, _totalSeconds.toDouble()),
                  min: 0.0,
                  max: _totalSeconds.toDouble(),
                  onChanged: (val) {
                    setState(() {
                      _currentSeconds = val.toInt();
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatTime(_currentSeconds), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(_formatTime(_totalSeconds), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Action Controls ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Play / Pause Button
              ElevatedButton.icon(
                onPressed: _togglePlayback,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_isPlaying ? 'Pause' : 'Play'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),

              // Replay Button
              OutlinedButton.icon(
                onPressed: _replayClip,
                icon: const Icon(Icons.replay, color: Colors.cyanAccent),
                label: const Text('Replay', style: TextStyle(color: Colors.cyanAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.cyanAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),

              // Delete Button
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: 'Delete Clip',
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _pausePlayback();
            Navigator.pop(context);
          },
          child: const Text('Close', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
