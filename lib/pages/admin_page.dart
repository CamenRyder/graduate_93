import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/auth_controller.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';
import '../theme/row_palette.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/theme_toggle_button.dart';

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

  bool get _hasFilter =>
      _nameQuery.trim().isNotEmpty ||
      _meetingQuery.trim().isNotEmpty ||
      _activeFilter != null ||
      _confirmFilter != null ||
      _colorFilter != null;

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
      if (name.isNotEmpty && !u.name.toLowerCase().contains(name)) return false;
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
              labelText: 'Tìm theo Name',
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
  });

  final List<AppUser> users;
  final FirestoreService service;
  final int addToken;

  /// Khi đang lọc/tìm kiếm thì tắt kéo-thả (false).
  final bool reorderEnabled;

  /// Trạng thái chia sẻ với nút nổi "Lưu" ở [AdminPage].
  final EditSession session;

  @override
  State<UsersTable> createState() => _UsersTableState();
}

class _UsersTableState extends State<UsersTable> {
  // Độ rộng từng cột (px).
  static const double _wHandle = 40;
  static const double _wIndex = 44;
  static const double _wId = 60;
  static const double _wName = 150;
  static const double _wWho = 120;
  static const double _wMe = 120;
  static const double _wEmail = 190;
  static const double _wPhone = 120;
  static const double _wAddress = 150;
  static const double _wMessage = 200;
  static const double _wDes = 110;
  static const double _wTimeM = 120;
  static const double _wTimeE = 120;
  static const double _wActive = 70;
  static const double _wConfirm = 80;
  static const double _wUpdated = 130;
  static const double _wActions = 190;

  double get _totalWidth =>
      _wHandle +
      _wIndex +
      _wId +
      _wName +
      _wWho +
      _wMe +
      _wEmail +
      _wPhone +
      _wAddress +
      _wMessage +
      _wDes * 3 +
      _wTimeM +
      _wTimeE +
      _wActive +
      _wConfirm +
      _wUpdated +
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
    _editRowColor = u.rowColor;
  }

  void _startAdd() {
    if (!_canAct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy lưu hoặc hủy hàng đang thao tác trước.')),
      );
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
    );
  }

  Future<void> _saveEdit(AppUser original) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    widget.session.setBusy(true);
    try {
      await widget.service.updateUser(
        _userFromControllers(id: original.id, index: original.index),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _editingId = null;
      });
      widget.session.end();
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      widget.session.setBusy(false);
      messenger.showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
    }
  }

  Future<void> _saveNew() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    widget.session.setBusy(true);
    try {
      // Tự sinh mã ID 4 chữ số ngẫu nhiên, không trùng — admin không nhập tay.
      final newId = await widget.service.generateUniqueUserId();
      _idCtrl.text = newId.toString();
      await widget.service.addUser(_userFromControllers(id: '', index: 0));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _addingNew = false;
      });
      widget.session.end();
      messenger.showSnackBar(const SnackBar(content: Text('Đã thêm user mới')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      widget.session.setBusy(false);
      messenger.showSnackBar(SnackBar(content: Text('Lỗi khi thêm: $e')));
    }
  }

  Future<void> _copy(AppUser u) async {
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã sao chép — chỉnh sửa rồi bấm Lưu')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Lỗi khi sao chép: $e')));
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

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.service.deleteUser(u.id);
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xóa user')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
    }
  }

  /// Đổi màu "holder" của hàng — ghi thẳng xuống Firebase ngay.
  Future<void> _setColor(AppUser u, String colorKey) async {
    if (u.rowColor == colorKey) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.service.updateRowColor(docId: u.id, colorKey: colorKey);
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Lỗi khi đổi màu: $e')));
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
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(SnackBar(content: Text('Lỗi khi đổi thứ tự: $e')));
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
              h(_wId, 'ID'),
              h(_wName, 'Name'),
              h(_wWho, 'who'),
              h(_wMe, 'Me'),
              h(_wEmail, 'Email'),
              h(_wPhone, 'Phone'),
              h(_wAddress, 'Address'),
              h(_wMessage, 'Message'),
              h(_wDes, 'Des_1'),
              h(_wDes, 'Des_2'),
              h(_wDes, 'Des_3'),
              h(_wTimeM, 'timeMeeting'),
              h(_wTimeE, 'timeEnding'),
              h(_wActive, 'Active'),
              h(_wConfirm, 'Confirm'),
              h(_wUpdated, 'Cập nhật'),
              // Chừa chỗ cho cột thao tác (được vẽ ở lớp phủ neo bên dưới).
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
              _cell(_wUpdated, Text(_formatTime(u.timeUpdated))),
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
              _cell(_wUpdated, const Text('-')),
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

  List<Widget> _editCells() => [
        _cell(_wId, _idDisplayCell()),
        _cell(_wName, _miniField(_nameCtrl)),
        _cell(_wWho, _miniField(_whoCtrl)),
        _cell(_wMe, _miniField(_meCtrl)),
        _cell(_wEmail, _miniField(_emailCtrl)),
        _cell(_wPhone, _miniField(_phoneCtrl)),
        _cell(_wAddress, _miniField(_addressCtrl)),
        _cell(_wMessage, _expandableField(_messageCtrl, 'Message')),
        _cell(_wDes, _expandableField(_des1Ctrl, 'Des_1')),
        _cell(_wDes, _expandableField(_des2Ctrl, 'Des_2')),
        _cell(_wDes, _expandableField(_des3Ctrl, 'Des_3')),
        _cell(_wTimeM, _miniField(_timeMeetingCtrl)),
        _cell(_wTimeE, _miniField(_timeEndingCtrl)),
        _cell(
          _wActive,
          Switch(
            value: _editActive,
            onChanged: (v) => setState(() => _editActive = v),
          ),
        ),
        _cell(
          _wConfirm,
          Switch(
            value: _editConfirm,
            onChanged: (v) => setState(() => _editConfirm = v),
          ),
        ),
      ];

  List<Widget> _readCells(AppUser u) => [
        _cell(_wId, Text('${u.userId}')),
        _cell(_wName, _readText(u.name)),
        _cell(_wWho, _readText(u.who)),
        _cell(_wMe, _readText(u.me)),
        _cell(_wEmail, _readText(u.email)),
        _cell(_wPhone, _readText(u.phone)),
        _cell(_wAddress, _readText(u.address)),
        _cell(_wMessage, _readText(u.message)),
        _cell(_wDes, _readText(u.des1)),
        _cell(_wDes, _readText(u.des2)),
        _cell(_wDes, _readText(u.des3)),
        _cell(_wTimeM, _readText(u.timeMeeting)),
        _cell(_wTimeE, _readText(u.timeEnding)),
        _cell(_wActive, _boolIcon(u.isActive)),
        _cell(_wConfirm, _boolIcon(u.isConfirm)),
      ];

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
    final draft = TextEditingController(text: c.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: draft,
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xong'),
          ),
        ],
      ),
    );
    if (ok == true) {
      c.text = draft.text;
      if (mounted) setState(() {}); // cập nhật phần xem trước
    }
    draft.dispose();
  }

  /// Ô ID ở chế độ thêm/sửa: KHÔNG cho nhập tay.
  /// - Khi sửa user cũ: hiển thị mã hiện có.
  /// - Khi thêm mới: chưa có mã (sẽ tự sinh lúc lưu) -> hiển thị "Tự động".
  Widget _idDisplayCell() {
    final text = _idCtrl.text.trim();
    if (text.isNotEmpty) return _readText(text);
    return Text(
      'Tự động',
      style: TextStyle(
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
