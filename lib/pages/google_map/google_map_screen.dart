import 'dart:async';
import 'package:dash_master_toolkit/pages/google_map/map_imports.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;
import '../../services/address_service.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  ThemeController themeController = Get.put(ThemeController());

  GoogleMapController? _mapController;

  final TextEditingController addressCtrl = TextEditingController();
  Timer? _debounce;
  String _lastQuery = "";

  static const LatLng initial = LatLng(36.8065, 10.1815);
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    addressCtrl.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    addressCtrl.removeListener(_onAddressChanged);
    addressCtrl.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    if (_selected != null) {
      await _moveCamera(_selected!, 16);
      if (mounted) setState(() {});
    }
  }

  void _onAddressChanged() {
    final q = addressCtrl.text.trim();
    if (q.length < 3) return;
    if (q == _lastQuery) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), () async {
      await _autoLocate(q);
    });
  }

  Set<Marker> get _markers {
    if (_selected == null) return {};
    return {
      Marker(
        markerId: const MarkerId("project"),
        position: _selected!,
        infoWindow: const InfoWindow(title: "Adresse"),
      ),
    };
  }

  void _applyLocation(LatLng p) {
    setState(() => _selected = p);
  }

  Future<void> _moveCamera(LatLng p, double zoom) async {
    final mc = _mapController;
    if (mc == null) return;
    await Future.delayed(const Duration(milliseconds: 80));
    await mc.animateCamera(CameraUpdate.newLatLngZoom(p, zoom));
  }

  Future<void> _autoLocate(String query) async {
    try {
      final results = await AddressService.search(query);
      if (!mounted || results.isEmpty) return;

      final best = results.first;
      _lastQuery = best.displayName;

      final clean = best.displayName.trim();
      if (addressCtrl.text.trim() != clean) {
        addressCtrl.value = addressCtrl.value.copyWith(
          text: clean,
          selection: TextSelection.collapsed(offset: clean.length),
          composing: TextRange.empty,
        );
      }

      final p = LatLng(best.lat, best.lon);
      _applyLocation(p);
      await _moveCamera(p, 16);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _onTap(LatLng p) async {
    _applyLocation(p);
    await _moveCamera(p, 16);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final target = _selected ?? initial;

    return Scaffold(
      backgroundColor: themeController.isDarkMode ? colorGrey900 : colorWhite,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          rf.ResponsiveValue<double>(
            context,
            conditionalValues: [
              const rf.Condition.between(start: 0, end: 340, value: 2),
              const rf.Condition.between(start: 341, end: 992, value: 8),
            ],
            defaultValue: 16,
          ).value,
        ),
        child: Column(
          children: [
            ResponsiveGridRow(
              children: [
                _dialogCard(
                  Column(
                    children: [
                      SizedBox(
                        height: 700,
                        child: GoogleMap(
                          mapType: MapType.normal,
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: target,
                            zoom: _selected == null ? 10 : 16,
                          ),
                          onTap: _onTap,
                          markers: _markers,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: "Adresse (copier/coller)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selected != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Lat: ${_selected!.latitude}, Lng: ${_selected!.longitude}",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ResponsiveGridCol _dialogCard(Widget child) {
    return ResponsiveGridCol(
      xs: 12,
      sm: 12,
      md: 12,
      lg: 12,
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 8, end: 8, top: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: themeController.isDarkMode ? colorDark : colorWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
