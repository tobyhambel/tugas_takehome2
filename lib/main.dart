import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

// HALAMAN UTAMA DAN NAVIGASI

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int selectedIndex = 0;

  List<Map<String, dynamic>> likedSongs = [];

  // LOAD DATA FAVORIT
  Future<void> loadLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();

    final savedSongs = prefs.getString('likedSongs');

    if (savedSongs != null) {
      final List<dynamic> decoded = jsonDecode(savedSongs);

      if (!mounted) return;

      setState(() {
        likedSongs = decoded
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    }
  }

  // LIKE / UNLIKE
  Future<void> toggleLikedSong(
      Map<String, dynamic> song) async {
    final index = likedSongs.indexWhere(
          (item) => item['trackId'] == song['trackId'],
    );

    setState(() {
      if (index == -1) {
        likedSongs.add(song);
      } else {
        likedSongs.removeAt(index);
      }
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'likedSongs',
      jsonEncode(likedSongs),
    );
  }

  @override
  void initState() {
    super.initState();
    loadLikedSongs();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: [
            MusicPage(
              likedSongs: likedSongs,
              onToggleLike: toggleLikedSong,
            ),
            ProfilePage(
              likedSongs: likedSongs,
            ),
          ],
        ),

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.music_note),
              label: 'Musik',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// HALAMAN PEMUTARAN MUSIK

class MusicPage extends StatefulWidget {
  final List<Map<String, dynamic>> likedSongs;
  final Future<void> Function(Map<String, dynamic>) onToggleLike;

  const MusicPage({
    super.key,
    required this.likedSongs,
    required this.onToggleLike,
  });

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final controller = TextEditingController();

  List<dynamic> songs = [];
  bool isLoading = false;
  String errorMessage = '';

  Future<void> carilagu() async {
    if (controller.text.trim().isEmpty) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
      songs = [];
    });

    try {
      final url = Uri.https(
        'itunes.apple.com',
        '/search',
        <String, String>{
          'term': controller.text.trim(),
          'limit': '10',
          'entity': 'song',
        },
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (!mounted) return;

        setState(() {
          songs = data['results'] ?? [];
        });

        debugPrint('Jumlah lagu: ${songs.length}');
      } else {
        setState(() {
          errorMessage = 'Gagal mengambil data lagu.';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Judul lagu atau artis',
              ),
              onSubmitted: (value) {
                carilagu();
              },
            ),

            ElevatedButton(
              onPressed: isLoading ? null : carilagu,
              child: const Text('Cari Lagu'),
            ),

            if (isLoading)
              const CircularProgressIndicator(),

            if (errorMessage.isNotEmpty)
              Text(errorMessage),

            Expanded(
              child: songs.isEmpty
                  ? const Center(
                child: Text('Belum ada hasil pencarian'),
              )
                  : ListView.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];

                  return ListTile(
                    leading: song['artworkUrl60'] != null
                        ? Image.network(
                      song['artworkUrl60'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                        : const Icon(Icons.music_note),

                    title: Text(
                      song['trackName'] ?? '-',
                    ),

                    subtitle: Text(
                      song['artistName'] ?? '-',
                    ),

                    trailing: const Icon(
                      Icons.chevron_right,
                    ),

                    onTap: () {
                      final selectedSong =
                      Map<String, dynamic>.from(song);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailLaguPage(
                            title: song['trackName'] ?? '-',
                            artist: song['artistName'] ?? '-',
                            artwork: song['artworkUrl100'] ?? '',
                            previewUrl:
                            song['previewUrl']?.toString() ?? '',

                            isLiked: widget.likedSongs.any(
                                  (item) =>
                              item['trackId'] == song['trackId'],
                            ),

                            onToggleLike: () {
                              return widget.onToggleLike(
                                selectedSong,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// HALAMAN PROFILE

class ProfilePage extends StatelessWidget {
  final List<Map<String, dynamic>> likedSongs;

  const ProfilePage({
    super.key,
    required this.likedSongs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Profile'),
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'My Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Image.network(
                  'https://i.pravatar.cc/',
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return const CircleAvatar(
                      radius: 50,
                      child: Icon(
                        Icons.person,
                        size: 60,
                      ),
                    );
                  },
                ),

                const SizedBox(width: 20),

                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text('test@gmail.com'),

                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: Colors.blue,
                          ),
                          Text('Jakarta, Indonesia'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            const Divider(),

            const SizedBox(height: 10),

            const Text(
              'Lagu yang Disukai',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (likedSongs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Belum ada lagu yang disukai',
                  ),
                ),
              )
            else
              ...likedSongs.map((song) {
                return ListTile(
                  leading: Image.network(
                    song['artworkUrl60'] ?? '',
                    width: 50,
                    height: 50,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.music_note);
                    },
                  ),

                  title: Text(
                    song['trackName'] ?? '-',
                  ),

                  subtitle: Text(
                    song['artistName'] ?? '-',
                  ),

                  trailing: const Icon(
                    Icons.favorite,
                    color: Colors.red,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// HALAMAN DETAIL LAGU

class DetailLaguPage extends StatefulWidget {
  final String title;
  final String artist;
  final String artwork;
  final String previewUrl;
  final bool isLiked;
  final Future<void> Function() onToggleLike;

  const DetailLaguPage({
    super.key,
    required this.title,
    required this.artist,
    required this.artwork,
    required this.previewUrl,
    required this.isLiked,
    required this.onToggleLike,
  });

  @override
  State<DetailLaguPage> createState() => _DetailLaguPageState();
}

class _DetailLaguPageState extends State<DetailLaguPage> {
  late AudioPlayer player;

  late bool isLiked;

  PlayerState playerState = PlayerState.stopped;
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();

    isLiked = widget.isLiked;

    player = AudioPlayer();

    player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;

      setState(() {
        playerState = state;
      });
    });
  }

  // PLAY / PAUSE
  Future<void> playLagu() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      if (playerState == PlayerState.playing) {
        await player.pause();
      } else if (playerState == PlayerState.paused) {
        await player.resume();
      } else {
        await player.play(
          UrlSource(widget.previewUrl),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Gagal memutar lagu: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // LIKE / UNLIKE
  Future<void> likeLagu() async {
    await widget.onToggleLike();

    if (!mounted) return;

    setState(() {
      isLiked = !isLiked;
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Lagu'),
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.artwork.isNotEmpty)
                Image.network(
                  widget.artwork,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                ),

              const SizedBox(height: 24),

              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.artist,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 30),

              // TOMBOL PLAY / PAUSE
              IconButton(
                onPressed: isLoading ? null : playLagu,
                iconSize: 64,
                icon: Icon(
                  playerState == PlayerState.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
              ),

              Text(
                playerState == PlayerState.playing
                    ? 'Sedang diputar'
                    : playerState == PlayerState.paused
                    ? 'Dijeda'
                    : 'Tekan Play untuk memutar lagu',
              ),

              const SizedBox(height: 15),

              // TOMBOL LIKE / UNLIKE
              ElevatedButton.icon(
                onPressed: likeLagu,
                icon: Icon(
                  isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                label: Text(
                  isLiked ? 'Unlike' : 'Like',
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: isLiked
                      ? Colors.red
                      : Colors.blue,
                ),
              ),

              if (isLoading)
                const CircularProgressIndicator(),

              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}