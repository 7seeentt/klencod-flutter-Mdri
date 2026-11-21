import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.you.music.channel',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
    ),
  );
  runApp(const MyApp());
}

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.setLoopMode(LoopMode.off);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  Future<void> setAudioSource(Uri uri) async {
    await _player.setAudioSource(AudioSource.uri(uri));
  }

  @override
  Future<void> skipToNext() async {
    // منطق التالي
  }

  @override
  Future<void> skipToPrevious() async {
    // منطق السابق
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF1DB954),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _songs = [];
  SongModel? _currentSong;
  bool _isPlaying = false;
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      _loadSongs();
    } else {
      // التعامل مع الرفض
    }
  }

  Future<void> _loadSongs() async {
    bool permissionStatus = await _audioQuery.permissionsStatus();
    if (!permissionStatus) {
      await _audioQuery.permissionsRequest();
    }
    _songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    setState(() {});
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    setState(() {
      _currentIndex = index;
      _currentSong = _songs[index];
    });

    final handler = AudioService.instance as MyAudioHandler;
    await handler.setAudioSource(Uri.parse(_songs[index].uri));
    await handler.play();
    setState(() {
      _isPlaying = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A22),
          title: const Text('Music Flutter'),
          bottom: const TabBar(
            indicatorColor: Color(0xFF1DB954),
            tabs: [
              Tab(text: 'المشغل'),
              Tab(text: 'المكتبة'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPlayer(),
            _buildLibrary(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF651FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(
            _currentSong?.title ?? 'اختر أغنية',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Text(
            _currentSong?.artist ?? 'فنان غير معروف',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          // شريط التقدم
          const Slider(
            value: 0,
            onChanged: null,
            activeColor: Color(0xFF1DB954),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 50,
                icon: const Icon(Icons.skip_previous),
                onPressed: () {
                  if (_currentIndex > 0) _playSong(_currentIndex - 1);
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 80,
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                color: const Color(0xFF1DB954),
                onPressed: () async {
                  final handler = AudioService.instance as MyAudioHandler;
                  if (_isPlaying) {
                    await handler.pause();
                  } else {
                    await handler.play();
                  }
                  setState(() {
                    _isPlaying = !_isPlaying;
                  });
                },
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 50,
                icon: const Icon(Icons.skip_next),
                onPressed: () {
                  if (_currentIndex < _songs.length - 1) _playSong(_currentIndex + 1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLibrary() {
    return ListView.builder(
      itemCount: _songs.length,
      itemBuilder: (context, index) {
        final song = _songs[index];
        return ListTile(
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.artist ?? 'غير معروف'),
          onTap: () => _playSong(index),
        );
      },
    );
  }
}