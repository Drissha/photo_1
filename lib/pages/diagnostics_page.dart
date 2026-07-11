import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/diagnostic_service.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  Map<String, dynamic> _diagnostics = const {};

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    final diagnostics = await context.read<DiagnosticService>().collectDiagnostics();
    setState(() => _diagnostics = diagnostics);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Diagnostics', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  ..._diagnostics.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 180, child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(child: Text(entry.value.toString())),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadDiagnostics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Diagnostics'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
