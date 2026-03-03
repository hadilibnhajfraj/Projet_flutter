import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/address_service.dart';

class LocationPickerResult {
  final double lat;
  final double lng;
  final String comment;
  final String address;

  LocationPickerResult({
    required this.lat,
    required this.lng,
    required this.comment,
    required this.address,
  });
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialPosition,
    this.initialAddress,
  });

  final LatLng? initialPosition;
  final String? initialAddress;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng fallback = LatLng(36.8065, 10.1815); // Tunis

  GoogleMapController? _mapController;
  LatLng? _selected;

  final TextEditingController commentCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();

  Timer? _debounce;
  String _lastQuery = "";

  @override
  void initState() {
    super.initState();

    if (widget.initialAddress != null && widget.initialAddress!.trim().isNotEmpty) {
      addressCtrl.text = widget.initialAddress!.trim();
    }
    if (widget.initialPosition != null) {
      _selected = widget.initialPosition;
    }

    addressCtrl.addListener(_onAddressChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_selected != null) {
        await _moveCamera(_selected!, zoom: 16);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    addressCtrl.removeListener(_onAddressChanged);
    commentCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController c) async {
    _mapController = c;

    if (_selected != null) {
      await _moveCamera(_selected!, zoom: 16);
      if (mounted) setState(() {});
    }
  }

  // ✅ MARKERS (tu l'avais oublié => erreur)
  Set<Marker> get _markers {
    final s = _selected;
    if (s == null) return <Marker>{};

    return {
      Marker(
        markerId: const MarkerId("picked"),
        position: s,
        infoWindow: const InfoWindow(title: "Localisation sélectionnée"),
      ),
    };
  }

  void _onAddressChanged() {
    final raw = addressCtrl.text.trim();
    if (raw.isEmpty) return;
    if (raw == _lastQuery) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      await _resolveInput(raw);
    });
  }

  Future<void> _resolveInput(String input) async {
    // 1) short link google maps
    final isShort = input.contains("maps.app.goo.gl") || input.contains("goo.gl/maps");
    if (isShort) {
      final coords = await AddressService.expandShortGoogleMaps(input);
      if (!mounted || coords == null) return;

      final (lat, lng) = coords;
      final p = LatLng(lat, lng);

      _lastQuery = input;
      _applyLocation(p);
      await _moveCamera(p, zoom: 16);
      if (mounted) setState(() {});
      return;
    }

    // 2) lat,lng
    final reg = RegExp(r'(-?\d+(\.\d+)?)[ ,]+(-?\d+(\.\d+)?)');
    final m = reg.firstMatch(input);
    if (m != null) {
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(3)!);
      if (lat != null && lng != null) {
        final p = LatLng(lat, lng);
        _lastQuery = input;
        _applyLocation(p);
        await _moveCamera(p, zoom: 16);
        if (mounted) setState(() {});
        return;
      }
    }

    // 3) adresse texte => geocode
    if (input.length < 3) return;
    await _autoLocate(input);
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
      await _moveCamera(p, zoom: 16);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _applyLocation(LatLng p) {
    setState(() {
      _selected = p;
    });
  }

  Future<void> _onTap(LatLng p) async {
    _applyLocation(p);
    await _moveCamera(p, zoom: 16);
    if (mounted) setState(() {});
  }

  // ✅ camera robuste web mobile
  Future<void> _moveCamera(LatLng p, {double zoom = 16}) async {
    final mc = _mapController;
    if (mc == null) return;

    await Future.delayed(const Duration(milliseconds: 180));

    try {
      await mc.animateCamera(CameraUpdate.newLatLngZoom(p, zoom));
    } catch (_) {
      try {
        await mc.moveCamera(CameraUpdate.newLatLngZoom(p, zoom));
      } catch (_) {}
    }
  }

  void _save() {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Colle une adresse ou clique sur la map.")),
      );
      return;
    }

    Navigator.pop(
      context,
      LocationPickerResult(
        lat: _selected!.latitude,
        lng: _selected!.longitude,
        comment: commentCtrl.text.trim(),
        address: addressCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = _selected ?? fallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Choisir une localisation"),
        actions: [
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.check),
            tooltip: "Valider",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              // ✅ force rebuild (web mobile)
              key: ValueKey(
                "${target.latitude.toStringAsFixed(6)},${target.longitude.toStringAsFixed(6)}",
              ),
              initialCameraPosition: CameraPosition(
                target: target,
                zoom: _selected == null ? 10 : 16,
              ),
              onMapCreated: _onMapCreated,
              onTap: _onTap,
              markers: _markers,

              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              myLocationEnabled: false,
              compassEnabled: true,
            ),
          ),
        ],
      ),
    );
  }
}