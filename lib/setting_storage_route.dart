import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/storageform/smbform.dart';
import 'package:img_syncer/storageform/webdavform.dart';
import 'package:img_syncer/storageform/nfsform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/global.dart';

class SettingStorageRoute extends StatefulWidget {
  const SettingStorageRoute({Key? key}) : super(key: key);

  @override
  _SettingStorageRouteState createState() => _SettingStorageRouteState();
}

class _SettingStorageRouteState extends State<SettingStorageRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageSetting),
      ),
      body: const SettingStorageRouteBody(),
    );
  }
}

class SettingStorageRouteBody extends StatefulWidget {
  const SettingStorageRouteBody({Key? key}) : super(key: key);

  @override
  SettingStorageRouteBodyState createState() => SettingStorageRouteBodyState();
}

Drive getDrive(String drive) {
  return driveName.entries
      .firstWhere((element) => element.value == drive,
          orElse: () => const MapEntry(Drive.smb, "SMB"))
      .key;
}

class SettingStorageRouteBodyState extends State<SettingStorageRouteBody> {
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

  @override
  Widget build(BuildContext context) {
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
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingLarge,
                vertical: AppSpacing.paddingSmall),
            child: TextField(
              readOnly: true,
              controller: TextEditingController(
                  text: driveName[currentDrive]),
              decoration: InputDecoration(
                  labelText: l10n.remoteStorageType,
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    itemBuilder: (BuildContext context) {
                      return driveName.values
                          .map((String value) => PopupMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ))
                          .toList();
                    },
                    onSelected: (String value) => setState(() {
                      currentDrive = getDrive(value);
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setString("drive", value);
                      });
                    }),
                  )),
            ),
          ),
          const Divider(height: 15),
          form,
        ],
      ),
    );
  }
}
