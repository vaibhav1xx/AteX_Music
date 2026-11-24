import '../models/track.dart';

class RadioStation {
  final String stationUuid;
  final String name;
  final String url;
  final String urlResolved;
  final String? favicon;
  final String tags;
  final String country;
  final String countryCode;
  final int bitrate;
  final String codec;
  final int votes;
  final bool isFavorite;

  const RadioStation({
    required this.stationUuid,
    required this.name,
    required this.url,
    required this.urlResolved,
    this.favicon,
    required this.tags,
    required this.country,
    this.countryCode = '',
    this.bitrate = 0,
    this.codec = 'MP3',
    this.votes = 0,
    this.isFavorite = false,
  });

  RadioStation copyWith({
    String? stationUuid,
    String? name,
    String? url,
    String? urlResolved,
    String? favicon,
    String? tags,
    String? country,
    String? countryCode,
    int? bitrate,
    String? codec,
    int? votes,
    bool? isFavorite,
  }) {
    return RadioStation(
      stationUuid: stationUuid ?? this.stationUuid,
      name: name ?? this.name,
      url: url ?? this.url,
      urlResolved: urlResolved ?? this.urlResolved,
      favicon: favicon ?? this.favicon,
      tags: tags ?? this.tags,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      bitrate: bitrate ?? this.bitrate,
      codec: codec ?? this.codec,
      votes: votes ?? this.votes,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      stationUuid: json['stationuuid'] as String? ?? '',
      name: (json['name'] as String? ?? 'Unnamed Station').trim(),
      url: json['url'] as String? ?? '',
      urlResolved: json['url_resolved'] as String? ?? json['url'] as String? ?? '',
      favicon: (json['favicon'] as String?)?.isNotEmpty == true ? json['favicon'] as String : null,
      tags: (json['tags'] as String? ?? '').trim(),
      country: (json['country'] as String? ?? 'Global').trim(),
      countryCode: (json['countrycode'] as String? ?? '').trim(),
      bitrate: json['bitrate'] as int? ?? 0,
      codec: (json['codec'] as String? ?? 'MP3').trim(),
      votes: json['votes'] as int? ?? 0,
      isFavorite: false,
    );
  }

  Track toTrack() {
    final streamUri = urlResolved.isNotEmpty ? urlResolved : url;
    return Track(
      id: 'radio_$stationUuid',
      title: name,
      artist: tags.isNotEmpty ? tags : 'Live Broadcast',
      album: country.isNotEmpty ? country : 'Global Live Radio',
      duration: Duration.zero,
      coverGradientIndex: stationUuid.hashCode.abs() % 6,
      genre: 'Radio',
      filePath: streamUri,
      localCoverPath: favicon,
      isFavorite: isFavorite,
    );
  }
}
