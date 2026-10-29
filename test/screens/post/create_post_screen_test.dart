import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiehub/screens/post/create_post_screen.dart';
import 'package:foodiehub/services/post_service.dart';
import 'package:image_picker/image_picker.dart';

const _pngBytes = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  0,
  0,
  3,
  1,
  1,
  0,
  201,
  254,
  146,
  239,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

void main() {
  late FakePostService postService;
  late List<ImageSource> pickedSources;
  late int postedCallbackCount;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<XFile?> Function(ImageSource source)? pickImage,
    Future<XFile?> Function()? pickVideo,
    String? communityId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostScreen(
          onPosted: () => postedCallbackCount++,
          communityId: communityId,
          postService: postService,
          pickImage: pickImage,
          pickVideo: pickVideo,
        ),
      ),
    );
  }

  Future<void> selectGalleryImage(WidgetTester tester) async {
    await tester.tap(find.text('เพิ่มรูปภาพ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือกรูปจากอัลบั้ม'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    postService = FakePostService();
    pickedSources = [];
    postedCallbackCount = 0;
  });

  testWidgets('shows the create-post form and publish action', (tester) async {
    await pumpScreen(tester);

    expect(find.text('สร้างโพสต์'), findsOneWidget);
    expect(find.text('โพสต์'), findsOneWidget);
    expect(find.text('ข้อความ (จำเป็น)'), findsOneWidget);
    expect(find.text('สถานที่ (ไม่บังคับ)'), findsOneWidget);
  });

  testWidgets('caption field has a required accessible label and 1000 limit', (
    tester,
  ) async {
    await pumpScreen(tester);

    final captionField = tester.widget<TextField>(find.byType(TextField).first);
    expect(captionField.decoration!.labelText, 'ข้อความ (จำเป็น)');
    expect(captionField.maxLength, 1000);
  });

  testWidgets('location field is explicitly marked optional with 120 limit', (
    tester,
  ) async {
    await pumpScreen(tester);

    final locationField = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );
    expect(locationField.decoration!.labelText, 'สถานที่ (ไม่บังคับ)');
    expect(locationField.maxLength, 120);
  });

  testWidgets('image picker control has a screen-reader label and hint', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await pumpScreen(tester);

    final semantics = tester.getSemantics(
      find.bySemanticsLabel(RegExp('เพิ่มรูปภาพ')).first,
    );
    expect(semantics.label, contains('เพิ่มรูปภาพ'));
    expect(semantics.hint, contains('วิดีโอสั้น'));
    semanticsHandle.dispose();
  });

  testWidgets('gallery source passes the selected source to image picker', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      pickImage: (source) async {
        pickedSources.add(source);
        return XFile.fromData(Uint8List.fromList(_pngBytes), name: 'food.png');
      },
    );

    await selectGalleryImage(tester);

    expect(pickedSources, [ImageSource.gallery]);
    expect(find.byTooltip('ลบรูปภาพ'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('รูปภาพที่เลือก')), findsOneWidget);
    semanticsHandle.dispose();
  });

  testWidgets('camera source passes the selected source to image picker', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      pickImage: (source) async {
        pickedSources.add(source);
        return XFile.fromData(Uint8List.fromList(_pngBytes), name: 'food.png');
      },
    );

    await tester.tap(find.text('เพิ่มรูปภาพ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ถ่ายรูป'));
    await tester.pumpAndSettle();

    expect(pickedSources, [ImageSource.camera]);
    expect(find.byTooltip('ลบรูปภาพ'), findsOneWidget);
  });

  testWidgets('canceling image source selection does not invoke picker', (
    tester,
  ) async {
    var pickerCalls = 0;
    await pumpScreen(
      tester,
      pickImage: (source) async {
        pickerCalls++;
        return null;
      },
    );

    await tester.tap(find.text('เพิ่มรูปภาพ'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(pickerCalls, 0);
    expect(find.text('เพิ่มรูปภาพ'), findsOneWidget);
  });

  testWidgets('empty form cannot be submitted and shows validation feedback', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('โพสต์'));
    await tester.pump();

    expect(find.text('กรุณาเขียนข้อความก่อนโพสต์'), findsOneWidget);
    expect(postService.createCalls, 0);
  });

  testWidgets('publishes a text-only post without requiring media', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'อร่อยมาก');

    await tester.tap(find.text('โพสต์'));
    await tester.pumpAndSettle();

    expect(postService.createCalls, 1);
    expect(postService.lastCaption, 'อร่อยมาก');
    expect(postService.lastMedia, isNull);
    expect(postedCallbackCount, 1);
  });

  testWidgets('publishes a text post to its community', (tester) async {
    await pumpScreen(tester, communityId: 'community-1');
    await tester.enterText(find.byType(TextField).first, 'ประกาศจากกลุ่ม');

    await tester.tap(find.text('โพสต์'));
    await tester.pumpAndSettle();

    expect(postService.lastCommunityId, 'community-1');
  });

  testWidgets('selects and publishes a short video', (tester) async {
    final video = XFile.fromData(
      Uint8List.fromList([0, 0, 0, 0]),
      name: 'clip.mp4',
    );
    await pumpScreen(tester, pickVideo: () async => video);
    await tester.enterText(find.byType(TextField).first, 'คลิปสั้น');
    await tester.tap(find.text('เพิ่มรูปภาพ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือกวิดีโอสั้น (ไม่เกิน 60 วินาที)'));
    await tester.pumpAndSettle();

    expect(find.text('วิดีโอสั้นพร้อมโพสต์'), findsOneWidget);
    await tester.tap(find.text('โพสต์'));
    await tester.pumpAndSettle();

    expect(postService.lastMedia, video);
    expect(postService.lastMediaType, 'video');
    expect(postedCallbackCount, 1);
  });

  testWidgets('publishes trimmed text, clears the draft, and calls callback', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      pickImage: (source) async =>
          XFile.fromData(Uint8List.fromList(_pngBytes), name: 'food.png'),
    );
    await tester.enterText(find.byType(TextField).first, '  อร่อยมาก  ');
    await tester.enterText(find.byType(TextField).at(1), '  ร้านอร่อย  ');
    await selectGalleryImage(tester);

    await tester.tap(find.text('โพสต์'));
    await tester.pumpAndSettle();

    expect(postService.createCalls, 1);
    expect(postService.lastCaption, 'อร่อยมาก');
    expect(postService.lastLocation, 'ร้านอร่อย');
    expect(postedCallbackCount, 1);
    expect(find.text('โพสต์ของคุณถูกเผยแพร่แล้ว'), findsOneWidget);
    expect(find.byTooltip('ลบรูปภาพ'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
  });

  testWidgets('failed publish preserves the draft and re-enables the form', (
    tester,
  ) async {
    postService.failure = StateError('network unavailable');
    await pumpScreen(
      tester,
      pickImage: (source) async =>
          XFile.fromData(Uint8List.fromList(_pngBytes), name: 'food.png'),
    );
    await tester.enterText(find.byType(TextField).first, 'เก็บฉบับร่าง');
    await selectGalleryImage(tester);

    await tester.tap(find.text('โพสต์'));
    await tester.pumpAndSettle();

    expect(find.textContaining('โพสต์ไม่สำเร็จ:'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'เก็บฉบับร่าง',
    );
    expect(find.byTooltip('ลบรูปภาพ'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isTrue,
    );
    expect(postedCallbackCount, 0);
  });

  testWidgets('prevents duplicate submit and locks edits while saving', (
    tester,
  ) async {
    final completer = Completer<void>();
    postService.pendingCreate = completer.future;
    await pumpScreen(
      tester,
      pickImage: (source) async =>
          XFile.fromData(Uint8List.fromList(_pngBytes), name: 'food.png'),
    );
    await tester.enterText(find.byType(TextField).first, 'โพสต์หนึ่งครั้ง');
    await selectGalleryImage(tester);

    await tester.tap(find.text('โพสต์'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(postService.createCalls, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );
    expect(find.bySemanticsLabel('กำลังเผยแพร่โพสต์'), findsOneWidget);
    completer.complete();
    await tester.pumpAndSettle();

    expect(postedCallbackCount, 1);
  });

  testWidgets('remove-image action clears the selected preview', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      pickImage: (source) async =>
          XFile.fromData(Uint8List.fromList(_pngBytes), name: 'food.png'),
    );
    await selectGalleryImage(tester);
    await tester.tap(find.byTooltip('ลบรูปภาพ'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('ลบรูปภาพ'), findsNothing);
    expect(find.text('เพิ่มรูปภาพ'), findsOneWidget);
  });

  testWidgets('image-picker errors are announced and picker can be retried', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    var pickerCalls = 0;
    await pumpScreen(
      tester,
      pickImage: (source) async {
        pickerCalls++;
        if (pickerCalls == 1) throw StateError('permission denied');
        return XFile.fromData(Uint8List.fromList(_pngBytes), name: 'food.png');
      },
    );

    await tester.tap(find.text('เพิ่มรูปภาพ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือกรูปจากอัลบั้ม'));
    await tester.pumpAndSettle();

    expect(find.textContaining('เลือกสื่อไม่สำเร็จ:'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp('เพิ่มรูปภาพ')).first)
          .label,
      contains('เพิ่มรูปภาพ'),
    );

    await tester.tap(find.text('เพิ่มรูปภาพ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เลือกรูปจากอัลบั้ม'));
    await tester.pumpAndSettle();

    expect(pickerCalls, 2);
    expect(find.byTooltip('ลบรูปภาพ'), findsOneWidget);
    semanticsHandle.dispose();
  });
}

class FakePostService extends PostService {
  int createCalls = 0;
  String? lastCaption;
  String? lastLocation;
  XFile? lastMedia;
  String? lastMediaType;
  String? lastCommunityId;
  Object? failure;
  Future<void>? pendingCreate;

  @override
  Future<void> createPost({
    required String caption,
    required String location,
    XFile? media,
    String? mediaType,
    String? communityId,
  }) async {
    createCalls++;
    lastCaption = caption;
    lastLocation = location;
    lastMedia = media;
    lastMediaType = mediaType;
    lastCommunityId = communityId;
    if (pendingCreate != null) await pendingCreate;
    if (failure != null) throw failure!;
  }
}
