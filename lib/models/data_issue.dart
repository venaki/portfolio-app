class DataIssue {
  final String recordId;
  final String message;

  const DataIssue({required this.recordId, required this.message});

  @override
  String toString() => recordId.isEmpty ? message : '$recordId: $message';
}
