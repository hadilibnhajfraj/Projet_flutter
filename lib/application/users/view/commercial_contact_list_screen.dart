import 'package:flutter/material.dart';
import '../model/commercial_contact_model.dart';
import 'package:dash_master_toolkit/services/commercial_contact_service.dart';

class CommercialContactListScreen extends StatefulWidget {
  final String token;

  const CommercialContactListScreen({
    super.key,
    required this.token,
  });

  @override
  State<CommercialContactListScreen> createState() =>
      _CommercialContactListScreenState();
}

class _CommercialContactListScreenState
    extends State<CommercialContactListScreen> {
  final CommercialContactService _service = CommercialContactService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<CommercialContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts({String? query}) async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final data = await _service.fetchMyContacts(
        token: widget.token,
        query: query,
      );

      setState(() {
        _contacts = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Color _typeBgColor(String type) {
    switch (type.toLowerCase()) {
      case 'tuteur':
        return const Color(0xFFE8F1FF);
      case 'cloture':
        return const Color(0xFFEAFBF0);
      default:
        return const Color(0xFFF2F4F7);
    }
  }

  Color _typeTextColor(String type) {
    switch (type.toLowerCase()) {
      case 'tuteur':
        return const Color(0xFF1D4ED8);
      case 'cloture':
        return const Color(0xFF15803D);
      default:
        return const Color(0xFF475467);
    }
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _typeBgColor(type),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.isEmpty ? 'N/A' : type,
        style: TextStyle(
          color: _typeTextColor(type),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProductsCell(List<dynamic> produits) {
    if (produits.isEmpty) {
      return const Text(
        'No products',
        overflow: TextOverflow.ellipsis,
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: produits.take(3).map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Text(
            '${p.produit} (${p.qte})',
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE4E7EC)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_center_outlined, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Commercial Contacts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_contacts.length} records',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 28,
                headingRowHeight: 56,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 90,
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF101828),
                  fontSize: 13,
                ),
                columns: const [
                  DataColumn(label: Text('Full Name')),
                  DataColumn(label: Text('Company')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Client Type')),
                  DataColumn(label: Text('Products')),
                  DataColumn(label: Text('Message')),
                ],
                rows: _contacts.map((contact) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFEAF2FF),
                              child: Text(
                                contact.nom.isNotEmpty
                                    ? contact.nom[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                '${contact.nom} ${contact.prenom}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            (contact.nomSociete ?? '').trim().isNotEmpty
                                ? contact.nomSociete!
                                : 'N/A',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Text(
                            contact.telephone,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            (contact.localisation ?? '').trim().isNotEmpty
                                ? contact.localisation!
                                : 'N/A',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(_buildTypeBadge(contact.typeClient)),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: _buildProductsCell(contact.produits),
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            (contact.message ?? '').trim().isNotEmpty
                                ? contact.message!
                                : '-',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, company, phone or location...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                ),
              ),
              onSubmitted: (value) => _loadContacts(query: value),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _loadContacts(query: _searchController.text),
            icon: const Icon(Icons.search),
            label: const Text('Search'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () {
              _searchController.clear();
              _loadContacts();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDA4AF)),
          ),
          child: Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFB42318),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined, size: 54, color: Color(0xFF98A2B3)),
              SizedBox(height: 12),
              Text(
                'No commercial contacts found.',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try changing your search criteria or add new contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadContacts(query: _searchController.text),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSearchBar(),
          const SizedBox(height: 18),
          _buildTable(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Commercial Contacts'),
        centerTitle: false,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }
}