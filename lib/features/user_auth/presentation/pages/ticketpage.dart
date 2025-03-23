import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'dart:io';

class MyTicketsPage extends StatefulWidget {
  const MyTicketsPage({super.key});

  @override
  State<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends State<MyTicketsPage> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Tickets 🎟️"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('weekend_passes')
            .where('user_id', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No tickets found!",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          var tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              var ticket = tickets[index].data() as Map<String, dynamic>?;

              if (ticket == null) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ticket['role'] == 'student' &&
                          (ticket['student_id'] ?? '').isNotEmpty) ...[
                        _infoRow("Student ID", ticket['student_id'] ?? 'N/A'),
                        _infoRow(
                            "Student Name", ticket['student_name'] ?? 'N/A'),
                      ],
                      if (ticket['role'] == 'staff' &&
                          (ticket['staff_name'] ?? '').isNotEmpty) ...[
                        _infoRow("Staff Name", ticket['staff_name'] ?? 'N/A'),
                        _infoRow("Position", ticket['position'] ?? 'N/A'),
                      ],
                      _infoRow("Pass ID", ticket['pass_id'] ?? 'N/A'),
                      _infoRow("Bus No", ticket['bus_no'] ?? 'N/A'),
                      _infoRow(
                          "From Date", _formatDate(ticket['from_date'] ?? '')),
                      _infoRow("To Date", _formatDate(ticket['to_date'] ?? '')),
                      _infoRow("Amount Paid", "₹150"),
                      const SizedBox(height: 8),
                      _statusIndicator(
                          ticket['from_date'] ?? '', ticket['to_date'] ?? ''),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.download, color: Colors.blue),
                        label: const Text(
                          "Download PDF",
                          style: TextStyle(color: Colors.blue),
                        ),
                        onPressed: () =>
                            _downloadTicketAsPDF(ticket, tickets[index].id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return "N/A";
    try {
      DateTime parsedDate = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(parsedDate);
    } catch (e) {
      return "Invalid Date";
    }
  }

  Widget _statusIndicator(String fromDate, String toDate) {
    DateTime now = DateTime.now();
    DateTime from = DateTime.parse(fromDate);
    DateTime to = DateTime.parse(toDate);

    if (now.isBefore(from)) {
      return const Text("Pass Not Active",
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold));
    } else if (now.isAfter(to)) {
      return const Text("Pass Expired",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
    } else {
      return const Text("Pass Active",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
    }
  }

  Future<void> _downloadTicketAsPDF(
      Map<String, dynamic> ticket, String passId) async {
    try {
      // Check and Request Permission Before Download
      if (!await _requestStoragePermission()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Storage permission denied!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create a new PDF document
      final pdf = pw.Document();

      // Add a page to the PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "BusHopper Ticket",
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  if (ticket['role'] == 'student' &&
                      (ticket['student_id'] ?? '').isNotEmpty) ...[
                    _boldInfoRow("Student ID", ticket['student_id'] ?? 'N/A', 18),
                    _boldInfoRow(
                        "Student Name", ticket['student_name'] ?? 'N/A', 18),
                  ],
                  if (ticket['role'] == 'staff' &&
                      (ticket['staff_name'] ?? '').isNotEmpty) ...[
                    _boldInfoRow("Staff Name", ticket['staff_name'] ?? 'N/A', 18),
                    _boldInfoRow("Position", ticket['position'] ?? 'N/A', 18),
                  ],
                  _boldInfoRow("Pass ID", ticket['pass_id'] ?? 'N/A', 18),
                  _boldInfoRow("Bus No", ticket['bus_no'] ?? 'N/A', 14),
                  _boldInfoRow(
                      "From Date", _formatDateForPdf(ticket['from_date'] ?? ''), 14),
                  _boldInfoRow(
                      "To Date", _formatDateForPdf(ticket['to_date'] ?? ''), 14),
                  _boldInfoRow("Amount Paid", "₹150", 14),
                  pw.SizedBox(height: 25),
                  pw.Center(
                    child: pw.Text(
                      "Generated on ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}",
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Save PDF to Documents/BusHopper
      final directory = Directory('/storage/emulated/0/Documents/BusHopper');
      if (!(await directory.exists())) {
        await directory.create(recursive: true);
      }

      final file = File("${directory.path}/ticket_$passId.pdf");
      await file.writeAsBytes(await pdf.save());

      // Open PDF after Saving
      OpenFile.open(file.path);

      // Show Success Message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ticket saved to ${file.path}"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("❌ Error downloading PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateForPdf(String date) {
    if (date.isEmpty) return "N/A";
    try {
      DateTime parsedDate = DateTime.parse(date);
      return DateFormat('MMM dd, yyyy').format(parsedDate);
    } catch (e) {
      return "Invalid Date";
    }
  }

  pw.Widget _boldInfoRow(String label, String value, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      return true;
    }

    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    return false;
  }
}
