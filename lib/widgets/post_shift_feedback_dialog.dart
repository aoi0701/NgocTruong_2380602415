import 'package:flutter/material.dart';
import '../services/attendance_service.dart';

Future<void> showPostShiftFeedbackDialog({
  required BuildContext context,
  required int recordId,
  VoidCallback? onSubmitted,
}) async {
  const moods = [
    {'emoji': '😄', 'label': 'Rất tốt'},
    {'emoji': '🙂', 'label': 'Ổn'},
    {'emoji': '😐', 'label': 'Bình thường'},
    {'emoji': '😓', 'label': 'Mệt'},
    {'emoji': '😞', 'label': 'Không vui'},
  ];

  String? selectedMood;
  final notesController = TextEditingController();
  bool isSubmitting = false;
  String? validationError;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cảm nhận sau ca làm',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(height: 4),
                Text(
                  'Hôm nay bạn cảm thấy thế nào?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn một cảm nhận:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: moods.map((m) {
                      final moodString = '${m['emoji']} ${m['label']}';
                      final isSelected = selectedMood == moodString;
                      return ChoiceChip(
                        avatar: Text(m['emoji']!, style: const TextStyle(fontSize: 16)),
                        label: Text(m['label']!),
                        selected: isSelected,
                        selectedColor: Colors.teal.withValues(alpha: 0.25),
                        onSelected: (val) {
                          setDialogState(() {
                            selectedMood = val ? moodString : null;
                            validationError = null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      validationError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Ghi chú thêm (không bắt buộc)',
                      hintText: 'Ví dụ: Ca hôm nay đông khách...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        Navigator.pop(dialogCtx);
                      },
                child: const Text('Bỏ qua'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (selectedMood == null) {
                          setDialogState(() {
                            validationError = 'Vui lòng chọn một cảm nhận trước khi gửi.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          validationError = null;
                        });

                        try {
                          final res = await AttendanceService.instance.submitFeedback(
                            recordId: recordId,
                            mood: selectedMood!,
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          );

                          if (res.success) {
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(res.message)),
                                    ],
                                  ),
                                  backgroundColor: Colors.green[700],
                                ),
                              );
                            }
                            onSubmitted?.call();
                          } else {
                            setDialogState(() {
                              isSubmitting = false;
                              validationError = res.message;
                            });
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            validationError = 'Lỗi kết nối máy chủ: $e';
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Gửi'),
              ),
            ],
          );
        },
      );
    },
  );
}
