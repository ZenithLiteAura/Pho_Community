import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/storageform/smbform.dart';
import 'package:img_syncer/storageform/webdavform.dart';
import 'package:img_syncer/storageform/nfsform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/global.dart';

class StorageConfigPage extends StatefulWidget {
  const StorageConfigPage({Key? key}) : super(key: key);

  @override
  StorageConfigPageState createState() => StorageConfigPageState();
}

class StorageConfigPageState extends State<StorageConfigPage> {
  @protected
  Drive currentDrive = Drive.smb;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final drive = prefs.getString("drive");
      if (drive != null) {
        setState(() {
          currentDrive = getDrive(drive);
        });
      }
    });
  }

  Drive getDrive(String drive) {
    return driveName.entries
        .firstWhere((element) => element.value == drive,
            orElse: () => const MapEntry(Drive.smb, "SMB"))
        .key;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    late Widget form;
    switch (currentDrive) {
      case Drive.smb:
        form = const SMBForm();
        break;
      case Drive.webDav:
        form = const WebDavForm();
        break;
      case Drive.nfs:
        form = const NFSForm();
        break;
      default:
        form = const Text('Not implemented');
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.storageSetting,
          style: textTheme.headlineMedium?.copyWith(
            fontFamily: AppFonts.title, // Plus Jakarta Sans
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Storage type selection card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card), // squircle 24px
              ),
              color: colorScheme.surfaceContainerLowest, // surfacePrimary white
              elevation: 0,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.remoteStorageType,
                      style: textTheme.titleLarge?.copyWith(
                        fontFamily: AppFonts.body, // Inter
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Storage type dropdown
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: DropdownButtonFormField<Drive>(
                        value: currentDrive,
                        decoration: InputDecoration(
                          labelText: l10n.remoteStorageType,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.input),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 2,
                          ),
                        ),
                        items: driveName.entries.map((entry) {
                          return DropdownMenuItem<Drive>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              style: textTheme.bodyLarge?.copyWith(
                                fontFamily: AppFonts.body,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (Drive? newValue) {
                          if (newValue != null) {
                            setState(() {
                              currentDrive = newValue;
                            });
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setString("drive", driveName[newValue]!);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Storage configuration form card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card), // squircle 24px
              ),
              color: colorScheme.surfaceContainerLowest, // surfacePrimary white
              elevation: 0,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.storageSetting} - ${driveName[currentDrive]}',
                      style: textTheme.titleLarge?.copyWith(
                        fontFamily: AppFonts.body, // Inter
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    form,
                  ],
                ),
              ),
            ),
            
            // Dual WebDAV info card (if WebDAV is selected)
            if (currentDrive == Drive.webDav)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card), // squircle 24px
                ),
                color: colorScheme.surfaceContainerLowest, // surfacePrimary white
                elevation: 0,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.backup_outlined,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l10n.backupStorage,
                            style: textTheme.titleLarge?.copyWith(
                              fontFamily: AppFonts.body,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.backupStorageDesc,
                        style: textTheme.bodyMedium?.copyWith(
                          fontFamily: AppFonts.body,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Info card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card), // squircle 24px
              ),
              color: colorScheme.surfaceContainerLowest, // surfacePrimary white
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'About Storage',
                          style: textTheme.titleLarge?.copyWith(
                            fontFamily: AppFonts.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.storageLocationDesc,
                      style: textTheme.bodyMedium?.copyWith(
                        fontFamily: AppFonts.body,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}