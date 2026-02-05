class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.location,
    required this.dateLabel,
    required this.tag,
    required this.description,
    required this.imageAsset,
  });

  final String id;
  final String title;
  final String location;
  final String dateLabel;
  final String tag;
  final String description;
  final String imageAsset;

  factory EventSummary.fromJson(Map<String, dynamic> json) {
    return EventSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      location: json['location'] as String,
      dateLabel: json['dateLabel'] as String,
      tag: json['tag'] as String,
      description: json['description'] as String,
      imageAsset: json['imageAsset'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'dateLabel': dateLabel,
      'tag': tag,
      'description': description,
      'imageAsset': imageAsset,
    };
  }
}
