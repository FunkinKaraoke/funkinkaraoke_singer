class Song {
  final String id;
  final String title;
  final String artist;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
  });

  factory Song.fromDoc(String id, Map<String, dynamic> data) {
    return Song(
      id: id,
      title: (data['title'] ?? '') as String,
      artist: (data['artist'] ?? '') as String,
    );
  }
}
