import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/project_action_api.dart';
class AddProjectActionScreen extends StatefulWidget {

  final String projectId;

  const AddProjectActionScreen({required this.projectId});

  @override
  State<AddProjectActionScreen> createState() =>
      _AddProjectActionScreenState();
}

class _AddProjectActionScreenState
    extends State<AddProjectActionScreen> {

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

            ElevatedButton(

              child: const Text("Select Relance Date"),

              onPressed:()async{

                final d = await showDatePicker(

                  context:context,

                  firstDate:DateTime(2020),

                  lastDate:DateTime(2030),

                  initialDate:DateTime.now(),

                );

                if(d!=null){

                  setState(() {
                    relance=d;
                  });

                }

              },

            ),

            const SizedBox(height:30),

            ElevatedButton(

              child: const Text("Save"),

              onPressed:()async{

                await ProjectActionApi.instance.createAction(

                  projectId: widget.projectId,

                  type: type,

                  commentaire: commentaire.text,

                  dateRelance:
                  relance?.toIso8601String()

                );

                Get.back();

              },

            )

          ],

        ),

      ),

    );

  }

}