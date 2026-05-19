import 'dart:io';
void main() {
  final dir = Directory('lib');
  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      var newContent = content.replaceAllMapped(RegExp(r'\.withOpacity\(([^)]+)\)'), (m) => '.withValues(alpha: ${m[1]})');
      if (content != newContent) {
        file.writeAsStringSync(newContent);
        print('Fixed ${file.path}');
      }
    }
  }
}
