import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:dash_master_toolkit/application/users/model/user_project_model.dart';
import 'package:dash_master_toolkit/services/user_project_service.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
class UserProjectsScreen extends StatefulWidget {
  final String token;

  const UserProjectsScreen({
    super.key,
    required this.token,
  });

  @override
  State<UserProjectsScreen> createState() => _UserProjectsScreenState();
}

class _UserProjectsScreenState extends State<UserProjectsScreen> {
  static const Color kPrimary = Color(0xFF1F6FEB);
  static const Color kBg = Color(0xFFF4F7FC);
  static const Color kCard = Colors.white;
  static const Color kBorder = Color(0xFFE5EAF2);
  static const Color kTextDark = Color(0xFF111827);
  static const Color kTextMuted = Color(0xFF6B7280);
  static const Color kSuccessBg = Color(0xFFDCFCE7);
  static const Color kSuccessText = Color(0xFF166534);
  static const Color kWarningBg = Color(0xFFFEF3C7);
  static const Color kWarningText = Color(0xFFB45309);
  static const Color kNeutralBg = Color(0xFFF3F4F6);
  static const Color kNeutralText = Color(0xFF6B7280);

  final UserProjectService service = UserProjectService(
    baseUrl: 'https://api.crmprobar.com',
  );

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _architectCtrl = TextEditingController();
  final TextEditingController _promoteurCtrl = TextEditingController();
  final TextEditingController _ingenieurCtrl = TextEditingController();
  final TextEditingController _societeCtrl = TextEditingController();
  final TextEditingController _createdByCtrl = TextEditingController();
 String? userRole;
String? selectedUser;
List<Map<String, dynamic>> users = [];
  bool _loading = false;
  String? _error;
  UserProjectsResponse? _response;

  int _page = 1;
  final int _limit = 10;

  @override
void initState() {
  super.initState();

  Map<String, dynamic> decoded = JwtDecoder.decode(widget.token);

  userRole = decoded["role"];

  print("ROLE CONNECTED: $userRole"); // 🔥 DEBUG

  _loadUsers();
  _loadProjects();
}
Future<void> _loadUsers() async {
  try {
    final response = await http.get(
      Uri.parse('${service.baseUrl}/users'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        final allUsers = List<Map<String, dynamic>>.from(data);

users = allUsers.where((u) {
  final role = (u['role'] ?? '').toString().toLowerCase();
  return role == "user"; // 🔥 ou "agent" selon ton système
}).toList();
      });
    }
  } catch (e) {
    print("Error loading users: $e");
  }
}
  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await service.fetchMyProjects(
        token: widget.token,
        architecte: _architectCtrl.text,
        promoteur: _promoteurCtrl.text,
        createdBy: selectedUser,
        ingenieur: _ingenieurCtrl.text,
        societe: _societeCtrl.text,
        q: _searchCtrl.text,
        page: _page,
        limit: _limit,
      );

      setState(() {
        _response = result;
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

  void _resetFilters() {
  _searchCtrl.clear();
  _architectCtrl.clear();
  _promoteurCtrl.clear();
  _ingenieurCtrl.clear();
  _societeCtrl.clear();

  selectedUser = null; // 🔥 IMPORTANT

  _page = 1;
  _loadProjects();
}

  void _exportCsv() {
    final items = _response?.items ?? [];

    final buffer = StringBuffer();
    buffer.writeln(
      'Project Name,Start Date,Engineer,Architect,Promoter,Company,Status,Validation Status,Project Type,Address',
    );

    for (final p in items) {
      buffer.writeln(
        '"${_escapeCsv(p.nomProjet)}",'
        '"${_escapeCsv(p.dateDemarrage)}",'
        '"${_escapeCsv(p.ingenieurResponsable)}",'
        '"${_escapeCsv(p.architecte ?? '')}",'
        '"${_escapeCsv(p.promoteur ?? '')}",'
        '"${_escapeCsv(p.entreprise)}",'
        '"${_escapeCsv(p.statut ?? '')}",'
        '"${_escapeCsv(p.validationStatut ?? '')}",'
        '"${_escapeCsv(p.typeProjet ?? '')}",'
        '"${_escapeCsv(p.adresse ?? '')}"',
      );
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'user_projects.csv')
      ..click();

    html.Url.revokeObjectUrl(url);
    anchor.remove();
  }

  String _escapeCsv(String value) {
    return value.replaceAll('"', '""');
  }

  Color _validationBg(String? value) {
    final v = (value ?? '').toLowerCase().trim();
    if (v == 'validé' || v == 'valid') return kSuccessBg;
    if (v == 'non validé' || v == 'not valid') return kWarningBg;
    return kNeutralBg;
  }

  Color _validationText(String? value) {
    final v = (value ?? '').toLowerCase().trim();
    if (v == 'validé' || v == 'valid') return kSuccessText;
    if (v == 'non validé' || v == 'not valid') return kWarningText;
    return kNeutralText;
  }

  Color _statusBg(String? value) {
    final v = (value ?? '').toLowerCase().trim();
    if (v == 'terminé' || v == 'completed') return kSuccessBg;
    if (v == 'préparation' || v == 'preparation') return const Color(0xFFEEF2FF);
    if (v == 'en cours' || v == 'in progress') return const Color(0xFFDBEAFE);
    return kNeutralBg;
  }

  Color _statusText(String? value) {
    final v = (value ?? '').toLowerCase().trim();
    if (v == 'terminé' || v == 'completed') return kSuccessText;
    if (v == 'préparation' || v == 'preparation') return const Color(0xFF4338CA);
    if (v == 'en cours' || v == 'in progress') return const Color(0xFF1D4ED8);
    return kNeutralText;
  }

  Widget _filterField({
    required TextEditingController controller,
    required String hint,
    double width = 220,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrimary, width: 1.4),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _architectCtrl.dispose();
    _promoteurCtrl.dispose();
    _ingenieurCtrl.dispose();
    _societeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _response?.items ?? [];
    final total = _response?.total ?? 0;
    final totalPages = _response?.totalPages ?? 1;

    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Projects',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: kTextDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'View your associated projects and filter them professionally by architect, promoter, engineer, and company.',
              style: TextStyle(
                fontSize: 15,
                color: kTextMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _SummaryCard(
                  title: 'Total Projects',
                  value: total.toString(),
                  icon: Icons.folder_copy_rounded,
                  color: kPrimary,
                ),
                _SummaryCard(
                  title: 'Current Page',
                  value: _page.toString(),
                  icon: Icons.layers_rounded,
                  color: const Color(0xFF0EA5E9),
                ),
                _SummaryCard(
                  title: 'Total Pages',
                  value: totalPages.toString(),
                  icon: Icons.auto_awesome_mosaic_rounded,
                  color: const Color(0xFF10B981),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _filterField(
                        controller: _searchCtrl,
                        hint: 'Search project...',
                        width: 280,
                      ),
                      _filterField(
                        controller: _architectCtrl,
                        hint: 'Architect',
                      ),
                      _filterField(
                        controller: _promoteurCtrl,
                        hint: 'Promoter',
                      ),
                      _filterField(
                        controller: _ingenieurCtrl,
                        hint: 'Engineer',
                      ),
                      _filterField(
                        controller: _societeCtrl,
                        hint: 'Company',
                      ),
                      if (userRole == "superadmin") 
  DropdownButtonFormField<String>(
    value: selectedUser,
    hint: const Text("Created By"),
    items: users.map<DropdownMenuItem<String>>((u) {
      return DropdownMenuItem<String>(
        value: u['id'].toString(),
        child: Text(u['email'] ?? ''),
      );
    }).toList(),
    onChanged: (value) {
      setState(() {
        selectedUser = value;
      });

      _page = 1;
      _loadProjects();
    },
  ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          _page = 1;
                          _loadProjects();
                        },
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Apply Filters'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTextDark,
                          side: const BorderSide(color: kBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: items.isEmpty ? null : _exportCsv,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Export CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              ),

            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            if (!_loading && _error == null)
              Container(
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: kBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, 14),
                      child: Row(
                        children: [
                          Icon(Icons.table_chart_rounded, color: kPrimary),
                          SizedBox(width: 10),
                          Text(
                            'Projects Table',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: kTextDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1, color: kBorder),

                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          'No projects found for the selected filters.',
                          style: TextStyle(
                            fontSize: 15,
                            color: kTextMuted,
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 58,
                          dataRowMinHeight: 64,
                          dataRowMaxHeight: 72,
                          columnSpacing: 28,
                          horizontalMargin: 20,
                          dividerThickness: 0.8,
                          headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                            (states) => const Color(0xFFF8FAFC),
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Project Name',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Engineer',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Architect',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Promoter',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Company',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Start Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Validation',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Project Type',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark,
                                ),
                              ),
                            ),
                          ],
                          rows: items.map((p) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(0xFFDBEAFE),
                                          child: Text(
                                            p.nomProjet.isNotEmpty
                                                ? p.nomProjet[0].toUpperCase()
                                                : 'P',
                                            style: const TextStyle(
                                              color: Color(0xFF1D4ED8),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            p.nomProjet,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: kTextDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(Text(p.ingenieurResponsable)),
                                DataCell(Text(p.architecte ?? '-')),
                                DataCell(Text(p.promoteur ?? '-')),
                                DataCell(Text(p.entreprise)),
                                DataCell(Text(p.dateDemarrage)),
                                DataCell(
                                  _TagChip(
                                    text: p.statut ?? 'No status',
                                    bg: _statusBg(p.statut),
                                    fg: _statusText(p.statut),
                                  ),
                                ),
                                DataCell(
                                  _TagChip(
                                    text: p.validationStatut ?? 'Unknown',
                                    bg: _validationBg(p.validationStatut),
                                    fg: _validationText(p.validationStatut),
                                  ),
                                ),
                                DataCell(
                                  _TagChip(
                                    text: p.typeProjet ?? 'No type',
                                    bg: const Color(0xFFF3F4F6),
                                    fg: const Color(0xFF374151),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                    const Divider(height: 1, thickness: 1, color: kBorder),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Text(
                            'Page $_page / $totalPages',
                            style: const TextStyle(
                              color: kTextMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            onPressed: _page > 1
                                ? () {
                                    setState(() {
                                      _page--;
                                    });
                                    _loadProjects();
                                  }
                                : null,
                            child: const Text('Previous'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _page < totalPages
                                ? () {
                                    setState(() {
                                      _page++;
                                    });
                                    _loadProjects();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _TagChip({
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}