import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/form_input_field.dart';
import '../../providers/booking_provider.dart';
import '../../widgets/upload_profile_widget.dart';
import 'step_header.dart';

/// Step 3 — collect and validate the client's contact details.
///
/// The [formKey] is owned by the parent flow so the "Next" button can trigger
/// validation before advancing.
class ClientInfoStep extends StatefulWidget {
  const ClientInfoStep({super.key, required this.formKey});

  final GlobalKey<FormState> formKey;

  @override
  State<ClientInfoStep> createState() => _ClientInfoStepState();
}

class _ClientInfoStepState extends State<ClientInfoStep> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _facebook;

  @override
  void initState() {
    super.initState();
    // Seed controllers from the provider so values persist across navigation.
    final client = context.read<BookingProvider>().clientInfo;
    _name = TextEditingController(text: client.fullName);
    _email = TextEditingController(text: client.email);
    _phone = TextEditingController(text: client.phone);
    _facebook = TextEditingController(text: client.facebook);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _facebook.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<BookingProvider>();

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            title: 'Your information',
            subtitle: 'Tell us how to reach you about your appointment.',
          ),
          const SizedBox(height: AppSpacing.xl),
          FormInputField(
            label: 'Full name',
            hint: 'Jane Dela Cruz',
            controller: _name,
            icon: Icons.person_outline_rounded,
            isRequired: true,
            keyboardType: TextInputType.name,
            validator: Validators.name,
            onChanged: (v) => provider.updateClientInfo(fullName: v),
          ),
          const SizedBox(height: AppSpacing.lg),
          FormInputField(
            label: 'Email address',
            hint: 'jane@email.com',
            controller: _email,
            icon: Icons.mail_outline_rounded,
            isRequired: true,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            onChanged: (v) => provider.updateClientInfo(email: v),
          ),
          const SizedBox(height: AppSpacing.lg),
          FormInputField(
            label: 'Phone number',
            hint: '0917 123 4567',
            controller: _phone,
            icon: Icons.phone_outlined,
            isRequired: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
            ],
            validator: Validators.phone,
            onChanged: (v) => provider.updateClientInfo(phone: v),
          ),
          const SizedBox(height: AppSpacing.lg),
          FormInputField(
            label: 'Facebook profile',
            hint: 'facebook.com/yourprofile',
            controller: _facebook,
            icon: Icons.facebook_rounded,
            isRequired: true,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            validator: Validators.facebook,
            onChanged: (v) => provider.updateClientInfo(facebook: v),
          ),
          const SizedBox(height: AppSpacing.xl),
          Selector<BookingProvider, String?>(
            selector: (_, p) => p.clientInfo.photoPath,
            builder: (context, photoPath, _) {
              return UploadProfileWidget(
                photoPath: photoPath,
                onPhotoSelected: (path) => provider.setPhoto(path),
                onPhotoRemoved: () => provider.setPhoto(null),
              );
            },
          ),
        ],
      ),
    );
  }
}
