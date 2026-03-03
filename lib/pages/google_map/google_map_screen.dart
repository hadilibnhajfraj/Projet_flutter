import 'dart:async';
import 'package:dash_master_toolkit/pages/google_map/map_imports.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:responsive_framework/responsive_framework.dart' as rf;

import '../../services/address_service.dart';
import '../../tables/model/project_map_item.dart';
import '../../services/kpi_service.dart';

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

  // ✅ IMPORTANT: on mémorise l’input collé (pas displayName)
  String _lastInput = "";

  static const LatLng initial = LatLng(36.8065, 10.1815);
  LatLng? _selected;

  List<ProjectMapItem> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    addressCtrl.addListener(_onAddressChanged);
    _loadProjects();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    addressCtrl.removeListener(_onAddressChanged);
    addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await KpiService.fetchMapProjects();
      if (!mounted) return;
      setState(() {
        _projects = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;

    if (_selected != null) {
      await _moveCamera(_selected!, 16);
      if (mounted) setState(() {});
    }
  }

  void _onAddressChanged() {
    final input = addressCtrl.text.trim();
    if (input.length < 3) return;

    // ✅ compare avec le texte collé/tapé
    if (input == _lastInput) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      await _resolveInput(input);
    });
  }

  // ✅ markers: projets + selected
  Set<Marker> get _markers {
    final markers = <Marker>{};

    if (_selected != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("selected"),
          position: _selected!,
          infoWindow: const InfoWindow(title: "Adresse sélectionnée"),
        ),
      );
    }

    for (final p in _projects) {
      if (p.lat == 0 && p.lng == 0) continue;

      markers.add(
        Marker(
          markerId: MarkerId("project_${p.id}"),
          position: LatLng(p.lat, p.lng),
          infoWindow: InfoWindow(
            title: p.nomProjet,
            snippet: [
              if (p.adresse != null && p.adresse!.trim().isNotEmpty) p.adresse!.trim(),
              if (p.validationStatut != null) "Validation: ${p.validationStatut}",
              if (p.statut != null) "Statut: ${p.statut}",
            ].where((x) => x.trim().isNotEmpty).join(" • "),
          ),
          onTap: () async {
            await _moveCamera(LatLng(p.lat, p.lng), 16);
          },
        ),
      );
    }

    return markers;
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

  // ✅ NOUVEAU : gère maps.app.goo.gl + lat,lng + lien long + adresse
  Future<void> _resolveInput(String input) async {
    try {
      final v = input.trim();
      if (v.length < 3) return;

      _lastInput = v;

      // 1) ✅ lien court Google Maps (nécessite backend)
      if (v.contains("maps.app.goo.gl") || v.contains("goo.gl")) {
        final coords = await AddressService.expandShortGoogleMaps(v); // <-- à implémenter
        if (!mounted) return;

        if (coords != null) {
          final p = LatLng(coords.$1, coords.$2);
          _applyLocation(p);
          await _moveCamera(p, 16);
          if (mounted) setState(() {});
        }
        return;
      }

      // 2) ✅ "lat,lng"
      final direct = _extractLatLng(v);
      if (direct != null) {
        final p = LatLng(direct.$1, direct.$2);
        _applyLocation(p);
        await _moveCamera(p, 16);
        if (mounted) setState(() {});
        return;
      }

      // 3) ✅ lien Google Maps long avec coords
      final fromUrl = _extractLatLngFromGoogleMapsUrl(v);
      if (fromUrl != null) {
        final p = LatLng(fromUrl.$1, fromUrl.$2);
        _applyLocation(p);
        await _moveCamera(p, 16);
        if (mounted) setState(() {});
        return;
      }

      // 4) ✅ adresse texte -> geocoding
      final results = await AddressService.search(v);
      if (!mounted || results.isEmpty) return;

      final best = results.first;

      // ✅ (optionnel) normaliser le texte SANS bloquer le paste
      // final clean = best.displayName.trim();
      // if (addressCtrl.text.trim() != clean) {
      //   addressCtrl.value = addressCtrl.value.copyWith(
      //     text: clean,
      //     selection: TextSelection.collapsed(offset: clean.length),
      //     composing: TextRange.empty,
      //   );
      // }

      final p = LatLng(best.lat, best.lon);
      _applyLocation(p);
      await _moveCamera(p, 16);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  (double, double)? _extractLatLng(String s) {
    final m = RegExp(r'(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)').firstMatch(s);
    if (m == null) return null;
    final lat = double.tryParse(m.group(1)!);
    final lng = double.tryParse(m.group(2)!);
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return (lat, lng);
  }

  (double, double)? _extractLatLngFromGoogleMapsUrl(String url) {
    final at = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(url);
    if (at != null) {
      final lat = double.tryParse(at.group(1)!);
      final lng = double.tryParse(at.group(2)!);
      if (lat != null && lng != null) return (lat, lng);
    }

    final q = RegExp(r'(?:query=|q=)(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)').firstMatch(url);
    if (q != null) {
      final lat = double.tryParse(q.group(1)!);
      final lng = double.tryParse(q.group(2)!);
      if (lat != null && lng != null) return (lat, lng);
    }
    return null;
  }

  Future<void> _onTap(LatLng p) async {
    _applyLocation(p);
    await _moveCamera(p, 16);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final target = _selected ??
        (_projects.isNotEmpty ? LatLng(_projects.first.lat, _projects.first.lng) : initial);

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Projets géolocalisés",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: "Rafraîchir",
                            onPressed: _loadProjects,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // ✅ champ adresse (utile pour test)
                      TextField(
                        controller: addressCtrl,
                        decoration: const InputDecoration(
                          labelText: "Adresse / Lien Google Maps / lat,lng",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_loading) const LinearProgressIndicator(),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 10),

                      SizedBox(
                        height: 650,
                        child: GoogleMap(
                          mapType: MapType.normal,
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: CameraPosition(
                            target: target,
                            zoom: 10,
                          ),
                          onTap: _onTap,
                          markers: _markers,
                          zoomControlsEnabled: true,
                          myLocationButtonEnabled: false,

                          // ✅ IMPORTANT: interactions OK sur mobile (map dans ScrollView)
                          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                          },
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