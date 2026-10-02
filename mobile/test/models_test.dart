import 'package:cloud_storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan duration labels', () {
    Plan p(int days) => Plan(id: 'x', code: 'c', name: 'n', durationDays: days, priceInr: 1);
    expect(p(2).durationLabel, '2 Days');
    expect(p(7).durationLabel, '7 Days');
    expect(p(30).durationLabel, '1 Month');
    expect(p(180).durationLabel, '6 Months');
    expect(p(365).durationLabel, '1 Year');
  });

  test('post parses channel, folder and sorted items', () {
    final post = Post.fromJson({
      'id': 'p1',
      'channel_id': 'c1',
      'folder_id': 'f1',
      'title': 'Hello',
      'caption': null,
      'published_at': '2026-10-01T10:00:00Z',
      'view_count': 3,
      'channels': {'name': 'Friends Status', 'icon_url': null},
      'post_items': [
        {'id': 'b', 'kind': 'image', 'is_premium': false, 'media_key': 'k2', 'position': 1},
        {'id': 'a', 'kind': 'video', 'is_premium': true, 'media_key': 'k1', 'thumb_key': 't1', 'position': 0},
      ],
    });
    expect(post.channelName, 'Friends Status');
    expect(post.folderId, 'f1');
    expect(post.items.map((i) => i.id), ['a', 'b']);
    expect(post.cover!.isVideo, isTrue);
    expect(post.hasPremium, isTrue);
    expect(post.cover!.thumbUrl, endsWith('/storage/v1/object/public/public/t1'));
  });

  test('status parses premium and storage', () {
    final s = UserStatus.fromJson({
      'user_id': 'u',
      'display_name': 'User-1',
      'is_guest': false,
      'source': 'ads',
      'is_premium': true,
      'plan_name': 'Gold Plan',
      'plan_ends_at': '2026-11-01T00:00:00Z',
      'used_bytes': 1024,
      'quota_bytes': 2199023255552,
    });
    expect(s.isPremium, isTrue);
    expect(s.source, 'ads');
    expect(s.quotaBytes, 2199023255552);
  });

  test('channel folder count from embedded count', () {
    final c = Channel.fromJson({
      'id': 'c',
      'name': 'Sports',
      'members_count': 534,
      'channel_folders': [
        {'count': 6}
      ],
    });
    expect(c.foldersCount, 6);
    expect(c.reviewStatus, 'approved');
  });
}
