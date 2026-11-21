import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/widgets/message_link_text.dart';
import 'package:charmi_insta_freelancing/core/link_preview/link_preview_service.dart';
import 'package:charmi_insta_freelancing/core/models/author.dart';

void main() {
  test('link detection does not stop at the letter s and counts www links', () {
    const text =
        'See https://steel.example/products and www.business.example today';
    expect(MessageLinks.pattern.allMatches(text).map((m) => m.group(0)), [
      'https://steel.example/products',
      'www.business.example',
    ]);
    expect(LinkPreviewService.firstUrl(text), 'https://steel.example/products');
    expect(
      LinkPreviewService.firstUrl('visit www.business.example'),
      'https://www.business.example',
    );
  });
  test('company name round-trips and falls back when missing', () {
    final author = Author.fromJson({
      'id': 2,
      'name': 'Personal Name',
      'business_name': 'Steel Company',
    });
    expect(author.displayBusinessName, 'Steel Company');
    expect(Author.fromJson(author.toJson()), author);
    expect(
      const Author(id: 2, name: 'Personal Name').displayBusinessName,
      'Personal Name',
    );
  });
}
