import 'package:flutter/material.dart';

/// Project edit form widget - Edit project name/description/status
///
/// Features:
/// - Name validation (required, 1-255 characters)
/// - Description field (optional)
/// - Status dropdown (active/inactive)
/// - Save/Cancel actions
/// - Loading state with disabled inputs
/// - Error message display
///
/// Usage:
/// ```dart
/// ProjectEditForm(
///   projectName: project.name,
///   projectDescription: project.description,
///   projectStatus: project.status,
///   onSave: (name, description, status) async {
///     await projectRepository.updateProject(
///       id: project.id,
///       name: name,
///       description: description,
///       status: status,
///     );
///   },
///   isLoading: false,
/// )
/// ```
class ProjectEditForm extends StatefulWidget {
  final String projectName;
  final String? projectDescription;
  final String? projectStatus;
  final Future<void> Function(String name, String? description, String? status) onSave;
  final VoidCallback? onCancel;
  final bool isLoading;
  final String? errorMessage;

  const ProjectEditForm({
    Key? key,
    required this.projectName,
    this.projectDescription,
    this.projectStatus,
    required this.onSave,
    this.onCancel,
    this.isLoading = false,
    this.errorMessage,
  }) : super(key: key);

  @override
  State<ProjectEditForm> createState() => _ProjectEditFormState();
}

class _ProjectEditFormState extends State<ProjectEditForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _selectedStatus;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.projectName);
    _descriptionController = TextEditingController(text: widget.projectDescription ?? '');
    _selectedStatus = widget.projectStatus ?? 'active';

    // Track changes
    _nameController.addListener(_checkForChanges);
    _descriptionController.addListener(_checkForChanges);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    final hasChanges = _nameController.text != widget.projectName ||
        _descriptionController.text != (widget.projectDescription ?? '') ||
        _selectedStatus != (widget.projectStatus ?? 'active');

    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      await widget.onSave(
        _nameController.text.trim(),
        _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        _selectedStatus,
      );
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Project name is required';
    }

    if (value.trim().length > 255) {
      return 'Project name must be 255 characters or less';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error message display
          if (widget.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Name field
          Text(
            'Project Name',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            enabled: !widget.isLoading,
            maxLength: 255,
            textInputAction: TextInputAction.next,
            validator: _validateName,
            decoration: InputDecoration(
              hintText: 'Enter project name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Description field
          Text(
            'Description (Optional)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            enabled: !widget.isLoading,
            maxLines: 4,
            maxLength: 1000,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Enter project description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Status dropdown
          Text(
            'Status',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            enabled: !widget.isLoading,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'active',
                child: Text('Active'),
              ),
              DropdownMenuItem(
                value: 'inactive',
                child: Text('Inactive'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedStatus = value;
                  _checkForChanges();
                });
              }
            },
          ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              // Cancel button
              if (widget.onCancel != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.isLoading ? null : widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (widget.onCancel != null) const SizedBox(width: 12),

              // Save button
              Expanded(
                child: ElevatedButton(
                  onPressed: (widget.isLoading || !_hasChanges) ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),

          // Unsaved changes indicator
          if (_hasChanges && !widget.isLoading) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You have unsaved changes',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
