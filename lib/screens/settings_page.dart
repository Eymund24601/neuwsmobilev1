import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../repositories/settings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_image.dart';
import '../widgets/sign_in_required_view.dart';

const List<_CountryOption> _countryOptions = [
  _CountryOption(code: 'AT', name: 'Austria'),
  _CountryOption(code: 'BE', name: 'Belgium'),
  _CountryOption(code: 'BG', name: 'Bulgaria'),
  _CountryOption(code: 'CH', name: 'Switzerland'),
  _CountryOption(code: 'CY', name: 'Cyprus'),
  _CountryOption(code: 'CZ', name: 'Czechia'),
  _CountryOption(code: 'DE', name: 'Germany'),
  _CountryOption(code: 'DK', name: 'Denmark'),
  _CountryOption(code: 'EE', name: 'Estonia'),
  _CountryOption(code: 'ES', name: 'Spain'),
  _CountryOption(code: 'FI', name: 'Finland'),
  _CountryOption(code: 'FR', name: 'France'),
  _CountryOption(code: 'GB', name: 'United Kingdom'),
  _CountryOption(code: 'GR', name: 'Greece'),
  _CountryOption(code: 'HR', name: 'Croatia'),
  _CountryOption(code: 'HU', name: 'Hungary'),
  _CountryOption(code: 'IE', name: 'Ireland'),
  _CountryOption(code: 'IS', name: 'Iceland'),
  _CountryOption(code: 'IT', name: 'Italy'),
  _CountryOption(code: 'LT', name: 'Lithuania'),
  _CountryOption(code: 'LU', name: 'Luxembourg'),
  _CountryOption(code: 'LV', name: 'Latvia'),
  _CountryOption(code: 'MT', name: 'Malta'),
  _CountryOption(code: 'NL', name: 'Netherlands'),
  _CountryOption(code: 'NO', name: 'Norway'),
  _CountryOption(code: 'PL', name: 'Poland'),
  _CountryOption(code: 'PT', name: 'Portugal'),
  _CountryOption(code: 'RO', name: 'Romania'),
  _CountryOption(code: 'SE', name: 'Sweden'),
  _CountryOption(code: 'SI', name: 'Slovenia'),
  _CountryOption(code: 'SK', name: 'Slovakia'),
  _CountryOption(code: 'US', name: 'United States'),
];

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryCodeController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _wallpaperUrlController = TextEditingController();

  bool _savingSettings = false;
  bool _savingProfile = false;
  bool _uploadingAvatar = false;
  bool _uploadingWallpaper = false;
  bool _profileDraftInitialized = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _countryCodeController.dispose();
    _avatarUrlController.dispose();
    _wallpaperUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final useMockData = ref.watch(useMockDataProvider);
    final hasSession = ref.watch(hasSupabaseSessionProvider);
    final email = ref.watch(currentSupabaseUserEmailProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final profileAsync = ref.watch(profileProvider);

    if (settingsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load settings: ${settingsAsync.error}'),
          ),
        ),
      );
    }

    if (profileAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load profile: ${profileAsync.error}'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: (!useMockData && !hasSession)
          ? const SignInRequiredView(
              message: 'Sign in is required to manage settings.',
            )
          : (settingsAsync.valueOrNull == null ||
                profileAsync.valueOrNull == null)
          ? const Center(child: CircularProgressIndicator())
          : Builder(
              builder: (context) {
                final settings = settingsAsync.valueOrNull!;
                final profile = profileAsync.valueOrNull!;
                _initializeProfileDraft(profile);
                final avatarPreview = _avatarUrlController.text.trim().isEmpty
                    ? profile.avatarAsset
                    : _avatarUrlController.text.trim();
                final wallpaperPreview =
                    _wallpaperUrlController.text.trim().isEmpty
                    ? profile.wallpaperAsset
                    : _wallpaperUrlController.text.trim();
                final selectedCountryCode = _countryCodeController.text
                    .trim()
                    .toUpperCase();
                final selectedCountryValue =
                    _countryOptions.any(
                      (item) => item.code == selectedCountryCode,
                    )
                    ? selectedCountryCode
                    : null;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile details',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: 'Display name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _usernameController,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              helperText:
                                  '3-24 chars, letters/numbers/underscore',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _bioController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cityController,
                                  decoration: const InputDecoration(
                                    labelText: 'City',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 170,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedCountryValue,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Country',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _countryOptions
                                      .map(
                                        (item) => DropdownMenuItem<String>(
                                          value: item.code,
                                          child: Text(
                                            '${item.name} (${item.code})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _countryCodeController.text = value ?? '';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed:
                                  (_savingProfile ||
                                      _uploadingAvatar ||
                                      _uploadingWallpaper)
                                  ? null
                                  : _saveProfile,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                _savingProfile ? 'Saving...' : 'Save profile',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile images',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Avatar preview',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.muted),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: ClipOval(
                              child: AdaptiveImage(
                                source: avatarPreview,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _avatarUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Avatar image URL',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed:
                                  (_savingProfile ||
                                      _uploadingAvatar ||
                                      _uploadingWallpaper)
                                  ? null
                                  : () => _pickAndUploadImage(isAvatar: true),
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(
                                _uploadingAvatar
                                    ? 'Uploading...'
                                    : 'Upload avatar image',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Wallpaper preview',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.muted),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AdaptiveImage(
                              source: wallpaperPreview,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _wallpaperUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Wallpaper image URL',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed:
                                  (_savingProfile ||
                                      _uploadingAvatar ||
                                      _uploadingWallpaper)
                                  ? null
                                  : () => _pickAndUploadImage(isAvatar: false),
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(
                                _uploadingWallpaper
                                    ? 'Uploading...'
                                    : 'Upload wallpaper image',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.language),
                        title: const Text('Reading language'),
                        subtitle: Text(settings.readingLanguage),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => _saveSettings(
                            settings.copyWith(readingLanguage: value),
                          ),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'English',
                              child: Text('English'),
                            ),
                            PopupMenuItem(
                              value: 'French',
                              child: Text('French'),
                            ),
                            PopupMenuItem(
                              value: 'German',
                              child: Text('German'),
                            ),
                            PopupMenuItem(
                              value: 'Swedish',
                              child: Text('Swedish'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: SwitchListTile(
                        value: settings.notificationsEnabled,
                        onChanged: _savingSettings
                            ? null
                            : (value) {
                                _saveSettings(
                                  settings.copyWith(
                                    notificationsEnabled: value,
                                  ),
                                );
                              },
                        title: const Text('Notifications'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: SwitchListTile(
                        value: settings.offlineModeEnabled,
                        onChanged: _savingSettings
                            ? null
                            : (value) {
                                _saveSettings(
                                  settings.copyWith(offlineModeEnabled: value),
                                );
                              },
                        title: const Text('Offline mode'),
                      ),
                    ),
                    if (_savingSettings) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (!useMockData && hasSession) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: palette.surfaceCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: palette.border),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Sign out'),
                          subtitle: Text(
                            email.isEmpty ? 'Current Supabase session' : email,
                          ),
                          onTap: _savingSettings || _savingProfile
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await Supabase.instance.client.auth.signOut();
                                  if (!mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Signed out successfully.'),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  void _initializeProfileDraft(dynamic profile) {
    if (_profileDraftInitialized) {
      return;
    }
    _displayNameController.text = profile.displayName;
    _usernameController.text = profile.username;
    _bioController.text = profile.bio;
    _cityController.text = profile.city;
    _countryCodeController.text = profile.countryCode;
    _avatarUrlController.text = profile.avatarAsset;
    _wallpaperUrlController.text = profile.wallpaperAsset;
    _profileDraftInitialized = true;
  }

  Future<void> _saveSettings(AppSettings next) async {
    setState(() => _savingSettings = true);
    try {
      await ref.read(settingsProvider.notifier).save(next);
    } finally {
      if (mounted) {
        setState(() => _savingSettings = false);
      }
    }
  }

  Future<void> _saveProfile({String? successMessage}) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = _client.auth.currentUser;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You must be signed in to save profile.')),
      );
      return;
    }

    final displayName = _displayNameController.text.trim().isEmpty
        ? 'nEUws User'
        : _displayNameController.text.trim();
    final normalizedUsername = _normalizeUsername(_usernameController.text);
    if (normalizedUsername.length < 3 || normalizedUsername.length > 24) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Username must be 3-24 chars after normalization.'),
        ),
      );
      return;
    }

    setState(() => _savingProfile = true);
    try {
      var email = user.email?.trim().toLowerCase() ?? '';
      if (email.isEmpty) {
        final existing = await _client
            .from('profiles')
            .select('email')
            .eq('id', user.id)
            .maybeSingle();
        if (existing is Map<String, dynamic>) {
          final existingEmail = existing['email'];
          if (existingEmail is String) {
            email = existingEmail.trim().toLowerCase();
          }
        }
      }
      if (email.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not save profile: account email is missing.'),
          ),
        );
        return;
      }

      final payload = <String, dynamic>{
        'id': user.id,
        'email': email,
        'display_name': displayName,
        'username': normalizedUsername,
        'bio': _nullIfEmpty(_bioController.text),
        'city': _nullIfEmpty(_cityController.text),
        'country_code': _countryCodeController.text.trim().toUpperCase(),
        'avatar_url': _nullIfEmpty(_avatarUrlController.text),
        'wallpaper_url': _nullIfEmpty(_wallpaperUrlController.text),
      };

      if ((payload['country_code'] as String).isEmpty) {
        payload.remove('country_code');
      }

      await _client.from('profiles').upsert(payload, onConflict: 'id');
      await ref.read(profileProvider.notifier).refresh();
      await ref.read(messageThreadsProvider.notifier).refresh();
      await ref.read(messageContactsProvider.notifier).refresh();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(successMessage ?? 'Profile updated.')),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not save profile: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not save profile: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  Future<void> _pickAndUploadImage({required bool isAvatar}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      if (isAvatar) {
        _uploadingAvatar = true;
      } else {
        _uploadingWallpaper = true;
      }
    });

    try {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (file == null || file.files.isEmpty) {
        return;
      }
      final selected = file.files.first;
      final bytes = selected.bytes;
      if (bytes == null) {
        throw Exception('Selected file has no binary data.');
      }

      final extension = (selected.extension ?? 'jpg').toLowerCase();
      final folder = isAvatar ? 'avatars' : 'wallpapers';
      final objectPath =
          'users/${user.id}/$folder/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await _client.storage
          .from('public-media')
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFromExt(extension),
            ),
          );

      final publicUrl = _client.storage
          .from('public-media')
          .getPublicUrl(objectPath);
      if (isAvatar) {
        _avatarUrlController.text = publicUrl;
      } else {
        _wallpaperUrlController.text = publicUrl;
      }

      await _saveProfile(
        successMessage: isAvatar ? 'Avatar updated.' : 'Wallpaper updated.',
      );
    } on StorageException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image upload failed: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isAvatar) {
            _uploadingAvatar = false;
          } else {
            _uploadingWallpaper = false;
          }
        });
      }
    }
  }

  String _normalizeUsername(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return '';
    }
    final normalized = lower.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final squashed = normalized.replaceAll(RegExp(r'_+'), '_');
    return squashed.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }
}

class _CountryOption {
  const _CountryOption({required this.code, required this.name});

  final String code;
  final String name;
}
