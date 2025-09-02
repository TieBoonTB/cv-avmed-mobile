import 'package:flutter/material.dart';

class PretestSurveyWidget extends StatefulWidget {
  final bool shouldCheckIn;
  final Function(Map<String, dynamic>) onSurveySubmit;

  const PretestSurveyWidget({
    super.key,
    required this.shouldCheckIn,
    required this.onSurveySubmit,
  });

  @override
  PretestSurveyWidgetState createState() => PretestSurveyWidgetState();
}

class PretestSurveyWidgetState extends State<PretestSurveyWidget> {
  final _patientCodeController = TextEditingController();
  bool _isFeelingWell = false;
  bool _hasAdverseRxn = false;

  void _submitSurvey() {
    final survey = {
      'patientCode': _patientCodeController.text,
      'checkIn': widget.shouldCheckIn
          ? {
              'isFeelingWell': _isFeelingWell,
              'hasAdverseRxn': _hasAdverseRxn,
            }
          : null,
    };

    widget.onSurveySubmit(survey);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pre-test Survey',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFA855F7), // Purple
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Patient Code Input
          TextField(
            controller: _patientCodeController,
            style: TextStyle(color: Color(0xFF1F2937)), // Dark gray
            decoration: InputDecoration(
              labelText: 'Patient Code',
              labelStyle: TextStyle(color: Color(0xFF6B7280)), // Medium gray
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFFA855F7).withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFA855F7).withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFA855F7), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          
          if (widget.shouldCheckIn) ...[
            const SizedBox(height: 20),
            
            // Check-in questions
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC), // Very light gray
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFA855F7).withValues(alpha: 0.2)),
              ),
              child: CheckboxListTile(
                title: Text(
                  'Are you feeling well today?',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _isFeelingWell,
                onChanged: (value) => setState(() => _isFeelingWell = value!),
                activeColor: Color(0xFFA855F7), // Purple
                checkColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            
            const SizedBox(height: 12),
            
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC), // Very light gray
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFA855F7).withValues(alpha: 0.2)),
              ),
              child: CheckboxListTile(
                title: Text(
                  'Have you experienced any adverse reactions?',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: _hasAdverseRxn,
                onChanged: (value) => setState(() => _hasAdverseRxn = value!),
                activeColor: Color(0xFFA855F7), // Purple
                checkColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitSurvey,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFA855F7), // Purple
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: Color(0xFFA855F7).withValues(alpha: 0.3),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _patientCodeController.dispose();
    super.dispose();
  }
}
