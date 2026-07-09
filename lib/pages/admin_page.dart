import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/auth_controller.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../theme/row_palette.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/theme_toggle_button.dart';

// ── Định nghĩa cột ──────────────────────────────────────────────────────────

class _Col {
  const _Col(this.key, this.label, this.width);
  final String key;
  final String label;
  final double width;
}

const _kCols = [
  _Col('id',          'ID',          80),
  _Col('name',        'Name',        150),
  _Col('who',         'who',         120),
  _Col('me',          'me',          120),
  _Col('email',       'Email',       190),
  _Col('phone',       'Phone',       120),
  _Col('address',     'Address',     150),
  _Col('message',     'Message',     200),
  _Col('des1',        'Des_1',       110),
  _Col('des2',        'Des_2',       110),
  _Col('des3',        'Des_3',       110),
  _Col('timeMeeting', 'timeMeeting', 120),
  _Col('timeEnding',  'timeEnding',  120),
  _Col('active',      'Active',       70),
  _Col('confirm',     'Confirm',      80),
  _Col('showAllPhotos', 'Xem toàn bộ', 90),
  _Col('updated',     'Cập nhật',   130),
];

const _kPrefsOrder  = 'admin_col_order';
const _kPrefsHidden = 'admin_col_hidden';

// ── EditSession ──────────────────────────────────────────────────────────────

/// Trạng thái chia sẻ giữa [AdminPage] (chứa nút nổi) và [UsersTable]
/// (giữ logic thêm/sửa). Khi đang thêm/sửa 1 hàng, nút "Thêm user" sẽ
/// đổi thành nút "Lưu" gọi [save].
class EditSession extends ChangeNotifier {
  bool _active = false;
  bool _busy = false;

  /// Hàm lưu hiện hành, do [UsersTable] đăng ký.
  VoidCallback? onSave;

  /// Đang có hàng thêm/sửa hay không (nút nổi thành "Lưu" khi true).
  bool get active => _active;

  /// Đang lưu (vô hiệu hóa nút + hiện spinner).
  bool get busy => _busy;

  void begin() {
    _active = true;
    _busy = false;
    notifyListeners();
  }

  void end() {
    _active = false;
    _busy = false;
    notifyListeners();
  }

  void setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  void save() => onSave?.call();
}

/// Trang quản trị: bảng users + thêm / sửa inline / sao chép / xóa /
/// kéo-thả đổi thứ tự.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _service = FirestoreService();
  final _session = EditSession();
  int _addToken = 0;

  final _searchCtrl = TextEditingController();
  final _meetingCtrl = TextEditingController();
  String _nameQuery = '';
  String _meetingQuery = '';
  bool? _activeFilter;
  bool? _confirmFilter;

  /// Lọc theo màu hàng: null = tất cả; '' = chỉ hàng KHÔNG màu;
  /// còn lại = đúng khóa màu (vd 'blue').
  String? _colorFilter;

  // Thứ tự cột (list key); mặc định theo _kCols.
  List<String> _colOrder = _kCols.map((c) => c.key).toList();
  // Tập key các cột đang ẩn.
  Set<String> _hiddenCols = {};

  bool get _hasFilter =>
      _nameQuery.trim().isNotEmpty ||
      _meetingQuery.trim().isNotEmpty ||
      _activeFilter != null ||
      _confirmFilter != null ||
      _colorFilter != null;

  @override
  void initState() {
    super.initState();
    _loadColPrefs();
  }

  Future<void> _loadColPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawOrder  = prefs.getString(_kPrefsOrder);
    final rawHidden = prefs.getString(_kPrefsHidden);
    if (!mounted) return;
    setState(() {
      if (rawOrder != null) {
        final saved = (jsonDecode(rawOrder) as List).cast<String>();
        // Thêm cột mới (nếu có) vào cuối, bỏ cột đã xóa.
        final validKeys = _kCols.map((c) => c.key).toSet();
        _colOrder = [
          ...saved.where(validKeys.contains),
          ...validKeys.difference(saved.toSet()),
        ];
      }
      if (rawHidden != null) {
        _hiddenCols = (jsonDecode(rawHidden) as List).cast<String>().toSet();
      }
    });
  }

  Future<void> _saveColPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_kPrefsOrder,  jsonEncode(_colOrder)),
      prefs.setString(_kPrefsHidden, jsonEncode(_hiddenCols.toList())),
    ]);
  }

  void _showColumnPicker() {
    showDialog<void>(
      context: context,
      builder: (_) => _ColumnPickerDialog(
        colOrder:   List.of(_colOrder),
        hiddenCols: Set.of(_hiddenCols),
        onApply: (order, hidden) {
          setState(() {
            _colOrder   = order;
            _hiddenCols = hidden;
          });
          _saveColPrefs();
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _meetingCtrl.dispose();
    _session.dispose();
    super.dispose();
  }

  /// Lọc client-side: từ khóa Name (chứa), isActive, isConfirm,
  /// và timeMeeting (so sánh chuỗi - chứa).
  List<AppUser> _applyFilters(List<AppUser> users) {
    final name = _nameQuery.trim().toLowerCase();
    final meeting = _meetingQuery.trim().toLowerCase();
    return users.where((u) {
      if (name.isNotEmpty &&
          !u.name.toLowerCase().contains(name) &&
          !u.userId.toString().contains(name)) {
        return false;
      }
      if (_activeFilter != null && u.isActive != _activeFilter) return false;
      if (_confirmFilter != null && u.isConfirm != _confirmFilter) return false;
      if (_colorFilter != null) {
        // Chuẩn hóa key lạ/cũ (không khớp bảng màu) thành "không màu" ('').
        final normalized = RowPalette.byKey(u.rowColor) == null ? '' : u.rowColor;
        if (normalized != _colorFilter) return false;
      }
      if (meeting.isNotEmpty &&
          !u.timeMeeting.toLowerCase().contains(meeting)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _meetingCtrl.clear();
      _nameQuery = '';
      _meetingQuery = '';
      _activeFilter = null;
      _confirmFilter = null;
      _colorFilter = null;
    });
  }

  String _statusText(int total, int shown) {
    if (total == 0) return 'Chưa có user';
    if (_hasFilter) {
      return 'Hiển thị $shown/$total user · đang lọc (kéo-thả tạm tắt)';
    }
    return '$total user · nhấn giữ ⠿ và kéo để đổi thứ tự';
  }

  Widget _filterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _nameQuery = v),
            decoration: const InputDecoration(
              labelText: 'Tìm theo Name / Mã ID',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 190,
          child: _boolFilter(
            label: 'isActive',
            value: _activeFilter,
            options: const {null: 'Tất cả', true: 'Đang hoạt động', false: 'Ngưng'},
            onChanged: (v) => setState(() => _activeFilter = v),
          ),
        ),
        SizedBox(
          width: 190,
          child: _boolFilter(
            label: 'isConfirm',
            value: _confirmFilter,
            options: const {null: 'Tất cả', true: 'Đã xác nhận', false: 'Chưa'},
            onChanged: (v) => setState(() => _confirmFilter = v),
          ),
        ),
        SizedBox(
          width: 190,
          child: _colorFilterField(),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _meetingCtrl,
            onChanged: (v) => setState(() => _meetingQuery = v),
            decoration: const InputDecoration(
              labelText: 'Lọc timeMeeting',
              prefixIcon: Icon(Icons.event_outlined),
              isDense: true,
            ),
          ),
        ),
        if (_hasFilter)
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Xóa lọc'),
          ),
      ],
    );
  }

  Widget _boolFilter({
    required String label,
    required bool? value,
    required Map<bool?, String> options,
    required ValueChanged<bool?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<bool?>(
          isExpanded: true,
          isDense: true,
          value: value,
          hint: Text(options[null] ?? 'Tất cả'),
          items: options.entries
              .map((e) => DropdownMenuItem<bool?>(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Dropdown lọc theo màu hàng: Tất cả / Không màu / từng màu (kèm ô tròn).
  Widget _colorFilterField() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Lọc theo màu', isDense: true),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          isDense: true,
          value: _colorFilter,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Tất cả')),
            DropdownMenuItem<String?>(
              value: RowPalette.none,
              child: _colorFilterItem(null, 'Không màu'),
            ),
            ...RowPalette.options.map(
              (o) => DropdownMenuItem<String?>(
                value: o.key,
                child: _colorFilterItem(o, o.label),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _colorFilter = v),
        ),
      ),
    );
  }

  Widget _colorFilterItem(RowColorOption? option, String label) {
    return Row(
      children: [
        ColorDot(option: option, size: 16),
        const SizedBox(width: 10),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Future<void> _logout() async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Đăng xuất?',
      message: 'Bạn muốn đăng xuất khỏi trang admin?',
      confirmLabel: 'Đăng xuất',
      icon: Icons.logout,
    );
    if (confirm) {
      await authController.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Users'),
        actions: [
          IconButton(
            tooltip: 'Kho ảnh',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => context.go('/gallery'),
          ),
          IconButton(
            tooltip: 'Bài viết',
            icon: const Icon(Icons.article_outlined),
            onPressed: () => context.go('/admin/posts'),
          ),
          IconButton(
            tooltip: 'Trò chơi thổi bóng (Love)',
            icon: const Icon(Icons.favorite_outline),
            // push (không phải go) để bấm back từ trang game quay lại admin.
            onPressed: () => context.push('/love'),
          ),
          IconButton(
            tooltip: 'Ẩn / hiện & sắp xếp cột',
            icon: const Icon(Icons.view_column_outlined),
            onPressed: _showColumnPicker,
          ),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          // Đang thêm/sửa 1 hàng -> nút "Lưu" (xanh lá, nền trắng).
          if (_session.active) {
            return FloatingActionButton.extended(
              onPressed: _session.busy ? null : _session.save,
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              icon: _session.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.green,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Lưu'),
            );
          }
          // Mặc định -> nút "Thêm user".
          return FloatingActionButton.extended(
            onPressed: () => setState(() => _addToken++),
            icon: const Icon(Icons.add),
            label: const Text('Thêm user'),
          );
        },
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _service.watchUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(error: '${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final users = _applyFilters(all);
          final reorderEnabled = !_hasFilter;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  _statusText(all.length, users.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _filterBar(),
              ),
              Expanded(
                child: users.isEmpty
                    ? Center(
                        child: Text(
                          all.isEmpty
                              ? 'Chưa có user — bấm "Thêm user" để tạo hàng mới'
                              : 'Không tìm thấy user khớp bộ lọc',
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: UsersTable(
                          users: users,
                          service: _service,
                          addToken: _addToken,
                          reorderEnabled: reorderEnabled,
                          session: _session,
                          colOrder:   _colOrder,
                          hiddenCols: _hiddenCols,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bảng users: kéo-thả đổi thứ tự, sửa inline, sao chép, xóa, thêm hàng mới.
/// Tại 1 thời điểm chỉ cho sửa/thêm 1 hàng.
class UsersTable extends StatefulWidget {
  const UsersTable({
    super.key,
    required this.users,
    required this.service,
    required this.addToken,
    required this.reorderEnabled,
    required this.session,
    required this.colOrder,
    required this.hiddenCols,
  });

  final List<AppUser> users;
  final FirestoreService service;
  final int addToken;

  /// Khi đang lọc/tìm kiếm thì tắt kéo-thả (false).
  final bool reorderEnabled;

  /// Trạng thái chia sẻ với nút nổi "Lưu" ở [AdminPage].
  final EditSession session;

  /// Thứ tự hiển thị các cột (list key theo _kCols).
  final List<String> colOrder;

  /// Tập key các cột đang ẩn.
  final Set<String> hiddenCols;

  @override
  State<UsersTable> createState() => _UsersTableState();
}

class _UsersTableState extends State<UsersTable> {
  // Độ rộng cột cố định (không thể ẩn).
  static const double _wHandle  = 40;
  static const double _wIndex   = 44;
  static const double _wActions = 190;

  /// Các cột hiện tại theo đúng thứ tự + chỉ lấy cột không ẩn.
  List<_Col> get _visibleCols {
    final colByKey = {for (final c in _kCols) c.key: c};
    return [
      for (final key in widget.colOrder)
        if (!widget.hiddenCols.contains(key) && colByKey.containsKey(key))
          colByKey[key]!,
    ];
  }

  double get _totalWidth =>
      _wHandle +
      _wIndex +
      _visibleCols.fold(0.0, (s, c) => s + c.width) +
      _wActions;

  /// Bản sao cục bộ của danh sách để cập nhật ngay khi kéo-thả (optimistic).
  late List<AppUser> _users;

  final _hScrollController = ScrollController();

  String? _editingId;
  bool _addingNew = false;
  bool _busy = false;

  /// Chỉ true trong lúc kéo-thả (giữ thứ tự optimistic, tạm bỏ qua stream).
  /// Các thao tác khác (xóa/thêm/sửa) KHÔNG bật cờ này để bảng luôn cập nhật.
  bool _reordering = false;

  final _idCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _whoCtrl = TextEditingController();
  final _meCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _des1Ctrl = TextEditingController();
  final _des2Ctrl = TextEditingController();
  final _des3Ctrl = TextEditingController();
  final _timeMeetingCtrl = TextEditingController();
  final _timeEndingCtrl = TextEditingController();
  bool _editActive = false;
  bool _editConfirm = false;
  bool _editShowAllPhotos = false;

  /// Màu hàng hiện hành của hàng đang thêm/sửa — giữ lại để khi lưu form
  /// không vô tình xóa màu (màu được đổi qua nút chọn màu riêng).
  String _editRowColor = '';

  List<TextEditingController> get _allCtrls => [
        _idCtrl,
        _nameCtrl,
        _whoCtrl,
        _meCtrl,
        _emailCtrl,
        _phoneCtrl,
        _addressCtrl,
        _messageCtrl,
        _des1Ctrl,
        _des2Ctrl,
        _des3Ctrl,
        _timeMeetingCtrl,
        _timeEndingCtrl,
      ];

  bool get _canAct => _editingId == null && !_addingNew && !_busy;

  void _showToast(String msg, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(msg, style: const TextStyle(color: Colors.white))),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2500), entry.remove);
  }

  @override
  void initState() {
    super.initState();
    _users = widget.users;
    // Đăng ký hàm lưu để nút nổi "Lưu" ở AdminPage gọi được.
    widget.session.onSave = _saveCurrent;
    // Sau frame đầu, scroll position đã có viewportDimension -> rebuild để
    // lớp phủ neo cột thao tác tính đúng vị trí ngay lần hiển thị đầu tiên.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant UsersTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Đồng bộ với dữ liệu mới từ stream (chỉ tạm dừng khi đang kéo-thả).
    if (!_reordering) {
      _users = widget.users;
    }
    if (widget.addToken != oldWidget.addToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startAdd();
      });
    }
  }

  @override
  void dispose() {
    widget.session.onSave = null;
    _hScrollController.dispose();
    for (final c in _allCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  /// Hàm lưu dùng chung cho nút nổi "Lưu": tùy trạng thái mà lưu hàng
  /// mới hay lưu thay đổi của hàng đang sửa.
  void _saveCurrent() {
    if (_busy) return;
    if (_addingNew) {
      _saveNew();
    } else if (_editingId != null) {
      final idx = _users.indexWhere((u) => u.id == _editingId);
      if (idx != -1) _saveEdit(_users[idx]);
    }
  }

  void _clearControllers() {
    for (final c in _allCtrls) {
      c.clear();
    }
    _editActive = false;
    _editConfirm = false;
    _editShowAllPhotos = false;
    _editRowColor = '';
  }

  void _fillControllers(AppUser u) {
    _idCtrl.text = u.userId.toString();
    _nameCtrl.text = u.name;
    _whoCtrl.text = u.who;
    _meCtrl.text = u.me;
    _emailCtrl.text = u.email;
    _phoneCtrl.text = u.phone;
    _addressCtrl.text = u.address;
    _messageCtrl.text = u.message;
    _des1Ctrl.text = u.des1;
    _des2Ctrl.text = u.des2;
    _des3Ctrl.text = u.des3;
    _timeMeetingCtrl.text = u.timeMeeting;
    _timeEndingCtrl.text = u.timeEnding;
    _editActive = u.isActive;
    _editConfirm = u.isConfirm;
    _editShowAllPhotos = u.showAllPhotos;
    _editRowColor = u.rowColor;
  }

  void _startAdd() {
    if (!_canAct) {
      _showToast('Hãy lưu hoặc hủy hàng đang thao tác trước.');
      return;
    }
    _clearControllers();
    setState(() => _addingNew = true);
    widget.session.begin(); // nút "Thêm user" -> "Lưu"
  }

  void _cancelAdd() {
    setState(() => _addingNew = false);
    widget.session.end();
  }

  void _startEdit(AppUser u) {
    _fillControllers(u);
    setState(() => _editingId = u.id);
    widget.session.begin(); // nút "Thêm user" -> "Lưu"
  }

  void _cancelEdit() {
    setState(() => _editingId = null);
    widget.session.end();
  }

  AppUser _userFromControllers({required String id, required int index}) {
    return AppUser(
      id: id,
      index: index,
      userId: int.tryParse(_idCtrl.text.trim()) ?? 0,
      name: _nameCtrl.text.trim(),
      who: _whoCtrl.text.trim(),
      me: _meCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
      des1: _des1Ctrl.text.trim(),
      des2: _des2Ctrl.text.trim(),
      des3: _des3Ctrl.text.trim(),
      isActive: _editActive,
      isConfirm: _editConfirm,
      rowColor: _editRowColor,
      timeMeeting: _timeMeetingCtrl.text.trim(),
      timeEnding: _timeEndingCtrl.text.trim(),
      timeUpdated: null,
      showAllPhotos: _editShowAllPhotos,
    );
  }

  /// Xác thực (và nếu cần thì tự sinh) mã ID lúc lưu.
  /// Trả về mã hợp lệ; trả null nếu không hợp lệ (đã hiện snackbar lỗi).
  /// [docId] = id document đang sửa (null khi thêm) để bỏ qua lúc kiểm trùng.
  /// [allowAuto] = true (thêm mới) cho phép để trống -> tự sinh mã mới.
  Future<int?> _resolveUserId({
    required String? docId,
    required bool allowAuto,
  }) async {
    final raw = _idCtrl.text.trim();

    if (raw.isEmpty) {
      if (allowAuto) return widget.service.generateUniqueUserId();
      _showToast('Vui lòng nhập mã ID', isError: true);
      return null;
    }

    final code = int.tryParse(raw);
    if (code == null || raw.length != 4) {
      _showToast('Mã ID phải gồm đúng 4 chữ số', isError: true);
      return null;
    }

    if (await widget.service.isUserIdTaken(code, exceptDocId: docId)) {
      _showToast('Mã ID $code đã được dùng, chọn mã khác', isError: true);
      return null;
    }
    return code;
  }

  Future<void> _saveEdit(AppUser original) async {
    setState(() => _busy = true);
    widget.session.setBusy(true);
    try {
      final code = await _resolveUserId(docId: original.id, allowAuto: false);
      if (code == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        widget.session.setBusy(false);
        return; // mã không hợp lệ -> giữ nguyên hàng đang sửa để admin sửa lại
      }
      _idCtrl.text = code.toString();
      await widget.service.updateUser(
        _userFromControllers(id: original.id, index: original.index),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _editingId = null;
      });
      widget.session.end();
      _showToast('Đã lưu thay đổi');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      widget.session.setBusy(false);
      _showToast('Lỗi khi lưu: $e', isError: true);
    }
  }

  Future<void> _saveNew() async {
    setState(() => _busy = true);
    widget.session.setBusy(true);
    try {
      // Admin có thể nhập mã 4 chữ số; để trống thì tự sinh mã không trùng.
      final code = await _resolveUserId(docId: null, allowAuto: true);
      if (code == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        widget.session.setBusy(false);
        return; // mã không hợp lệ -> giữ nguyên hàng mới để admin sửa lại
      }
      _idCtrl.text = code.toString();
      await widget.service.addUser(_userFromControllers(id: '', index: 0));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _addingNew = false;
      });
      widget.session.end();
      _showToast('Đã thêm user mới');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      widget.session.setBusy(false);
      _showToast('Lỗi khi thêm: $e', isError: true);
    }
  }

  Future<void> _copy(AppUser u) async {
    setState(() => _busy = true);
    try {
      final newUserId = await widget.service.generateUniqueUserId();
      final newDocId = await widget.service.copyUser(u, newUserId: newUserId);
      if (!mounted) return;
      _fillControllers(u);
      _idCtrl.text = newUserId.toString(); // mã mới, không trùng bản gốc
      setState(() {
        _busy = false;
        _editingId = newDocId;
      });
      widget.session.begin(); // đang sửa bản sao -> nút "Lưu"
      _showToast('Đã sao chép — chỉnh sửa rồi bấm Lưu');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showToast('Lỗi khi sao chép: $e', isError: true);
    }
  }

  Future<void> _delete(AppUser u) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Xóa user?',
      message: 'Bạn chắc chắn muốn xóa "${u.name.isEmpty ? u.id : u.name}"?',
      confirmLabel: 'Xóa',
      icon: Icons.delete_outline,
      destructive: true,
    );
    if (!confirm || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.service.deleteUser(u.id);
      if (!mounted) return;
      setState(() => _busy = false);
      _showToast('Đã xóa user');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showToast('Lỗi khi xóa: $e', isError: true);
    }
  }

  /// Đổi màu "holder" của hàng — ghi thẳng xuống Firebase ngay.
  Future<void> _setColor(AppUser u, String colorKey) async {
    if (u.rowColor == colorKey) return;
    setState(() => _busy = true);
    try {
      await widget.service.updateRowColor(docId: u.id, colorKey: colorKey);
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showToast('Lỗi khi đổi màu: $e', isError: true);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (!_canAct || !widget.reorderEnabled) return;
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    final list = [..._users];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    setState(() => _users = list); // cập nhật ngay (optimistic)
    _persistOrder(list);
  }

  Future<void> _persistOrder(List<AppUser> ordered) async {
    setState(() {
      _busy = true;
      _reordering = true;
    });
    try {
      await widget.service.persistOrder(ordered);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _reordering = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _reordering = false;
        _users = widget.users; // hoàn lại nếu lỗi
      });
      _showToast('Lỗi khi đổi thứ tự: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _hScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hScrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _totalWidth,
          child: Column(
            children: [
              _headerRow(),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _users.length,
                  onReorder: _onReorder,
                  proxyDecorator: (child, index, animation) => Material(
                    elevation: 6,
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: child,
                  ),
                  itemBuilder: (context, i) => _dataRow(i),
                ),
              ),
              if (_addingNew)
                Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: _newRow(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lớp phủ "neo" cụm nút thao tác vào mép phải KHUNG NHÌN.
  ///
  /// Khi bảng chưa cuộn hết sang phải, cụm nút nổi ngay cạnh phải khung nhìn
  /// (đè lên nội dung phía sau, có nền đục + bóng đổ để dễ nhìn). Khi đã cuộn
  /// tới cuối, [floatLeft] chạm vị trí cột cuối nên cụm nút về đúng chỗ như
  /// một cột bình thường (bỏ bóng đổ). Chỉ lớp phủ này rebuild theo cuộn ngang,
  /// không rebuild cả danh sách.
  Widget _pinnedActions({
    required Color background,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _hScrollController,
        child: child,
        builder: (context, child) {
          final maxLeft = _totalWidth - _wActions;
          // Bề rộng vùng nhìn + offset lấy trực tiếp từ scroll position
          // (tránh LayoutBuilder làm tổ tiên ReorderableListView gây lỗi layout).
          var floatLeft = maxLeft;
          if (_hScrollController.hasClients) {
            final pos = _hScrollController.position;
            floatLeft = (pos.pixels + pos.viewportDimension - _wActions)
                .clamp(0.0, maxLeft)
                .toDouble();
          }
          // Đang "nổi" khi chưa về tới vị trí cột cuối cùng.
          final floating = floatLeft < maxLeft - 0.5;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: floatLeft),
              Container(
                width: _wActions,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: background,
                  border: Border(
                    left: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  boxShadow: floating
                      ? [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.18),
                            blurRadius: 5,
                            offset: const Offset(-3, 0),
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerRow() {
    final colorScheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurface,
    );
    Widget h(double w, String label) => _cell(w, Text(label, style: style));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              _cell(_wHandle, const SizedBox()),
              h(_wIndex, '#'),
              for (final col in _visibleCols) h(col.width, col.label),
              const SizedBox(width: _wActions),
            ],
          ),
          _pinnedActions(
            background: colorScheme.surfaceContainerHighest,
            child: Text('Hành động', style: style),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(int i) {
    final u = _users[i];
    final editing = _editingId == u.id;
    final colorScheme = Theme.of(context).colorScheme;
    final baseBg = colorScheme.surface;
    // Màu "holder" của hàng theo chế độ Sáng/Tối hiện hành (null = không tô).
    final rowColor =
        RowPalette.backgroundFor(u.rowColor, Theme.of(context).brightness);
    // Nền hàng dạng ĐỤC để cột thao tác neo phải che sạch nội dung phía sau
    // khi đang nổi giữa khung nhìn. Khi đang sửa: ưu tiên tông "đang sửa".
    final rowBg = editing
        ? Color.alphaBlend(
            colorScheme.primaryContainer.withValues(alpha: 0.2), baseBg)
        : (rowColor ?? baseBg);

    return Container(
      key: ValueKey(u.id),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _dragHandle(i),
              _cell(_wIndex, Text(widget.reorderEnabled ? '$i' : '${u.index}')),
              ...(editing ? _editCells() : _readCells(u)),
              const SizedBox(width: _wActions),
            ],
          ),
          _pinnedActions(
            background: rowBg,
            child: editing ? _editActions(onCancel: _cancelEdit) : _rowActions(u),
          ),
        ],
      ),
    );
  }

  Widget _newRow() {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = Color.alphaBlend(
      colorScheme.primaryContainer.withValues(alpha: 0.25),
      colorScheme.surface,
    );
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              _cell(_wHandle, const SizedBox()),
              _cell(_wIndex, Text('${_users.length}')),
              ..._editCells(),
              const SizedBox(width: _wActions),
            ],
          ),
          _pinnedActions(
            background: bg,
            child: _editActions(onCancel: _cancelAdd),
          ),
        ],
      ),
    );
  }

  Widget _dragHandle(int i) {
    final colorScheme = Theme.of(context).colorScheme;
    final canDrag = _canAct && widget.reorderEnabled;
    final icon = Icon(
      Icons.drag_indicator,
      color: canDrag ? colorScheme.onSurfaceVariant : colorScheme.outlineVariant,
    );
    return _cell(
      _wHandle,
      canDrag
          ? ReorderableDragStartListener(
              index: i,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Tooltip(message: 'Kéo để đổi thứ tự', child: icon),
              ),
            )
          : icon,
    );
  }

  List<Widget> _editCells() {
    Widget build(String key, double w) => switch (key) {
      'id'          => _cell(w, _idEditField()),
      'name'        => _cell(w, _miniField(_nameCtrl)),
      'who'         => _cell(w, _miniField(_whoCtrl)),
      'me'          => _cell(w, _miniField(_meCtrl)),
      'email'       => _cell(w, _miniField(_emailCtrl)),
      'phone'       => _cell(w, _miniField(_phoneCtrl)),
      'address'     => _cell(w, _miniField(_addressCtrl)),
      'message'     => _cell(w, _expandableField(_messageCtrl, 'Message')),
      'des1'        => _cell(w, _expandableField(_des1Ctrl, 'Des_1')),
      'des2'        => _cell(w, _expandableField(_des2Ctrl, 'Des_2')),
      'des3'        => _cell(w, _expandableField(_des3Ctrl, 'Des_3')),
      'timeMeeting' => _cell(w, _miniField(_timeMeetingCtrl)),
      'timeEnding'  => _cell(w, _miniField(_timeEndingCtrl)),
      'active'      => _cell(w, Switch(value: _editActive,  onChanged: (v) => setState(() => _editActive  = v))),
      'confirm'     => _cell(w, Switch(value: _editConfirm, onChanged: (v) => setState(() => _editConfirm = v))),
      'showAllPhotos' => _cell(w, Switch(value: _editShowAllPhotos, onChanged: (v) => setState(() => _editShowAllPhotos = v))),
      'updated'     => _cell(w, const Text('-')),
      _             => const SizedBox.shrink(),
    };
    return [for (final c in _visibleCols) build(c.key, c.width)];
  }

  List<Widget> _readCells(AppUser u) {
    Widget build(String key, double w) => switch (key) {
      'id'          => _cell(w, Text('${u.userId}')),
      'name'        => _cell(w, _readText(u.name)),
      'who'         => _cell(w, _readText(u.who)),
      'me'          => _cell(w, _readText(u.me)),
      'email'       => _cell(w, _readText(u.email)),
      'phone'       => _cell(w, _readText(u.phone)),
      'address'     => _cell(w, _readText(u.address)),
      'message'     => _cell(w, _readText(u.message)),
      'des1'        => _cell(w, _readText(u.des1)),
      'des2'        => _cell(w, _readText(u.des2)),
      'des3'        => _cell(w, _readText(u.des3)),
      'timeMeeting' => _cell(w, _readText(u.timeMeeting)),
      'timeEnding'  => _cell(w, _readText(u.timeEnding)),
      'active'      => _cell(w, _boolIcon(u.isActive)),
      'confirm'     => _cell(w, _boolIcon(u.isConfirm)),
      'showAllPhotos' => _cell(w, _boolIcon(u.showAllPhotos)),
      'updated'     => _cell(w, Text(_formatTime(u.timeUpdated))),
      _             => const SizedBox.shrink(),
    };
    return [for (final c in _visibleCols) build(c.key, c.width)];
  }

  Widget _cell(double width, Widget child) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }

  Widget _miniField(TextEditingController c, {bool number = false}) {
    return TextField(
      controller: c,
      // Multiline để Enter xuống dòng được (trừ ô số).
      keyboardType: number ? TextInputType.number : TextInputType.multiline,
      inputFormatters:
          number ? [FilteringTextInputFormatter.digitsOnly] : null,
      // Tự giãn theo nội dung: 1 dòng khi text ngắn, rộng dần theo số dòng,
      // tối đa 5 dòng rồi cuộn bên trong ô.
      minLines: 1,
      maxLines: number ? 1 : 5,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }

  /// Ô nhập dạng "xem trước + nhấn để mở popup". Dùng cho các field nội dung
  /// dài (Message, Des_1/2/3) để có không gian rộng hơn khi nhập.
  Widget _expandableField(TextEditingController c, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = c.text.trim();
    return InkWell(
      onTap: () => _openTextEditor(c, label),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          suffixIcon: const Icon(Icons.open_in_full, size: 16),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        child: Text(
          text.isEmpty ? 'Nhấn để nhập…' : text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: text.isEmpty
              ? TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                )
              : null,
        ),
      ),
    );
  }

  /// Mở popup soạn nội dung với khung lớn. Chỉ ghi lại vào [c] khi bấm "Xong".
  Future<void> _openTextEditor(TextEditingController c, String label) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextEditorDialog(label: label, initialText: c.text),
    );
    // null = đã hủy / bấm ra ngoài -> giữ nguyên; chuỗi (kể cả rỗng) = đã "Xong".
    if (result != null) {
      c.text = result;
      if (mounted) setState(() {}); // cập nhật phần xem trước
    }
  }

  /// Ô nhập mã ID (số, tối đa 4 chữ số) ở chế độ thêm/sửa.
  /// - Khi sửa user cũ: điền sẵn mã hiện có, admin có thể đổi.
  /// - Khi thêm mới: để trống -> hiện gợi ý "Tự động" và sẽ tự sinh lúc lưu.
  Widget _idEditField() {
    return TextField(
      controller: _idCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        hintText: _addingNew ? 'Tự động' : null,
      ),
    );
  }

  Widget _readText(String value) {
    return Text(
      value.isEmpty ? '-' : value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _boolIcon(bool value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Icon(
      value ? Icons.check_circle : Icons.cancel_outlined,
      color: value ? Colors.green : colorScheme.outline,
      size: 20,
    );
  }

  Widget _iconBtn(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    Color? color,
    Widget? customIcon,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: customIcon ?? Icon(icon, size: 20),
      color: color,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    );
  }

  Widget _rowActions(AppUser u) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _colorPickerButton(u),
        _iconBtn(Icons.edit_outlined, 'Sửa', _canAct ? () => _startEdit(u) : null),
        _iconBtn(Icons.content_copy_outlined, 'Sao chép',
            _canAct ? () => _copy(u) : null),
        _iconBtn(Icons.delete_outline, 'Xóa', _canAct ? () => _delete(u) : null,
            color: colorScheme.error),
      ],
    );
  }

  /// Nút chọn màu "holder" cho hàng: ô tròn hiển thị màu hiện tại, bấm mở
  /// menu các màu (kèm "Không màu"); chọn xong ghi thẳng xuống Firebase.
  Widget _colorPickerButton(AppUser u) {
    final colorScheme = Theme.of(context).colorScheme;
    final current = RowPalette.byKey(u.rowColor);
    return PopupMenuButton<String>(
      enabled: _canAct,
      tooltip: 'Màu hàng',
      position: PopupMenuPosition.under,
      onSelected: (key) => _setColor(u, key),
      itemBuilder: (ctx) => [
        _colorMenuItem(RowPalette.none, 'Không màu', null, u.rowColor.isEmpty),
        ...RowPalette.options.map(
          (o) => _colorMenuItem(o.key, o.label, o, o.key == u.rowColor),
        ),
      ],
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: current == null
              ? Icon(
                  Icons.palette_outlined,
                  size: 20,
                  color: _canAct
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.outlineVariant,
                )
              : ColorDot(option: current, size: 20),
        ),
      ),
    );
  }

  PopupMenuItem<String> _colorMenuItem(
    String key,
    String label,
    RowColorOption? option,
    bool selected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      value: key,
      child: Row(
        children: [
          ColorDot(option: option, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (selected) Icon(Icons.check, size: 18, color: colorScheme.primary),
        ],
      ),
    );
  }

  // Cột "Hành động" khi đang sửa/thêm chỉ còn nút Hủy — việc Lưu nay do
  // nút nổi "Lưu" ở AdminPage đảm nhiệm.
  Widget _editActions({required VoidCallback onCancel}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBtn(Icons.close, 'Hủy', _busy ? null : onCancel),
      ],
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

/// Popup soạn nội dung dài (Message, Des_1/2/3).
///
/// Tự quản lý controller nháp và chỉ dispose trong [dispose] của chính nó —
/// tức là sau khi dialog đã bị gỡ khỏi cây widget. Nếu dispose ngay sau
/// `await showDialog` thì controller bị hủy trong lúc animation đóng còn chạy
/// (TextField vẫn còn sống) -> lỗi "TextEditingController used after disposed".
class _TextEditorDialog extends StatefulWidget {
  const _TextEditorDialog({required this.label, required this.initialText});

  final String label;
  final String initialText;

  @override
  State<_TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<_TextEditorDialog> {
  late final TextEditingController _draft =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _draft,
          autofocus: true,
          minLines: 8,
          maxLines: 16,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Nhập nội dung…',
          ),
        ),
      ),
      actions: [
        TextButton(
          // null -> giữ nguyên nội dung cũ.
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          // Trả chuỗi (kể cả rỗng) -> ghi đè nội dung.
          onPressed: () => Navigator.of(context).pop(_draft.text),
          child: const Text('Xong'),
        ),
      ],
    );
  }
}

// ── Dialog ẩn/hiện & sắp xếp cột ────────────────────────────────────────────

class _ColumnPickerDialog extends StatefulWidget {
  const _ColumnPickerDialog({
    required this.colOrder,
    required this.hiddenCols,
    required this.onApply,
  });

  final List<String> colOrder;
  final Set<String> hiddenCols;
  final void Function(List<String> order, Set<String> hidden) onApply;

  @override
  State<_ColumnPickerDialog> createState() => _ColumnPickerDialogState();
}

class _ColumnPickerDialogState extends State<_ColumnPickerDialog> {
  late List<String> _order  = List.of(widget.colOrder);
  late Set<String>  _hidden = Set.of(widget.hiddenCols);

  String _label(String key) =>
      _kCols.firstWhere((c) => c.key == key, orElse: () => _Col(key, key, 0)).label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Cột hiển thị'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SizedBox(
        width: 300,
        child: ReorderableListView.builder(
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          itemCount: _order.length,
          onReorder: (oldIdx, newIdx) {
            setState(() {
              if (newIdx > oldIdx) newIdx--;
              final key = _order.removeAt(oldIdx);
              _order.insert(newIdx, key);
            });
            widget.onApply(_order, _hidden);
          },
          itemBuilder: (ctx, i) {
            final key    = _order[i];
            final hidden = _hidden.contains(key);
            return ListTile(
              key: ValueKey(key),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: ReorderableDragStartListener(
                index: i,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Icon(Icons.drag_handle,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              title: Text(
                _label(key),
                style: hidden
                    ? TextStyle(color: theme.colorScheme.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough)
                    : null,
              ),
              trailing: Switch(
                value: !hidden,
                onChanged: (_) {
                  setState(() {
                    if (hidden) { _hidden.remove(key); } else { _hidden.add(key); }
                  });
                  widget.onApply(_order, _hidden);
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _order  = _kCols.map((c) => c.key).toList();
              _hidden = {};
            });
            widget.onApply(_order, _hidden);
          },
          child: const Text('Đặt lại'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Xong'),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: colorScheme.error),
            const SizedBox(height: 16),
            const Text('Lỗi khi đọc Firestore'),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
