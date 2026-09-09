Future<String?> pickTextFile({String accept = '.json'}) async =>
    throw UnsupportedError('파일 가져오기는 웹에서 지원합니다.');
void downloadText({
  required String text,
  required String fileName,
  String mimeType = 'application/json',
}) => throw UnsupportedError('파일 내보내기는 웹에서 지원합니다.');
