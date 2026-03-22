import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../providers/provider.dart';
import '../../services/maintenance_service.dart';
import '../../widgets/reusable_widgets.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // ── Basic Info ──────────────────────────────────────────────
  String? selectedType;
  final makeController        = TextEditingController();
  final modelController       = TextEditingController();
  final yearController        = TextEditingController();
  final mileageController     = TextEditingController();

  // ── Maintenance History (all optional – default to currentMileage) ──
  final lastOilController           = TextEditingController();
  final tyresAgeController          = TextEditingController();
  final brakesAgeController         = TextEditingController();
  final airFilterController         = TextEditingController();
  final transmissionFluidController = TextEditingController();
  final coolantController           = TextEditingController();
  final sparkPlugsController        = TextEditingController();
  final batteryController           = TextEditingController();
  final brakeFluidController        = TextEditingController();
  final timingBeltController        = TextEditingController();
  final chainController             = TextEditingController();
  final alignmentController         = TextEditingController();
  final suspensionController        = TextEditingController();

  @override
  void dispose() {
    makeController.dispose();
    modelController.dispose();
    yearController.dispose();
    mileageController.dispose();
    lastOilController.dispose();
    tyresAgeController.dispose();
    brakesAgeController.dispose();
    airFilterController.dispose();
    transmissionFluidController.dispose();
    coolantController.dispose();
    sparkPlugsController.dispose();
    batteryController.dispose();
    brakeFluidController.dispose();
    timingBeltController.dispose();
    chainController.dispose();
    alignmentController.dispose();
    suspensionController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────

  bool get _isCar  => selectedType == 'Car';
  bool get _isBike => selectedType == 'Bike';

  /// Parse a text-field value; fall back to [fallback] if empty/invalid.
  double _parseOrFallback(TextEditingController c, double fallback) {
    final text = c.text.trim();
    if (text.isEmpty) return fallback;
    return double.tryParse(text) ?? fallback;
  }

  // ── Firestore write ─────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (selectedType == null) {
      _showSnack('Please select a vehicle type', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final auth      = ref.read(firebaseAuthProvider);
      final firestore = ref.read(firestoreProvider);
      final user      = auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final double currentMileage =
          double.tryParse(mileageController.text.trim()) ?? 0.0;

      // Start with the canonical initial-fields map so no field is ever missing
      final Map<String, dynamic> data =
      MaintenanceService.getInitialMaintenanceFields(
          selectedType!, currentMileage);

      // Overlay core identity fields
      data.addAll({
        'type':    selectedType!,
        'make':    makeController.text.trim(),
        'model':   modelController.text.trim(),
        'year':    int.tryParse(yearController.text.trim()) ?? 0,
        'mileage': currentMileage,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Overlay user-supplied maintenance values (only override if provided)
      void _maybe(String key, TextEditingController c) {
        final text = c.text.trim();
        if (text.isNotEmpty) {
          final v = double.tryParse(text);
          if (v != null) data[key] = v;
        }
      }

      _maybe('engineOil',           lastOilController);
      _maybe('tyresAge',            tyresAgeController);
      _maybe('brakesAge',           brakesAgeController);
      _maybe('airFilterAge',        airFilterController);
      _maybe('coolantAge',          coolantController);
      _maybe('sparkPlugsAge',       sparkPlugsController);
      _maybe('batteryAge',          batteryController);
      _maybe('brakeFluidAge',       brakeFluidController);
      _maybe('suspensionAge',       suspensionController);

      if (_isCar) {
        _maybe('transmissionFluidAge', transmissionFluidController);
        _maybe('timingBeltAge',        timingBeltController);
        _maybe('alignmentAge',         alignmentController);
      }
      if (_isBike) {
        _maybe('chainAge', chainController);
      }

      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .add(data);

      _showSnack('Vehicle added successfully! 🚗');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    showAppSnackBar(
      context,
      msg,
      backgroundColor: isError ? Colors.red : Colors.green,
    );
  }

  // ── UI ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add Vehicle'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff6a11cb), Color(0xff2575fc)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Vehicle Type ───────────────────────────────
              _sectionHeader('Vehicle Type', Icons.directions_car_rounded),
              SizedBox(height: 12.h),
              _buildTypeSelector(),

              SizedBox(height: 24.h),

              // ─── Basic Info ─────────────────────────────────
              _sectionHeader('Basic Information', Icons.info_outline_rounded),
              SizedBox(height: 12.h),
              _buildCard([
                _field(makeController,    'Make',            'e.g. Toyota',  isRequired: true),
                _field(modelController,   'Model',           'e.g. Corolla', isRequired: true),
                _field(yearController,    'Year',            'e.g. 2021',    isRequired: true,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final y = int.tryParse(v);
                      if (y == null || y < 1900 || y > DateTime.now().year + 2) {
                        return 'Enter a valid year';
                      }
                      return null;
                    }),
                _field(mileageController, 'Current Mileage (km)', 'e.g. 45000', isRequired: true,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Enter a number';
                      return null;
                    }),
              ]),

              SizedBox(height: 16.h),

              // ─── Maintenance History (collapsible) ──────────
              _buildMaintenanceSection(isDark),

              SizedBox(height: 32.h),

              // ─── Save Button ────────────────────────────────
              _buildSaveButton(),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section header ───────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20.r, color: const Color(0xff6a11cb)),
        SizedBox(width: 8.w),
        Text(title,
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color)),
      ],
    );
  }

  // ── Type selector (Car / Bike chips) ─────────────────────────

  Widget _buildTypeSelector() {
    return Row(
      children: ['Car', 'Bike'].map((type) {
        final selected = selectedType == type;
        return Padding(
          padding: EdgeInsets.only(right: 12.w),
          child: GestureDetector(
            onTap: () => setState(() => selectedType = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                    colors: [Color(0xff6a11cb), Color(0xff2575fc)])
                    : null,
                color: selected ? null : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : Colors.grey.withOpacity(0.3),
                ),
                boxShadow: selected
                    ? [
                  BoxShadow(
                    color: const Color(0xff6a11cb).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type == 'Car'
                        ? Icons.directions_car_filled_rounded
                        : Icons.two_wheeler_rounded,
                    color: selected ? Colors.white : Colors.grey,
                    size: 20.r,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Card wrapper ─────────────────────────────────────────────

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(16.r),
      child: Column(
        children: children
            .expand((w) => [w, SizedBox(height: 12.h)])
            .toList()
          ..removeLast(),
      ),
    );
  }

  // ── Maintenance collapsible section ──────────────────────────

  Widget _buildMaintenanceSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        // Remove default ExpansionTile dividers
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16.w),
          childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          leading: Icon(Icons.build_circle_outlined,
              color: const Color(0xff6a11cb), size: 24.r),
          title: Text(
            'Maintenance History',
            style:
            TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            'Optional – leave blank to use current mileage',
            style: TextStyle(fontSize: 11.sp, color: Colors.grey),
          ),
          children: [
            // ── Core (always visible) ──────────────────
            _maintenanceSubHeader('Engine'),
            _field(lastOilController, 'Last Oil Change (km)',
                'Mileage at last change'),
            SizedBox(height: 10.h),
            _field(airFilterController, 'Air Filter Last Changed (km)',
                'Mileage at last change'),
            SizedBox(height: 10.h),
            _field(coolantController, 'Coolant Last Flushed (km)',
                'Mileage at last flush'),
            SizedBox(height: 10.h),
            _field(sparkPlugsController, 'Spark Plugs Last Replaced (km)',
                'Mileage at last replacement'),

            SizedBox(height: 14.h),
            _maintenanceSubHeader('Safety'),
            _field(tyresAgeController, 'Tyres Installed At (km)',
                'Mileage when tyres were fitted'),
            SizedBox(height: 10.h),
            _field(brakesAgeController, 'Brakes Last Serviced (km)',
                'Mileage at last service'),
            SizedBox(height: 10.h),
            _field(brakeFluidController, 'Brake Fluid Last Changed (km)',
                'Mileage at last change'),

            SizedBox(height: 14.h),
            _maintenanceSubHeader('Electrical'),
            _field(batteryController, 'Battery Last Checked (km)',
                'Mileage at last check'),

            SizedBox(height: 14.h),
            _maintenanceSubHeader('Suspension'),
            _field(suspensionController, 'Suspension Last Inspected (km)',
                'Mileage at last inspection'),

            // ── Car-only ──────────────────────────────
            if (_isCar) ...[
              SizedBox(height: 14.h),
              _maintenanceSubHeader('Transmission / Drivetrain'),
              _field(transmissionFluidController,
                  'Transmission Fluid Changed At (km)',
                  'Mileage at last change'),
              SizedBox(height: 10.h),
              _field(timingBeltController,
                  'Timing Belt Last Done (km)',
                  'Mileage at last replacement'),
              SizedBox(height: 14.h),
              _maintenanceSubHeader('Wheels'),
              _field(alignmentController,
                  'Last Wheel Alignment (km)',
                  'Mileage at last alignment'),
            ],

            // ── Bike-only ─────────────────────────────
            if (_isBike) ...[
              SizedBox(height: 14.h),
              _maintenanceSubHeader('Drivetrain'),
              _field(chainController, 'Chain Last Lubricated (km)',
                  'Mileage at last lubrication'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _maintenanceSubHeader(String label) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Text(label,
        style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xff6a11cb),
            letterSpacing: 0.5)),
  );

  // ── Reusable validated text field ────────────────────────────

  Widget _field(
      TextEditingController controller,
      String label,
      String hint, {
        bool isRequired = false,
        TextInputType keyboardType = TextInputType.number,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        isDense: true,
      ),
      validator: validator ??
              (v) {
            if (isRequired && (v == null || v.trim().isEmpty)) {
              return '$label is required';
            }
            if (v != null && v.isNotEmpty && double.tryParse(v) == null) {
              return 'Enter a valid number';
            }
            return null;
          },
    );
  }

  // ── Save button ──────────────────────────────────────────────

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r)),
        ).copyWith(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isSaving
                ? null
                : const LinearGradient(
                colors: [Color(0xff6a11cb), Color(0xff2575fc)]),
            color: _isSaving ? Colors.grey : null,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xff2575fc).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: _isSaving
                ? SizedBox(
                width: 24.r,
                height: 24.r,
                child: const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
                : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Save Vehicle',
                    style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                SizedBox(width: 10.w),
                Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white, size: 22.r),
              ],
            ),
          ),
        ),
      ),
    );
  }
}