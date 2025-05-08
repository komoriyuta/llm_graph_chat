import 'package:markdown/markdown.dart' as md;

class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\$([^$\n]+?)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!));
    return true;
  }
}

class BlockMathSyntax extends md.BlockSyntax {
  static final _startPattern = RegExp(r'^\$\$\s*$');
  static final _endPattern = RegExp(r'^\$\$\s*$');
  RegExp get pattern => _startPattern;

  const BlockMathSyntax();

  @override
  bool canParse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content);
    return match != null;
  }

  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    final lines = <String>[];

    while (!parser.isDone) {
      final line = parser.current.content;
      if (_endPattern.hasMatch(line)) {
        parser.advance();
        break;
      }
      lines.add(line);
      parser.advance();
    }

    final content = lines.join('\n');
    return md.Element('math', [md.Text('\n$content\n')]);
  }
}