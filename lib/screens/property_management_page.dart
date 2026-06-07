import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class MonthRecord {
  final String monthKey; // e.g. "2024-06"
  final DateTime month;
  bool isPaid;
  DateTime? paidDate;
  String? updatedBy;

  MonthRecord({
    required this.monthKey,
    required this.month,
    this.isPaid = false,
    this.paidDate,
    this.updatedBy,
  });

  factory MonthRecord.fromFirestore(String key, Map<String, dynamic> data) {
    return MonthRecord(
      monthKey: key,
      month: _keyToDate(key),
      isPaid: data['isPaid'] ?? false,
      paidDate: data['paidDate'] != null
          ? (data['paidDate'] as Timestamp).toDate()
          : null,
      updatedBy: data['updatedBy'],
    );
  }

  static DateTime _keyToDate(String key) {
    final parts = key.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}

class PropertyRecord {
  final String id;
  final String propertyName;
  final String ownerName;
  final String tenantName;
  final double rent;
  final double deposit;
  final String duration;
  final DateTime startDate;
  final DateTime endDate;
  final String createdBy;
  List<MonthRecord> months;

  PropertyRecord({
    required this.id,
    required this.propertyName,
    required this.ownerName,
    required this.tenantName,
    required this.rent,
    required this.deposit,
    required this.duration,
    required this.startDate,
    required this.endDate,
    required this.createdBy,
    this.months = const [],
  });

  factory PropertyRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PropertyRecord(
      id: doc.id,
      propertyName: data['propertyName'] ?? '',
      ownerName: data['ownerName'] ?? '',
      tenantName: data['tenantName'] ?? '',
      rent: (data['rent'] ?? 0).toDouble(),
      deposit: (data['deposit'] ?? 0).toDouble(),
      duration: data['duration'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'propertyName': propertyName,
        'ownerName': ownerName,
        'tenantName': tenantName,
        'rent': rent,
        'deposit': deposit,
        'duration': duration,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdBy': createdBy,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static List<String> generateMonthKeys(DateTime start, DateTime end) {
    final keys = <String>[];
    DateTime current = DateTime(start.year, start.month);
    final last = DateTime(end.year, end.month);
    while (!current.isAfter(last)) {
      keys.add(
          '${current.year}-${current.month.toString().padLeft(2, '0')}');
      current = DateTime(current.year, current.month + 1);
    }
    return keys;
  }
}

// ─── Firestore Service ────────────────────────────────────────────────────────

class PropertyService {
  static final _col =
      FirebaseFirestore.instance.collection('rental_management');
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Add property + initialize payment subcollection docs
  static Future<void> addProperty(PropertyRecord p) async {
    final docRef = await _col.add({
      ...p.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _uid,
    });
    // Create payment docs for each month
    final batch = FirebaseFirestore.instance.batch();
    for (final key in PropertyRecord.generateMonthKeys(p.startDate, p.endDate)) {
      batch.set(docRef.collection('payments').doc(key), {
        'isPaid': false,
        'paidDate': null,
        'updatedBy': null,
      });
    }
    await batch.commit();
  }

  // Update property details
  static Future<void> updateProperty(PropertyRecord p) async {
    await _col.doc(p.id).update({
      ...p.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete property + all payment docs
  static Future<void> deleteProperty(String propertyId) async {
    final payments =
        await _col.doc(propertyId).collection('payments').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in payments.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_col.doc(propertyId));
    await batch.commit();
  }

  // Update a single month payment
  static Future<void> updatePayment(
      String propertyId, MonthRecord record) async {
    await _col.doc(propertyId).collection('payments').doc(record.monthKey).set({
      'isPaid': record.isPaid,
      'paidDate':
          record.paidDate != null ? Timestamp.fromDate(record.paidDate!) : null,
      'updatedBy': _uid,
    });
  }

  // Fetch payments for a property
  static Future<List<MonthRecord>> fetchPayments(
      String propertyId, DateTime start, DateTime end) async {
    final keys = PropertyRecord.generateMonthKeys(start, end);
    final snap =
        await _col.doc(propertyId).collection('payments').get();
    final dataMap = {for (final d in snap.docs) d.id: d.data()};
    return keys.map((key) {
      if (dataMap.containsKey(key)) {
        return MonthRecord.fromFirestore(key, dataMap[key]!);
      }
      return MonthRecord(
          monthKey: key,
          month: MonthRecord._keyToDate(key));
    }).toList();
  }
}

// ─── Main Page ────────────────────────────────────────────────────────────────

class PropertyManagementPage extends StatelessWidget {
  const PropertyManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Property Management',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE8E8F0), height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rental_management')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.home_work_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No properties yet',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade400)),
                  const SizedBox(height: 6),
                  Text('Tap + to add one',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final property =
                  PropertyRecord.fromFirestore(docs[index]);
              return _PropertyCard(property: property);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A1A2E),
        onPressed: () => _showPropertyForm(context, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─── Property Card ────────────────────────────────────────────────────────────

class _PropertyCard extends StatelessWidget {
  final PropertyRecord property;

  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    final totalMonths =
        PropertyRecord.generateMonthKeys(property.startDate, property.endDate)
            .length;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) =>
              PropertyDetailPage(property: property),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.home_work_rounded,
                        color: Color(0xFF1A1A2E), size: 26),
                  ),
                  const SizedBox(width: 14),

                  // Property info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property.propertyName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.person_outline,
                                size: 13, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                property.ownerName,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF6B7280)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.key_outlined,
                                size: 13, color: Color(0xFF6B7280)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                property.tenantName,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF6B7280)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${property.rent.toStringAsFixed(0)}/mo · ${property.duration}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Edit & Delete buttons
                  Column(
                    children: [
                      _iconBtn(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF3B82F6),
                        onTap: () => _showPropertyForm(context, property),
                      ),
                      const SizedBox(height: 6),
                      _iconBtn(
                        icon: Icons.delete_rounded,
                        color: const Color(0xFFEF4444),
                        onTap: () => _confirmDelete(context, property),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Progress bar from Firestore ──
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rental_management')
                    .doc(property.id)
                    .collection('payments')
                    .snapshots(),
                builder: (context, snap) {
                  int paidCount = 0;
                  if (snap.hasData) {
                    paidCount = snap.data!.docs
                        .where((d) =>
                            (d.data() as Map<String, dynamic>)['isPaid'] ==
                            true)
                        .length;
                  }
                  final remaining = totalMonths - paidCount;
                  final progress =
                      totalMonths > 0 ? paidCount / totalMonths : 0.0;
                  final isComplete = paidCount == totalMonths;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xFFE8E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete
                                ? const Color(0xFF10B981)
                                : progress > 0.6
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFF59E0B),
                          ),
                          minHeight: 7,
                        ),
                      ),
                      const SizedBox(height: 7),

                      // Labels
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: paid count
                          Text(
                            snap.connectionState == ConnectionState.waiting
                                ? 'Loading...'
                                : '$paidCount / $totalMonths months paid',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF6B7280)),
                          ),

                          // Right: remaining or all clear
                          isComplete
                              ? const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        size: 13, color: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text(
                                      'All paid',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                )
                              : Text(
                                  '$remaining month${remaining == 1 ? '' : 's'} remaining · '
                                  '₹${(remaining * property.rent).toStringAsFixed(0)} due',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF)),
                                ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

void _confirmDelete(BuildContext context, PropertyRecord property) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Property'),
      content: Text(
          'Are you sure you want to delete "${property.propertyName}"? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await PropertyService.deleteProperty(property.id);
          },
          child: const Text('Delete',
              style: TextStyle(color: Color(0xFFEF4444))),
        ),
      ],
    ),
  );
}

// ─── Add / Edit Form ──────────────────────────────────────────────────────────

void _showPropertyForm(BuildContext context, PropertyRecord? existing) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PropertyForm(existing: existing),
  );
}

class _PropertyForm extends StatefulWidget {
  final PropertyRecord? existing;

  const _PropertyForm({this.existing});

  @override
  State<_PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends State<_PropertyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _propertyName;
  late final TextEditingController _ownerName;
  late final TextEditingController _tenantName;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;
  late final TextEditingController _duration;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _propertyName = TextEditingController(text: e?.propertyName ?? '');
    _ownerName = TextEditingController(text: e?.ownerName ?? '');
    _tenantName = TextEditingController(text: e?.tenantName ?? '');
    _rent = TextEditingController(
        text: e != null ? e.rent.toStringAsFixed(0) : '');
    _deposit = TextEditingController(
        text: e != null ? e.deposit.toStringAsFixed(0) : '');
    _duration = TextEditingController(text: e?.duration ?? '');
    _startDate = e?.startDate;
    _endDate = e?.endDate;
  }

  @override
  void dispose() {
    _propertyName.dispose();
    _ownerName.dispose();
    _tenantName.dispose();
    _rent.dispose();
    _deposit.dispose();
    _duration.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A1A2E),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }
    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final record = PropertyRecord(
      id: widget.existing?.id ?? '',
      propertyName: _propertyName.text.trim(),
      ownerName: _ownerName.text.trim(),
      tenantName: _tenantName.text.trim(),
      rent: double.tryParse(_rent.text.trim()) ?? 0,
      deposit: double.tryParse(_deposit.text.trim()) ?? 0,
      duration: _duration.text.trim(),
      startDate: _startDate!,
      endDate: _endDate!,
      createdBy: uid,
    );

    try {
      if (widget.existing == null) {
        await PropertyService.addProperty(record);
      } else {
        await PropertyService.updateProperty(record);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                isEdit ? 'Edit Property' : 'Add New Property',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 20),

              _field('Property Name', _propertyName, Icons.home_work_rounded),
              _field('Owner Name', _ownerName, Icons.person_rounded),
              _field('Tenant Name', _tenantName, Icons.key_rounded),
              _field('Monthly Rent (₹)', _rent, Icons.currency_rupee_rounded,
                  isNumber: true),
              _field('Deposit (₹)', _deposit, Icons.savings_rounded,
                  isNumber: true),
              _field('Duration (e.g. 11 months)', _duration,
                  Icons.schedule_rounded),

              const SizedBox(height: 4),

              // Date pickers
              Row(
                children: [
                  Expanded(
                    child: _datePicker(
                      label: 'Start Date',
                      value: _startDate != null ? _fmt(_startDate!) : null,
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _datePicker(
                      label: 'End Date',
                      value: _endDate != null ? _fmt(_endDate!) : null,
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Add Property',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A1A2E), width: 1.5),
          ),
          filled: true,
          fillColor: const Color(0xFFFAFAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _datePicker(
      {required String label,
      required String? value,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null
                      ? const Color(0xFF1A1A2E)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Page ──────────────────────────────────────────────────────────────

class PropertyDetailPage extends StatefulWidget {
  final PropertyRecord property;

  const PropertyDetailPage({super.key, required this.property});

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  List<MonthRecord> _months = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final months = await PropertyService.fetchPayments(
      widget.property.id,
      widget.property.startDate,
      widget.property.endDate,
    );
    if (mounted) setState(() {
      _months = months;
      _loading = false;
    });
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickPaidDate(MonthRecord record) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: record.paidDate ?? record.month,
      firstDate: record.month,
      lastDate: DateTime(record.month.year, record.month.month + 1, 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A1A2E),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => record.paidDate = picked);
      await PropertyService.updatePayment(widget.property.id, record);
    }
  }

  Future<void> _togglePayment(MonthRecord record, bool val) async {
    setState(() {
      record.isPaid = val;
      if (!val) record.paidDate = null;
    });
    await PropertyService.updatePayment(widget.property.id, record);
    if (val) _pickPaidDate(record);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final paidCount = _months.where((m) => m.isPaid).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          p.propertyName,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6)),
            onPressed: () => _showPropertyForm(context, p),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444)),
            onPressed: () => _confirmDelete(context, p),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE8E8F0), height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Info Card ──
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROPERTY DETAILS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _infoRow(Icons.home_work_rounded, 'Property',
                          p.propertyName),
                      _infoRow(Icons.person_rounded, 'Owner', p.ownerName),
                      _infoRow(Icons.key_rounded, 'Tenant', p.tenantName),
                      const Divider(color: Colors.white24, height: 24),
                      _infoRow(Icons.currency_rupee_rounded, 'Monthly Rent',
                          '₹${p.rent.toStringAsFixed(0)}'),
                      _infoRow(Icons.savings_rounded, 'Deposit',
                          '₹${p.deposit.toStringAsFixed(0)}'),
                      _infoRow(Icons.schedule_rounded, 'Duration', p.duration),
                      const Divider(color: Colors.white24, height: 24),
                      _infoRow(Icons.calendar_today_rounded, 'Start Date',
                          _formatDate(p.startDate)),
                      _infoRow(Icons.event_rounded, 'End Date',
                          _formatDate(p.endDate)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Payment summary ──
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Text(
                        '$paidCount of ${_months.length} months paid',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${(paidCount * p.rent).toStringAsFixed(0)} collected',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'RENT PAYMENT TRACKER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 1.4,
                    ),
                  ),
                ),

                ..._months.map((record) => _MonthCard(
                      record: record,
                      monthLabel: _monthLabel(record.month),
                      rent: p.rent,
                      onToggle: (val) => _togglePayment(record, val),
                      onDateTap: () => _pickPaidDate(record),
                      formatDate: _formatDate,
                    )),

                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 10),
          Text('$label: ',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Month Card ───────────────────────────────────────────────────────────────

class _MonthCard extends StatelessWidget {
  final MonthRecord record;
  final String monthLabel;
  final double rent;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDateTap;
  final String Function(DateTime) formatDate;

  const _MonthCard({
    required this.record,
    required this.monthLabel,
    required this.rent,
    required this.onToggle,
    required this.onDateTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = record.isPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFFE8E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${rent.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => onToggle(!isPaid),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 80,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isPaid
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPaid
                            ? const Color(0xFF10B981)
                            : const Color(0xFFD1D5DB),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isPaid ? 'PAID' : 'UNPAID',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isPaid) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onDateTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            const Color(0xFF10B981).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 13, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        record.paidDate != null
                            ? 'Paid on ${formatDate(record.paidDate!)}'
                            : 'Tap to enter paid date',
                        style: TextStyle(
                          fontSize: 12,
                          color: record.paidDate != null
                              ? const Color(0xFF059669)
                              : const Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded,
                          size: 12, color: Color(0xFF10B981)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}