import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dash_master_toolkit/providers/api_client.dart';
import 'package:dio/dio.dart' as dio;
class AddCommercialActionScreen extends StatefulWidget {
  final String contactId;
  final String? initialType;

  const AddCommercialActionScreen({
    super.key,
    required this.contactId,
    this.initialType,
  });

  @override
  State<AddCommercialActionScreen> createState() =>
      _AddCommercialActionScreenState();
}

class _AddCommercialActionScreenState
    extends State<AddCommercialActionScreen> {

  String type = "Visite";
  final commentaireCtrl = TextEditingController();
  DateTime? relanceDate;

  PlatformFile? selectedFile;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      type = widget.initialType!;
    }
  }

  /// PICK FILE
  Future pickFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        selectedFile = result.files.first;
      });
    }
  }

  /// SAVE ACTION
  Future submit() async {

    try {

     final formData = dio.FormData.fromMap({
  "typeAction": type,
  "commentaire": commentaireCtrl.text.trim(),

  if (relanceDate != null)
    "dateRelance": relanceDate!.toIso8601String(),

  if (selectedFile != null)
    "file": dio.MultipartFile.fromBytes(
      selectedFile!.bytes!, // ✅ web safe
      filename: selectedFile!.name,
    ),
});

await ApiClient.instance.dio.post(
  "/commercial-contacts/${widget.contactId}/actions",
  data: formData,
);
      Get.snackbar(
        "Success",
        "Action added",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Navigator.pop(context, true);

    } catch (e) {

      Get.snackbar(
        "Error",
        "Cannot add action",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// DATE PICKER
  Future pickDate() async {

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        relanceDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Add Commercial Action"),
      ),

      body: Padding(

        padding: const EdgeInsets.all(20),

        child: SingleChildScrollView(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              /// TYPE ACTION
              DropdownButtonFormField(

                value: type,

                items: const [
                  DropdownMenuItem(value: "Visite", child: Text("Visite")),
                  DropdownMenuItem(value: "Plan technique", child: Text("Plan technique")),
                  DropdownMenuItem(value: "Echantillonnage", child: Text("Echantillonnage")),
                  DropdownMenuItem(value: "Devis envoyé", child: Text("Devis envoyé")),
                  DropdownMenuItem(value: "Negociation", child: Text("Negociation")),
                  DropdownMenuItem(value: "Relance", child: Text("Relance")),
                  DropdownMenuItem(value: "Commande gagnée", child: Text("Commande gagnée")),
                  DropdownMenuItem(value: "Commande perdue", child: Text("Commande perdue")),
                ],

                onChanged: (v) {
                  setState(() => type = v.toString());
                },

                decoration: const InputDecoration(
                  labelText: "Action type",
                ),
              ),

              const SizedBox(height: 20),

              /// COMMENTAIRE
              TextField(
                controller: commentaireCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Comment",
                ),
              ),

              const SizedBox(height: 20),

              /// DATE RELANCE
              Row(
                children: [

                  Expanded(
                    child: Text(
                      relanceDate == null
                          ? "No follow-up date"
                          : relanceDate.toString().split(" ")[0],
                    ),
                  ),

                  ElevatedButton(
                    onPressed: pickDate,
                    child: const Text("Select date"),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// FILE
              Row(
                children: [

                  Expanded(
                    child: Text(
                      selectedFile == null
                          ? "No file selected"
                          : selectedFile!.name,
                    ),
                  ),

                  ElevatedButton(
                    onPressed: pickFile,
                    child: const Text("Upload"),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              /// SAVE
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(

                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),

                  onPressed: submit,

                  child: const Text("Save Action"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}