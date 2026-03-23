import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/project_action_api.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
class AddProjectActionScreen extends StatefulWidget {

  final String projectId;
final String initialType;
  const AddProjectActionScreen({
  required this.projectId,
  required this.initialType,
});

  @override
  State<AddProjectActionScreen> createState() =>
      _AddProjectActionScreenState();
}

class _AddProjectActionScreenState
    extends State<AddProjectActionScreen> {
      dynamic selectedFile;

  String type="Visite";

  final commentaire = TextEditingController();

  DateTime? relance;

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Add CRM Action"),
      ),

      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          children: [

            DropdownButtonFormField(

              value: type,

              items: const [

                DropdownMenuItem(
                    value:"Visite",
                    child: Text("Visite")),

                DropdownMenuItem(
                    value:"Plan technique",
                    child: Text("Plan technique")),

                DropdownMenuItem(
                    value:"Echantillonnage",
                    child: Text("Echantillonnage")),

                DropdownMenuItem(
                    value:"Negociation",
                    child: Text("Negociation")),

                DropdownMenuItem(
                    value:"Rappel",
                    child: Text("Rappel"))

              ],

              onChanged:(v){

                setState(() {
                  type=v!;
                });

              },

            ),

            const SizedBox(height:20),

            TextField(
              controller: commentaire,
              decoration: const InputDecoration(
                  labelText:"Commentaire"
              ),
            ),

            const SizedBox(height:20),

            ElevatedButton.icon(
  icon: const Icon(Icons.calendar_today),
  label: Text(
    relance == null
        ? "Select Relance Date"
        : "Relance : ${relance!.toLocal().toString().split(' ')[0]}",
  ),
  onPressed: () async {

    final d = await showDatePicker(

      context: context,

      firstDate: DateTime(2020),

      lastDate: DateTime(2030),

      initialDate: relance ?? DateTime.now(), // ✅ IMPORTANT

    );

    if (d != null) {

      setState(() {
        relance = d;
      });

    }
  },
),

            const SizedBox(height:30),
ElevatedButton.icon(
  icon: const Icon(Icons.attach_file),
  label: const Text("Upload Image / PDF"),
  onPressed: () async {

    final result = await FilePicker.platform.pickFiles();

if (result != null) {

  setState(() {

    if (kIsWeb) {
      selectedFile = result.files.first; // contient bytes
    } else {
      selectedFile = File(result.files.single.path!);
    }

  });
}
  },
),
            ElevatedButton(

              child: const Text("Save"),

              onPressed:()async{

                await ProjectActionApi.instance.createAction(

                  projectId: widget.projectId,

                  type: type,

                  commentaire: commentaire.text.trim(),

                dateRelance: relance != null
    ? "${relance!.year}-${relance!.month.toString().padLeft(2,'0')}-${relance!.day.toString().padLeft(2,'0')}"
    : null,
                  file: selectedFile, // ✅ IMPORTANT

                );

                Navigator.pop(context, true);

              },

            )

          ],

        ),

      ),

    );

  }

}