import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../../../core/crypto/note_crypto_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/media/media_storage_service.dart';
import '../../../core/providers/crypto_providers.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/media_providers.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/navigation/noteon_page_route.dart';
import '../../folders/data/folder.dart';
import '../../tags/data/tag.dart';
import '../data/media_ref.dart';
import '../data/note.dart';
import '../data/note_block_model.dart';
import '../data/note_block_ops.dart';
import '../data/note_content_codec.dart';
import '../data/note_local_assist.dart';
import '../data/note_lock_service.dart';
import '../data/note_media_paths.dart';
import '../data/note_ocr_service.dart';
import '../data/noteon_table_data.dart';
import 'note_audio_recorder_sheet.dart';
import 'note_block_chrome.dart';
import 'note_editor_browse_caret_sync.dart';
import 'note_editor_styles.dart';
import 'note_page_background.dart';
import 'note_password_dialogs.dart';
import 'note_share_actions.dart';
import 'noteon_audio_embed.dart';
import 'noteon_image_embed.dart';
import 'noteon_ink_embed.dart';
import 'noteon_pdf_embed.dart';
import 'noteon_table_embed.dart';
import 'note_editor_zoom_viewport.dart';
import 'notes_providers.dart';
import 'pdf_annotator_screen.dart';
import 'sketch_editor_screen.dart';
import '../data/noteon_ink_payload.dart';
import '../data/noteon_pdf_payload.dart';

/// Creates or edits a single note with a Quill rich-text body.
///
/// Saves when leaving if content changed. Blank new notes are discarded.
/// Locked notes stay encrypted on disk; decrypted content lives only in a
/// session while unlocked in this screen.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.initialFolderId,
  });

  /// Existing note id. Null opens a new unsaved draft.
  final Id? noteId;

  /// Optional folder applied to brand-new notes (e.g. active list filter).
  final int? initialFolderId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  late final QuillController _quillController;
  final _editorFocusNode = FocusNode();
  final _titleFocusNode = FocusNode();
  final _editorScrollController = ScrollController();
  final _editorHostKey = GlobalKey();
  final _blockSelection = ValueNotifier<NoteBlockSelection?>(null);
  /// Dirty indicator without rebuilding the Quill editor body.
  final _dirtyListenable = ValueNotifier<bool>(false);
  late final NoteBlockInteraction _blockInteraction;
  late final NoteEditorBrowseCaretSync _browseCaretSync;

  Note? _note;
  bool _loading = true;
  bool _isLocked = false;
  bool _sessionUnlocked = false;
  bool _saving = false;
  bool _busyCrypto = false;
  bool _insertingTable = false;
  /// Compact chrome while the title/body has keyboard focus.
  bool _writingCompact = false;
  Object? _loadError;
  int? _folderId;
  List<int> _tagIds = [];
  Timer? _autosaveTimer;

  /// True when this session created a persisted note that may need discard.
  bool _isNewDraft = false;

  static const _autosaveDelay = Duration(milliseconds: 1200);

  bool get _dirty => _dirtyListenable.value;

  set _dirty(bool value) => _dirtyListenable.value = value;

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _browseCaretSync = NoteEditorBrowseCaretSync(
      controller: _quillController,
      editorHostKey: _editorHostKey,
      scrollController: _editorScrollController,
    );
    _blockInteraction = NoteBlockInteraction(
      selection: _blockSelection,
      controller: _quillController,
      onSelect: _selectBlock,
      onAcceptDrop: ({required fromIndex, required toIndex}) {
        _moveBlock(fromIndex: fromIndex, toIndex: toIndex);
      },
    );
    _titleController.addListener(_markDirty);
    _quillController.addListener(_onQuillChanged);
    _editorFocusNode.addListener(_onWritingFocusChanged);
    _titleFocusNode.addListener(_onWritingFocusChanged);
    _bootstrap();
  }

  void _onQuillChanged() => _markDirty();

  void _onWritingFocusChanged() {
    final compact =
        _editorFocusNode.hasFocus || _titleFocusNode.hasFocus;
    if (compact == _writingCompact || !mounted) {
      return;
    }
    setState(() => _writingCompact = compact);
  }

  void _markDirty() {
    if (!_loading && !_dirty) {
      _dirty = true;
    } else {
      _dirty = true;
    }
    _scheduleAutosave();
  }

  void _scheduleAutosave() {
    if (_loading || _busyCrypto) {
      return;
    }
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, () {
      if (!mounted || !_dirty || _saving || _busyCrypto) {
        return;
      }
      unawaited(_persistChanges(allowDiscardBlankDraft: false));
    });
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(noteRepositoryProvider);
    try {
      if (widget.noteId == null) {
        final id = await repo.create(
          title: '',
          contentJson: NoteContentCodec.emptyDeltaJson(),
          folderId: widget.initialFolderId,
        );
        final note = await repo.getById(id);
        _note = note;
        _folderId = note?.folderId;
        _tagIds = List<int>.from(note?.tagIds ?? const []);
        _isNewDraft = true;
        _isLocked = note?.isLocked ?? false;
      } else {
        final note = await repo.getById(widget.noteId!);
        if (note == null) {
          _loadError = 'missing';
        } else {
          _note = note;
          _isLocked = note.isLocked;
          _folderId = note.folderId;
          _tagIds = List<int>.from(note.tagIds);
          _titleController.text = note.title;
          if (!note.isLocked) {
            _quillController.document = NoteContentCodec.documentFromJson(
              note.contentJson,
            );
          }
        }
      }
    } catch (error) {
      _loadError = error;
    }

    _dirty = false;
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _clearUnlockSession() {
    final session = ref.read(unlockedNoteSessionProvider);
    session?.clearSensitive();
    ref.read(unlockedNoteSessionProvider.notifier).state = null;
    _sessionUnlocked = false;
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _titleController
      ..removeListener(_markDirty)
      ..dispose();
    _quillController
      ..removeListener(_onQuillChanged)
      ..dispose();
    _blockSelection.dispose();
    _dirtyListenable.dispose();
    _editorFocusNode
      ..removeListener(_onWritingFocusChanged)
      ..dispose();
    _titleFocusNode
      ..removeListener(_onWritingFocusChanged)
      ..dispose();
    _editorScrollController.dispose();
    _browseCaretSync.dispose();
    // Session may still be referenced via provider; clear on leave via pop.
    super.dispose();
  }

  String get _contentJson {
    if (_isLocked && !_sessionUnlocked) {
      return '';
    }
    return NoteContentCodec.encodeDocument(_quillController.document);
  }

  List<MediaRef> _currentMediaRefs(String contentJson) {
    final session = ref.read(unlockedNoteSessionProvider);
    final previous = session?.mediaRefs ?? _note?.mediaRefs ?? const <MediaRef>[];
    final live = NoteMediaPaths.extractFromContentJson(contentJson);
    final byPath = {
      for (final ref in previous) ref.relativePath.replaceAll('\\', '/'): ref,
    };
    return live.map((path) {
      final existing = byPath[path];
      if (existing != null) {
        return existing;
      }
      return MediaRef()
        ..relativePath = path
        ..kind = MediaStorageService.kindForRelativePath(path)
        ..createdAt = DateTime.now();
    }).toList();
  }

  Future<bool> _persistChanges({bool allowDiscardBlankDraft = true}) async {
    if (_saving) {
      return false;
    }
    final note = _note;
    if (note == null) {
      return false;
    }

    final title = _titleController.text;
    final contentJson = _contentJson;
    final repo = ref.read(noteRepositoryProvider);
    final lockService = ref.read(noteLockServiceProvider);
    final isBlankDraft = _isNewDraft &&
        !_isLocked &&
        NoteContentCodec.isBlankNote(title: title, contentJson: contentJson);

    // Autosave must not delete an empty new draft mid-edit; leave discard to pop.
    if (isBlankDraft && !allowDiscardBlankDraft) {
      return false;
    }

    if (isBlankDraft && allowDiscardBlankDraft) {
      await repo.delete(note.id);
      _note = null;
      _clearUnlockSession();
      return true;
    }

    if (!_dirty && !_isNewDraft) {
      return false;
    }

    _saving = true;
    try {
      note
        ..title = title.trim()
        ..folderId = _folderId
        ..tagIds = List<int>.from(_tagIds);

      if (_isLocked && _sessionUnlocked) {
        final session = ref.read(unlockedNoteSessionProvider);
        if (session == null) {
          throw const NoteCryptoException(NoteCryptoErrorCode.invalidSession);
        }
        // Ensure newly imported plaintext files are available to the session.
        await _hydrateSessionMedia(session, contentJson);
        await lockService.saveUnlockedNote(
          note: note,
          session: session,
          contentJson: contentJson,
          mediaRefs: _currentMediaRefs(contentJson),
        );
        await repo.update(note);
      } else if (!_isLocked) {
        final media = ref.read(mediaStorageProvider);
        note
          ..contentJson = contentJson
          ..mediaRefs = await media.reconcile(
            previous: note.mediaRefs,
            liveRelativePaths: NoteMediaPaths.extractFromContentJson(
              contentJson,
            ),
          );
        await repo.update(note);
      } else {
        // Locked without session: only metadata (title/folder/tags).
        await repo.update(note);
      }

      _dirty = false;
      _isNewDraft = false;
      if (mounted) {
        setState(() {});
      }
      return true;
    } finally {
      _saving = false;
    }
  }

  Future<void> _hydrateSessionMedia(
    UnlockedNoteSession session,
    String contentJson,
  ) async {
    final media = ref.read(mediaStorageProvider);
    for (final path in NoteMediaPaths.extractFromContentJson(contentJson)) {
      if (session.mediaBytes.containsKey(path)) {
        continue;
      }
      final file = await media.fileFor(path);
      if (file != null) {
        session.mediaBytes[path] = await file.readAsBytes();
      }
    }
  }

  Future<void> _lockNote() async {
    final l10n = AppLocalizations.of(context);
    final note = _note;
    if (note == null || _isLocked || _busyCrypto) {
      return;
    }

    final result = await showSetNotePasswordDialog(context);
    if (result == null || !mounted) {
      return;
    }

    setState(() => _busyCrypto = true);
    try {
      // Persist any pending plaintext edits first so lock seals current content.
      _dirty = true;
      final contentJson = NoteContentCodec.encodeDocument(
        _quillController.document,
      );
      final media = ref.read(mediaStorageProvider);
      final mediaRefs = await media.reconcile(
        previous: note.mediaRefs,
        liveRelativePaths: NoteMediaPaths.extractFromContentJson(contentJson),
      );

      note
        ..title = _titleController.text.trim()
        ..folderId = _folderId
        ..tagIds = List<int>.from(_tagIds)
        ..contentJson = contentJson
        ..mediaRefs = mediaRefs;

      await ref.read(noteLockServiceProvider).lockNote(
            note: note,
            password: result.password,
            contentJson: contentJson,
            mediaRefs: mediaRefs,
          );
      await ref.read(noteRepositoryProvider).update(note);

      _quillController.document = Document();
      _clearUnlockSession();
      setState(() {
        _isLocked = true;
        _sessionUnlocked = false;
        _dirty = false;
        _isNewDraft = false;
      });
    } on NoteCryptoException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lockFailed)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lockFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCrypto = false);
      }
    }
  }

  Future<void> _unlockNote() async {
    final l10n = AppLocalizations.of(context);
    final note = _note;
    if (note == null || !_isLocked || _sessionUnlocked || _busyCrypto) {
      return;
    }

    final result = await showUnlockNotePasswordDialog(
      context,
      title: l10n.unlockNoteTitle,
      subtitle: l10n.passwordNoRecoveryWarning,
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() => _busyCrypto = true);
    try {
      final session = await ref.read(noteLockServiceProvider).unlockNote(
            note: note,
            password: result.password,
          );
      ref.read(unlockedNoteSessionProvider.notifier).state = session;
      _quillController.document = NoteContentCodec.documentFromJson(
        session.contentJson,
      );
      setState(() {
        _sessionUnlocked = true;
        _dirty = false;
      });
    } on NoteCryptoException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cryptoErrorMessage(l10n, error))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unlockFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCrypto = false);
      }
    }
  }

  Future<void> _removePassword() async {
    final l10n = AppLocalizations.of(context);
    final note = _note;
    if (note == null || !_isLocked || _busyCrypto) {
      return;
    }

    // Require password again even if already unlocked in this session.
    final auth = await showUnlockNotePasswordDialog(
      context,
      title: l10n.removePasswordTitle,
      subtitle:
          '${l10n.removePasswordMessage}\n\n${l10n.passwordNoRecoveryWarning}',
      confirmLabel: l10n.removePassword,
    );
    if (auth == null || !mounted) {
      return;
    }

    setState(() => _busyCrypto = true);
    try {
      var session = ref.read(unlockedNoteSessionProvider);
      if (session == null || !_sessionUnlocked) {
        session = await ref.read(noteLockServiceProvider).unlockNote(
              note: note,
              password: auth.password,
            );
        ref.read(unlockedNoteSessionProvider.notifier).state = session;
        _quillController.document = NoteContentCodec.documentFromJson(
          session.contentJson,
        );
        _sessionUnlocked = true;
      } else {
        // Re-verify without exposing which check failed beyond auth errors.
        final verified = await ref.read(noteCryptoServiceProvider).verifyPassword(
              password: auth.password,
              salt: session.salt,
              storedVerifier: session.passwordVerifier,
            );
        if (!verified) {
          throw const NoteCryptoException(NoteCryptoErrorCode.incorrectPassword);
        }
      }

      final contentJson = NoteContentCodec.encodeDocument(
        _quillController.document,
      );
      await _hydrateSessionMedia(session, contentJson);
      final mediaRefs = _currentMediaRefs(contentJson);

      await ref.read(noteLockServiceProvider).removePassword(
            note: note,
            session: session,
            contentJson: contentJson,
            mediaRefs: mediaRefs,
          );
      note
        ..title = _titleController.text.trim()
        ..folderId = _folderId
        ..tagIds = List<int>.from(_tagIds);
      await ref.read(noteRepositoryProvider).update(note);
      _clearUnlockSession();
      setState(() {
        _isLocked = false;
        _sessionUnlocked = false;
        _dirty = false;
      });
    } on NoteCryptoException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cryptoErrorMessage(l10n, error))),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unlockFailed)),
      );
    } finally {
      if (mounted) {
        setState(() => _busyCrypto = false);
      }
    }
  }

  String _cryptoErrorMessage(AppLocalizations l10n, NoteCryptoException error) {
    return switch (error.code) {
      NoteCryptoErrorCode.incorrectPassword => l10n.incorrectPassword,
      NoteCryptoErrorCode.corruptData ||
      NoteCryptoErrorCode.missingData ||
      NoteCryptoErrorCode.authenticationFailed =>
        l10n.corruptLockedNote,
      NoteCryptoErrorCode.passwordTooShort => l10n.passwordTooShort,
      NoteCryptoErrorCode.alreadyLocked ||
      NoteCryptoErrorCode.notLocked ||
      NoteCryptoErrorCode.invalidSession =>
        l10n.unlockFailed,
    };
  }

  void _clearBlockSelection() {
    if (_blockSelection.value != null) {
      _blockSelection.value = null;
    }
  }

  void _selectBlock(NoteBlock block) {
    final blocks = NoteBlockModel.listBlocks(_quillController.document);
    final index = blocks.indexWhere(
      (b) =>
          b.kind == block.kind &&
          b.start == block.start &&
          (block.tableId == null || b.tableId == block.tableId),
    );
    if (index < 0) {
      return;
    }
    _editorFocusNode.unfocus();
    _blockSelection.value = NoteBlockSelection(
      blockIndex: index,
      block: blocks[index],
    );
  }

  void _refreshSelectionAfterMutation() {
    final current = _blockSelection.value;
    if (current == null) {
      return;
    }
    final blocks = NoteBlockModel.listBlocks(_quillController.document);
    if (current.block.tableId != null) {
      final i = blocks.indexWhere((b) => b.tableId == current.block.tableId);
      if (i < 0) {
        _clearBlockSelection();
      } else {
        _blockSelection.value =
            NoteBlockSelection(blockIndex: i, block: blocks[i]);
      }
    } else if (current.blockIndex < blocks.length &&
        blocks[current.blockIndex].kind == current.block.kind) {
      _blockSelection.value = NoteBlockSelection(
        blockIndex: current.blockIndex,
        block: blocks[current.blockIndex],
      );
    } else {
      _clearBlockSelection();
    }
    _markDirty();
  }

  void _moveBlock({required int fromIndex, required int toIndex}) {
    final newIndex = NoteBlockOps.moveBlock(
      _quillController,
      fromIndex: fromIndex,
      toIndex: toIndex,
    );
    if (newIndex == null) {
      return;
    }
    final blocks = NoteBlockModel.listBlocks(_quillController.document);
    if (newIndex >= 0 && newIndex < blocks.length) {
      _blockSelection.value =
          NoteBlockSelection(blockIndex: newIndex, block: blocks[newIndex]);
    }
    _markDirty();
  }

  void _moveSelectedUp() {
    final sel = _blockSelection.value;
    if (sel == null) {
      return;
    }
    if (NoteBlockOps.moveBlockUp(_quillController, sel.blockIndex)) {
      _refreshSelectionAfterMutation();
    }
  }

  void _moveSelectedDown() {
    final sel = _blockSelection.value;
    if (sel == null) {
      return;
    }
    if (NoteBlockOps.moveBlockDown(_quillController, sel.blockIndex)) {
      _refreshSelectionAfterMutation();
    }
  }

  Future<void> _deleteSelectedBlock() async {
    final sel = _blockSelection.value;
    if (sel == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteBlockTitle),
        content: Text(l10n.deleteBlockMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    NoteBlockOps.deleteBlock(_quillController, sel.block);
    _clearBlockSelection();
    _markDirty();
  }

  Future<void> _resizeSelectedImage() async {
    final sel = _blockSelection.value;
    if (sel == null || sel.block.kind != NoteBlockKind.image) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    var width = sel.block.displayWidth ?? 280.0;
    final result = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.resizeImageTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.resizeImageMessage),
                  Slider(
                    value: width.clamp(80.0, 400.0),
                    min: 80,
                    max: 400,
                    divisions: 16,
                    label: '${width.round()}',
                    onChanged: (v) => setLocal(() => width = v),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, width),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    NoteBlockOps.setImageDisplayWidth(
      _quillController,
      imageOffset: sel.block.start,
      width: result,
    );
    _refreshSelectionAfterMutation();
  }

  Future<void> _replaceSelectedImage() async {
    final sel = _blockSelection.value;
    if (sel == null || sel.block.kind != NoteBlockKind.image) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.addImageFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.addImageFromCamera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );
      if (picked == null || !mounted) {
        return;
      }
      final media = ref.read(mediaStorageProvider);
      final refMedia = await media.importImageFile(File(picked.path));
      final bytes = await media.fileFor(refMedia.relativePath);
      final session = ref.read(unlockedNoteSessionProvider);
      if (session != null && bytes != null) {
        session.mediaBytes[refMedia.relativePath] = await bytes.readAsBytes();
        session.mediaRefs = [...session.mediaRefs, refMedia];
      }
      NoteBlockOps.replaceImage(
        _quillController,
        imageOffset: sel.block.start,
        newRelativePath: refMedia.relativePath,
      );
      _refreshSelectionAfterMutation();
    } on PathAccessException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.imagePermissionDenied)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.imageImportFailed)),
      );
    }
  }

  Future<void> _editSelectedTableTitle() async {
    final sel = _blockSelection.value;
    if (sel == null || sel.block.tableId == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    NoteonTableData? table;
    for (final op in _quillController.document.toDelta().toList()) {
      final data = op.data;
      if (data is Map && data[BlockEmbed.customType] is String) {
        final parsed = NoteonTableBlockEmbed.tryParseEmbeddable(
          Embeddable.fromJson(Map<String, dynamic>.from(data)),
        );
        if (parsed?.id == sel.block.tableId) {
          table = parsed;
          break;
        }
      }
    }
    if (table == null) {
      return;
    }
    final controller = TextEditingController(text: table.title);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
            left: 20,
            right: 20,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(labelText: l10n.tableTitleHint),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(l10n.save),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (result == null || !mounted) {
      return;
    }
    final offset = NoteonTableDocument.offsetOf(
      _quillController.document,
      table.id,
    );
    if (offset == null) {
      return;
    }
    final updated = table.copyWith(title: result);
    _quillController.replaceText(
      offset,
      1,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(updated)),
      TextSelection.collapsed(offset: offset),
      ignoreFocus: true,
    );
    _refreshSelectionAfterMutation();
  }

  Future<void> _showImageSourceSheet() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.addImageFromGallery),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.addImageFromCamera),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) {
      return;
    }
    await _importAndInsertImage(source);
  }

  Future<void> _importAndInsertImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
      );
      if (picked == null || !mounted) {
        return;
      }

      final media = ref.read(mediaStorageProvider);
      final refMedia = await media.importImageFile(File(picked.path));
      final bytes = await media.fileFor(refMedia.relativePath);
      final session = ref.read(unlockedNoteSessionProvider);
      if (session != null && bytes != null) {
        session.mediaBytes[refMedia.relativePath] = await bytes.readAsBytes();
        session.mediaRefs = [...session.mediaRefs, refMedia];
      }
      _insertImageEmbed(refMedia.relativePath);
      _markDirty();
    } on PathAccessException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.imagePermissionDenied)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().toLowerCase().contains('permission')
          ? l10n.imagePermissionDenied
          : l10n.imageImportFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _insertImageEmbed(String relativePath) {
    _insertBlockEmbed(BlockEmbed.image(relativePath));
  }

  Future<void> _insertTable() async {
    if (_insertingTable || !_canEditBody) {
      return;
    }
    _insertingTable = true;
    try {
      final table = await showInsertTableDialog(context);
      if (table == null || !mounted) {
        return;
      }

      NoteonTableFocus.pendingTableId = table.id;
      _insertBlockEmbed(
        BlockEmbed.custom(NoteonTableBlockEmbed.fromData(table)),
      );
      _markDirty();
    } finally {
      _insertingTable = false;
    }
  }

  /// Inserts a block embed on its own line with the caret placed below it.
  void _insertBlockEmbed(Embeddable embed) {
    NoteBlockOps.insertBlockEmbed(_quillController, embed);
  }

  Future<void> _openSketchEditor({NoteonInkData? existing}) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    try {
      String? initialStrokes;
      if (existing != null && !existing.isEmpty) {
        final media = ref.read(mediaStorageProvider);
        final session = ref.read(unlockedNoteSessionProvider);
        Uint8List? bytes = session?.mediaBytes[existing.strokesPath];
        bytes ??= await media.readBytesAtRelativePath(existing.strokesPath);
        if (bytes != null) {
          initialStrokes = utf8.decode(bytes);
        }
      }

      final result = await navigator.push<SketchEditorResult>(
        NoteonPageRoute(
          builder: (_) => SketchEditorScreen(
            initialStrokesJson: initialStrokes,
          ),
        ),
      );
      if (result == null || !mounted) {
        return;
      }

      final media = ref.read(mediaStorageProvider);
      final bundled = await media.importInkBundle(
        strokesJson: result.strokesJson,
        previewPng: result.previewPng,
        id: existing?.id,
      );
      if (!mounted) {
        return;
      }
      final inkData = NoteonInkData(
        id: bundled.id,
        strokesPath: bundled.strokes.relativePath,
        previewPath: bundled.preview.relativePath,
        displayWidth: existing?.displayWidth,
      );

      final session = ref.read(unlockedNoteSessionProvider);
      if (session != null) {
        session.mediaBytes[bundled.strokes.relativePath] =
            Uint8List.fromList(utf8.encode(result.strokesJson));
        session.mediaBytes[bundled.preview.relativePath] = result.previewPng;
        session.mediaRefs = [
          ...session.mediaRefs.where(
            (r) =>
                r.relativePath != bundled.strokes.relativePath &&
                r.relativePath != bundled.preview.relativePath,
          ),
          bundled.strokes,
          bundled.preview,
        ];
      }

      if (existing != null) {
        final sel = _blockSelection.value;
        final offset = sel?.block.start;
        if (offset != null) {
          NoteBlockOps.replaceInk(
            _quillController,
            inkOffset: offset,
            data: inkData,
          );
        }
      } else {
        _insertBlockEmbed(
          BlockEmbed.custom(NoteonInkBlockEmbed.fromData(inkData)),
        );
      }
      _markDirty();
      if (mounted) {
        _editorFocusNode.requestFocus();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sketchSaveFailed)),
      );
    }
  }

  Future<void> _editSelectedInk() async {
    final sel = _blockSelection.value;
    if (sel == null || sel.block.kind != NoteBlockKind.ink) {
      return;
    }
    final blocks = NoteBlockModel.listBlocks(_quillController.document);
    if (sel.blockIndex < 0 || sel.blockIndex >= blocks.length) {
      return;
    }
    final block = blocks[sel.blockIndex];
    // Recover full ink payload from document embed.
    NoteonInkData? data;
    for (final op in _quillController.document.toDelta().toList()) {
      final d = op.data;
      if (d is Map) {
        final custom = d[BlockEmbed.customType];
        if (custom is String && custom.contains('noteonInk')) {
          try {
            final nested = jsonDecode(custom);
            if (nested is Map && nested['noteonInk'] is String) {
              final decoded = NoteonInkPayload.decode(nested['noteonInk']);
              if (decoded.id == block.inkId) {
                data = decoded;
                break;
              }
            }
          } catch (_) {}
        }
      }
    }
    data ??= NoteonInkData(
      id: block.inkId ?? '',
      strokesPath: '',
      previewPath: block.inkPreviewPath ?? '',
      displayWidth: block.displayWidth,
    );
    if (data.id.isEmpty) {
      return;
    }
    // Rebuild strokes path from id if missing.
    if (data.strokesPath.isEmpty) {
      data = NoteonInkData(
        id: data.id,
        strokesPath: 'ink/${data.id}.json',
        previewPath: data.previewPath.isEmpty
            ? 'ink/${data.id}.png'
            : data.previewPath,
        displayWidth: data.displayWidth,
      );
    }
    await _openSketchEditor(existing: data);
  }

  Future<void> _resizeSelectedInk() async {
    final sel = _blockSelection.value;
    if (sel == null || sel.block.kind != NoteBlockKind.ink) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    var width = sel.block.displayWidth ?? 280.0;
    final result = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.resizeImageTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.resizeImageMessage),
                  Slider(
                    value: width.clamp(80, 600),
                    min: 80,
                    max: 600,
                    onChanged: (v) => setLocal(() => width = v),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, width),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result == null || !mounted) {
      return;
    }
    final id = sel.block.inkId;
    if (id == null) {
      return;
    }
    final data = NoteonInkData(
      id: id,
      strokesPath: 'ink/$id.json',
      previewPath: sel.block.inkPreviewPath ?? 'ink/$id.png',
      displayWidth: result,
    );
    NoteBlockOps.setInkDisplayWidth(
      _quillController,
      inkOffset: sel.block.start,
      width: result,
      data: data,
    );
    _refreshSelectionAfterMutation();
    _markDirty();
  }

  Future<void> _recordAndInsertAudio() async {
    final l10n = AppLocalizations.of(context);
    final recorded = await NoteAudioRecorderSheet.show(context);
    if (recorded == null || !mounted) {
      return;
    }
    try {
      final bytes = await File(recorded.path).readAsBytes();
      final media = ref.read(mediaStorageProvider);
      final refMedia = await media.importAudioBytes(bytes);
      final session = ref.read(unlockedNoteSessionProvider);
      if (session != null) {
        session.mediaBytes[refMedia.relativePath] = bytes;
        session.mediaRefs = [...session.mediaRefs, refMedia];
      }
      _insertBlockEmbed(
        BlockEmbed.custom(
          NoteonAudioBlockEmbed.fromPayload(
            path: refMedia.relativePath,
            durationMs: recorded.durationMs,
          ),
        ),
      );
      _markDirty();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.audioRecordFailed)),
      );
    } finally {
      try {
        await File(recorded.path).delete();
      } catch (_) {
        // Temp cleanup is best-effort.
      }
    }
  }

  Future<void> _pickAndInsertPdf() async {
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: false,
      );
      if (picked == null || picked.files.isEmpty || !mounted) {
        return;
      }
      final path = picked.files.single.path;
      if (path == null) {
        return;
      }
      final source = File(path);
      final media = ref.read(mediaStorageProvider);
      final bundled = await media.importPdfFile(source);
      final title = p.basenameWithoutExtension(path);
      final pdfData = NoteonPdfData(
        id: bundled.id,
        pdfPath: bundled.pdf.relativePath,
        annotationsPath: bundled.annotations.relativePath,
        title: title,
      );

      final session = ref.read(unlockedNoteSessionProvider);
      if (session != null) {
        final pdfBytes = await media.readBytesAtRelativePath(pdfData.pdfPath);
        final annBytes =
            await media.readBytesAtRelativePath(pdfData.annotationsPath);
        if (pdfBytes != null) {
          session.mediaBytes[pdfData.pdfPath] = pdfBytes;
        }
        if (annBytes != null) {
          session.mediaBytes[pdfData.annotationsPath] = annBytes;
        }
        session.mediaRefs = [
          ...session.mediaRefs,
          bundled.pdf,
          bundled.annotations,
        ];
      }

      if (!mounted) {
        return;
      }
      _insertBlockEmbed(
        BlockEmbed.custom(NoteonPdfBlockEmbed.fromData(pdfData)),
      );
      _markDirty();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pdfImportFailed)),
      );
    }
  }

  Future<void> _openPdfAnnotator(NoteonPdfData data) async {
    if (data.isEmpty || !_canEditBody) {
      return;
    }
    final navigator = Navigator.of(context);
    final changed = await navigator.push<bool>(
      NoteonPageRoute(
        builder: (_) => PdfAnnotatorScreen(
          data: data,
          noteId: _note?.id,
        ),
      ),
    );
    if (changed == true && mounted) {
      _markDirty();
    }
  }

  Future<void> _editSelectedPdf() async {
    final sel = _blockSelection.value;
    if (sel == null || sel.block.kind != NoteBlockKind.pdf) {
      return;
    }
    final id = sel.block.pdfId;
    if (id == null || id.isEmpty) {
      return;
    }
    NoteonPdfData? data;
    for (final op in _quillController.document.toDelta().toList()) {
      final d = op.data;
      if (d is! Map) {
        continue;
      }
      final custom = d[BlockEmbed.customType];
      if (custom is! String || !custom.contains('noteonPdf')) {
        continue;
      }
      try {
        final nested = jsonDecode(custom);
        if (nested is Map && nested['noteonPdf'] is String) {
          final decoded = NoteonPdfPayload.decode(nested['noteonPdf']);
          if (decoded.id == id) {
            data = decoded;
            break;
          }
        }
      } catch (_) {}
    }
    data ??= NoteonPdfData(
      id: id,
      pdfPath: 'pdfs/$id.pdf',
      annotationsPath: 'pdfs/$id.ann.json',
    );
    await _openPdfAnnotator(data);
  }

  Future<void> _shareNote(_NoteShareAction action) async {
    final l10n = AppLocalizations.of(context);
    if (!_canEditBody) {
      return;
    }
    final media = ref.read(mediaStorageProvider);
    Future<File?> resolveMedia(String relativePath) =>
        media.fileFor(relativePath);
    try {
      switch (action) {
        case _NoteShareAction.text:
          await NoteShareActions.shareAsText(
            context: context,
            title: _titleController.text,
            contentJson: _contentJson,
          );
        case _NoteShareAction.image:
          await NoteShareActions.shareAsImage(
            context: context,
            title: _titleController.text,
            contentJson: _contentJson,
            resolveMedia: resolveMedia,
          );
        case _NoteShareAction.pdf:
          await NoteShareActions.shareAsPdf(
            context: context,
            title: _titleController.text,
            contentJson: _contentJson,
            resolveMedia: resolveMedia,
          );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareFailed)),
      );
    }
  }

  Future<void> _ocrSelectedBlock() async {
    final sel = _blockSelection.value;
    if (sel == null || !_canEditBody) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (!NoteOcrService.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ocrUnsupported)),
      );
      return;
    }

    final relative = switch (sel.block.kind) {
      NoteBlockKind.image => sel.block.imagePath,
      NoteBlockKind.ink => sel.block.inkPreviewPath,
      _ => null,
    };
    if (relative == null || relative.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ocrFailed)),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.ocrProgress), duration: const Duration(seconds: 30)),
    );

    try {
      final media = ref.read(mediaStorageProvider);
      final abs = await media.absolutePathFor(relative);
      final text = await NoteOcrService.recognizeText(filePath: abs);
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      await _showOcrResult(text, insertAfter: sel.block);
    } on NoteOcrException catch (e) {
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      final message = switch (e.code) {
        NoteOcrError.unsupportedPlatform => l10n.ocrUnsupported,
        NoteOcrError.noTextFound => l10n.ocrNoText,
        _ => l10n.ocrFailed,
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(l10n.ocrFailed)));
    }
  }

  Future<void> _showOcrResult(String text, {required NoteBlock insertAfter}) async {
    final l10n = AppLocalizations.of(context);
    final action = await showDialog<_OcrResultAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.ocrTitle),
          content: SingleChildScrollView(
            child: SelectableText(text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _OcrResultAction.copy),
              child: Text(l10n.ocrCopy),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _OcrResultAction.insert),
              child: Text(l10n.ocrInsert),
            ),
          ],
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == _OcrResultAction.copy) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ocrCopied)),
      );
      return;
    }

    final docLen = _quillController.document.length;
    final insertAt = insertAfter.end.clamp(0, docLen > 0 ? docLen - 1 : 0);
    final payload = text.endsWith('\n') ? '\n$text' : '\n$text\n';
    _quillController.replaceText(
      insertAt,
      0,
      payload,
      TextSelection.collapsed(offset: insertAt + payload.length),
    );
    _clearBlockSelection();
    _markDirty();
  }

  Future<void> _showAssistSheet() async {
    if (!_canEditBody) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<_AssistAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.short_text_rounded),
                title: Text(l10n.assistTidy),
                subtitle: Text(l10n.assistTidySubtitle),
                onTap: () => Navigator.pop(context, _AssistAction.tidy),
              ),
              ListTile(
                leading: const Icon(Icons.format_list_bulleted_rounded),
                title: Text(l10n.assistBullets),
                subtitle: Text(l10n.assistBulletsSubtitle),
                onTap: () => Navigator.pop(context, _AssistAction.bullets),
              ),
              ListTile(
                leading: const Icon(Icons.title_rounded),
                title: Text(l10n.assistFirstLine),
                subtitle: Text(l10n.assistFirstLineSubtitle),
                onTap: () => Navigator.pop(context, _AssistAction.firstLine),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) {
      return;
    }
    _applyAssist(choice);
  }

  void _applyAssist(_AssistAction action) {
    final l10n = AppLocalizations.of(context);
    final selection = _quillController.selection;
    var start = selection.start;
    var end = selection.end;
    if (end <= start) {
      final blockSel = _blockSelection.value;
      if (blockSel != null && blockSel.block.kind == NoteBlockKind.text) {
        start = blockSel.block.start;
        end = blockSel.block.end;
      }
    }
    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.assistSelectText)),
      );
      return;
    }

    final plain = _quillController.document.toPlainText();
    final max = plain.length;
    final a = start.clamp(0, max);
    final b = end.clamp(0, max);
    if (b <= a) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.assistSelectText)),
      );
      return;
    }
    final source = plain.substring(a, b);
    final transformed = switch (action) {
      _AssistAction.tidy => NoteLocalAssist.tidyWhitespace(source),
      _AssistAction.bullets => NoteLocalAssist.toBulletList(source),
      _AssistAction.firstLine => NoteLocalAssist.emphasizeFirstLine(source),
    };
    if (transformed == source) {
      return;
    }
    _quillController.replaceText(
      a,
      b - a,
      transformed,
      TextSelection.collapsed(offset: a + transformed.length),
    );
    _markDirty();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.assistApplied)),
    );
  }

  Future<void> _handlePop() async {
    final l10n = AppLocalizations.of(context);
    _autosaveTimer?.cancel();
    try {
      final changed = await _persistChanges();
      _clearUnlockSession();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(changed);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noteSaveFailed)),
      );
      // Keep the editor open so the user can retry or discard intentionally.
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteNoteTitle),
          content: Text(l10n.deleteNoteMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || _note == null) {
      return;
    }

    await ref.read(noteRepositoryProvider).delete(_note!.id);
    _clearUnlockSession();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _pickFolder(List<Folder> folders) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: Text(l10n.noFolder),
                onTap: () => Navigator.pop(context, -1),
              ),
              for (final folder in folders)
                ListTile(
                  leading: Icon(
                    folder.parentFolderId == null
                        ? Icons.folder_outlined
                        : Icons.folder_open_outlined,
                    color: AppColors.teal,
                  ),
                  title: Text(
                    folder.parentFolderId == null
                        ? folder.name
                        : '  ${folder.name}',
                  ),
                  selected: _folderId == folder.id,
                  onTap: () => Navigator.pop(context, folder.id),
                ),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }
    setState(() {
      _folderId = selected == -1 ? null : selected;
    });
    _markDirty();
  }

  Future<void> _addTag(List<Tag> existingTags) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.addTag),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.tagNameHint),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(l10n.addTag),
            ),
          ],
        );
      },
    );

    if (name == null || name.trim().isEmpty) {
      return;
    }

    final tagId = await ref.read(tagRepositoryProvider).createOrGet(name);
    await ref.read(tagsListProvider.notifier).refresh();
    if (!_tagIds.contains(tagId)) {
      setState(() {
        _tagIds = [..._tagIds, tagId];
      });
      _markDirty();
    }
  }

  bool get _canEditBody => !_isLocked || _sessionUnlocked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handlePop();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          toolbarHeight: _writingCompact ? 44 : kToolbarHeight,
          leading: IconButton(
            icon: const BackButtonIcon(),
            onPressed: _handlePop,
          ),
          title: _writingCompact
              ? null
              : Text(
                  _isNewDraft ? l10n.newNote : l10n.editNote,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: _dirtyListenable,
              builder: (context, dirty, _) {
                if (!dirty || _busyCrypto) {
                  return const SizedBox.shrink();
                }
                return Tooltip(
                  message: l10n.editNote,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_busyCrypto)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (_note != null && !_busyCrypto && _canEditBody)
              IconButton(
                tooltip: l10n.assistNote,
                onPressed: _showAssistSheet,
                icon: const Icon(Icons.short_text_rounded),
              ),
            if (_note != null && !_busyCrypto && _canEditBody)
              PopupMenuButton<_NoteShareAction>(
                tooltip: l10n.shareNote,
                icon: const Icon(Icons.ios_share_rounded),
                onSelected: (action) => _shareNote(action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _NoteShareAction.text,
                    child: Text(l10n.shareAsText),
                  ),
                  PopupMenuItem(
                    value: _NoteShareAction.image,
                    child: Text(l10n.shareAsImage),
                  ),
                  PopupMenuItem(
                    value: _NoteShareAction.pdf,
                    child: Text(l10n.shareAsPdf),
                  ),
                ],
              ),
            if (_note != null && !_busyCrypto)
              PopupMenuButton<_NoteSecurityAction>(
                tooltip: l10n.lockNote,
                onSelected: (action) {
                  switch (action) {
                    case _NoteSecurityAction.lock:
                      _lockNote();
                    case _NoteSecurityAction.unlock:
                      _unlockNote();
                    case _NoteSecurityAction.removePassword:
                      _removePassword();
                    case _NoteSecurityAction.delete:
                      _confirmDelete();
                  }
                },
                itemBuilder: (context) {
                  return [
                    if (!_isLocked)
                      PopupMenuItem(
                        value: _NoteSecurityAction.lock,
                        child: Text(l10n.lockNote),
                      ),
                    if (_isLocked && !_sessionUnlocked)
                      PopupMenuItem(
                        value: _NoteSecurityAction.unlock,
                        child: Text(l10n.unlockNote),
                      ),
                    if (_isLocked)
                      PopupMenuItem(
                        value: _NoteSecurityAction.removePassword,
                        child: Text(l10n.removePassword),
                      ),
                    if (!_isNewDraft)
                      PopupMenuItem(
                        value: _NoteSecurityAction.delete,
                        child: Text(l10n.delete),
                      ),
                  ];
                },
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _buildBody(l10n, theme),
        ),
      ),
    );
  }

  String _tagLabel(List<Tag> tags, int tagId) {
    final matches = tags.where((tag) => tag.id == tagId);
    return matches.isEmpty ? '#$tagId' : matches.first.name;
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null || _note == null) {
      final message =
          _loadError == 'missing' ? l10n.noteMissing : l10n.noteLoadFailed;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
    }

    final folders = ref.watch(foldersListProvider).valueOrNull ?? const [];
    final tags = ref.watch(tagsListProvider).valueOrNull ?? const [];
    final folderMatches = folders.where((folder) => folder.id == _folderId);
    final folderName =
        _folderId == null || folderMatches.isEmpty
            ? l10n.noFolder
            : folderMatches.first.name;

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            _writingCompact ? 0 : 6,
            16,
            0,
          ),
          child: TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            style: (_writingCompact
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleLarge)
                ?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.2,
            ),
            maxLength: 200,
            maxLines: _writingCompact ? 1 : 2,
            decoration: InputDecoration(
              hintText: l10n.noteTitleHint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _editorFocusNode.requestFocus(),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              12,
              _writingCompact ? 2 : 6,
              12,
              _writingCompact ? 2 : 6,
            ),
            child: _writingCompact
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ActionChip(
                      avatar: const Icon(Icons.folder_outlined, size: 16),
                      label: Text(folderName),
                      onPressed: () {
                        _editorFocusNode.unfocus();
                        _titleFocusNode.unfocus();
                        _pickFolder(folders);
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.folder_outlined, size: 18),
                          label: Text(folderName),
                          onPressed: () => _pickFolder(folders),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        for (final tagId in _tagIds) ...[
                          InputChip(
                            label: Text(_tagLabel(tags, tagId)),
                            onDeleted: () {
                              setState(() {
                                _tagIds =
                                    _tagIds.where((id) => id != tagId).toList();
                              });
                              _markDirty();
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                        ],
                        ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l10n.addTag),
                          onPressed: () => _addTag(tags),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (_isLocked && !_sessionUnlocked)
          Expanded(
            child: _LockedBody(
              message: l10n.lockedNoteEditorMessage,
              unlockLabel: l10n.unlockNote,
              onUnlock: _busyCrypto ? null : _unlockNote,
            ),
          )
        else ...[
          ValueListenableBuilder<NoteBlockSelection?>(
            valueListenable: _blockSelection,
            builder: (context, selection, _) {
              if (selection == null || !_canEditBody) {
                return const SizedBox.shrink();
              }
              final blocks =
                  NoteBlockModel.listBlocks(_quillController.document);
              final l10n = AppLocalizations.of(context);
              return NoteBlockToolbar(
                selection: selection,
                canMoveUp: selection.blockIndex > 0,
                canMoveDown: selection.blockIndex < blocks.length - 1,
                onMoveUp: _moveSelectedUp,
                onMoveDown: _moveSelectedDown,
                onDelete: _deleteSelectedBlock,
                onClear: _clearBlockSelection,
                onResize: selection.block.kind == NoteBlockKind.image
                    ? _resizeSelectedImage
                    : selection.block.kind == NoteBlockKind.ink
                        ? _resizeSelectedInk
                        : null,
                onReplace: selection.block.kind == NoteBlockKind.image
                    ? _replaceSelectedImage
                    : null,
                onEdit: selection.block.kind == NoteBlockKind.table
                    ? _editSelectedTableTitle
                    : selection.block.kind == NoteBlockKind.ink
                        ? _editSelectedInk
                        : selection.block.kind == NoteBlockKind.pdf
                            ? _editSelectedPdf
                            : null,
                onOcr: (selection.block.kind == NoteBlockKind.image ||
                        selection.block.kind == NoteBlockKind.ink)
                    ? _ocrSelectedBlock
                    : null,
                labels: NoteBlockToolbarLabels(
                  moveUp: l10n.blockMoveUp,
                  moveDown: l10n.blockMoveDown,
                  resizeImage: l10n.resizeImage,
                  replaceImage: l10n.replaceImage,
                  editBlock: l10n.editBlock,
                  delete: l10n.delete,
                  cancel: l10n.cancel,
                  ocrImage: l10n.ocrImage,
                ),
              );
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 4),
              child: NoteEditorZoomViewport(
                child: NotePageBackgroundLayer(
                  pattern: ref.watch(notePageBackgroundProvider),
                  child: RepaintBoundary(
                    child: KeyedSubtree(
                      key: _editorHostKey,
                      child: Listener(
                        onPointerSignal: (signal) {
                          if (signal is PointerScrollEvent) {
                            _browseCaretSync.onPointerScroll(signal);
                          }
                        },
                        child: NotificationListener<ScrollNotification>(
                          onNotification:
                              _browseCaretSync.onScrollNotification,
                          child: DefaultTextStyle(
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  decoration: TextDecoration.none,
                                ),
                            child: QuillEditor.basic(
                            controller: _quillController,
                            focusNode: _editorFocusNode,
                            scrollController: _editorScrollController,
                            config: QuillEditorConfig(
                              placeholder: l10n.noteBodyHint,
                              padding: EdgeInsets.only(
                                bottom: 48 +
                                    MediaQuery.viewInsetsOf(context).bottom,
                              ),
                              scrollBottomInset: 72,
                              autoFocus: false,
                              expands: false,
                              scrollable: true,
                              scrollPhysics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              // Keep caret ink aligned with body text, not error/primary.
                              paintCursorAboveText: true,
                              customStyles: noteEditorCompactStyles(context),
                              embedBuilders: [
                                NoteonImageEmbedBuilder(
                                  noteId: _note?.id,
                                  interaction: _canEditBody
                                      ? _blockInteraction
                                      : null,
                                ),
                                NoteonTableEmbedBuilder(
                                  editorFocusNode: _editorFocusNode,
                                  interaction: _canEditBody
                                      ? _blockInteraction
                                      : null,
                                ),
                                NoteonAudioEmbedBuilder(
                                  noteId: _note?.id,
                                  interaction: _canEditBody
                                      ? _blockInteraction
                                      : null,
                                ),
                                NoteonInkEmbedBuilder(
                                  noteId: _note?.id,
                                  interaction: _canEditBody
                                      ? _blockInteraction
                                      : null,
                                ),
                                NoteonPdfEmbedBuilder(
                                  noteId: _note?.id,
                                  interaction: _canEditBody
                                      ? _blockInteraction
                                      : null,
                                  onOpen: _canEditBody
                                      ? _openPdfAnnotator
                                      : null,
                                ),
                              ],
                              onSingleLongTapStart: (details, getPosition) {
                                if (!_canEditBody) {
                                  return false;
                                }
                                final pos =
                                    getPosition(details.globalPosition);
                                final block = NoteBlockModel.blockAtOffset(
                                  _quillController.document,
                                  pos.offset,
                                );
                                if (block == null ||
                                    block.kind != NoteBlockKind.text) {
                                  return false;
                                }
                                _selectBlock(block);
                                return true;
                              },
                            ),
                          ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Toolbar sits above the keyboard when the scaffold resizes.
          // QuillSimpleToolbar (multiRowsDisplay: false) uses an internal
          // Expanded scroll list and requires a bounded width — do not wrap
          // it in a horizontal SingleChildScrollView or the buttons vanish.
          Material(
            color: isDark
                ? AppColors.surfaceDarkElevated
                : AppColors.surfaceLightAlt,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(2, 0, 2, 0),
              child: Row(
                children: [
                  Expanded(
                    child: QuillSimpleToolbar(
                      controller: _quillController,
                      config: const QuillSimpleToolbarConfig(
                        multiRowsDisplay: false,
                        showDividers: false,
                        showFontFamily: false,
                        showFontSize: true,
                        showStrikeThrough: true,
                        showInlineCode: false,
                        // Color picker restored. Clear-format stays so accidental
                        // Material palette taps (often red) are easy to undo.
                        showColorButton: true,
                        showBackgroundColorButton: false,
                        showClearFormat: true,
                        showHeaderStyle: true,
                        showListCheck: true,
                        showCodeBlock: false,
                        showQuote: false,
                        showIndent: false,
                        showLink: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showBoldButton: true,
                        showItalicButton: true,
                        showUnderLineButton: true,
                        showListBullets: true,
                        showListNumbers: true,
                        showUndo: true,
                        showRedo: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.addImage,
                    onPressed: _canEditBody ? _showImageSourceSheet : null,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    tooltip: l10n.addSketch,
                    onPressed: _canEditBody ? _openSketchEditor : null,
                    icon: const Icon(Icons.brush_outlined),
                  ),
                  IconButton(
                    tooltip: l10n.insertTable,
                    onPressed: _canEditBody ? _insertTable : null,
                    icon: const Icon(Icons.table_chart_outlined),
                  ),
                  IconButton(
                    tooltip: l10n.addAudio,
                    onPressed: _canEditBody ? _recordAndInsertAudio : null,
                    icon: const Icon(Icons.mic_none_rounded),
                  ),
                  IconButton(
                    tooltip: l10n.addPdf,
                    onPressed: _canEditBody ? _pickAndInsertPdf : null,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _NoteShareAction { text, image, pdf }

enum _OcrResultAction { copy, insert }

enum _AssistAction { tidy, bullets, firstLine }

enum _NoteSecurityAction {
  lock,
  unlock,
  removePassword,
  delete,
}

class _LockedBody extends StatelessWidget {
  const _LockedBody({
    required this.message,
    required this.unlockLabel,
    required this.onUnlock,
  });

  final String message;
  final String unlockLabel;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: AppRadii.logoTile,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 40,
                  color: isDark ? AppColors.tealLight : AppColors.tealDark,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.lock_open_outlined),
                label: Text(unlockLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
