import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/lms_repository.dart';
import '../../models/app_user.dart';

class DeviceRequestDialog extends StatefulWidget {
  final AppUser user;

  const DeviceRequestDialog({super.key, required this.user});

  @override
  State<DeviceRequestDialog> createState() => _DeviceRequestDialogState();
}

class _DeviceRequestDialogState extends State<DeviceRequestDialog> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for changing your device.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final repo = Provider.of<LmsRepository>(context, listen: false);
    await repo.submitDeviceChangeRequest(user: widget.user, reason: reason);

    setState(() {
      _isSubmitting = false;
      _isSubmitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phonelink_lock,
                    color: Colors.orangeAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Device Transfer Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_isSubmitted) ...[
              Text(
                'Hello ${widget.user.name}, your account is bound to another registered device. You must request administrator approval to authorize this new device.',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason for Device Change:',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Purchased a new phone / Previous device lost or damaged...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Submit to Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withAlpha(80)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Device change request submitted successfully! An administrator will review and approve your request shortly.',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Close', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
