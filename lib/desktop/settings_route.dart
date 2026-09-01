import 'package:flutter/material.dart';

import 'package:img_syncer/global.dart';
import 'package:img_syncer/storage_config_page.dart';

class SettingRoute extends StatefulWidget {
  const SettingRoute({Key? key}) : super(key: key);

  @override
  _SettingRouteState createState() => _SettingRouteState();
}

class _SettingRouteState extends State<SettingRoute> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
          child: Row(
            children: [
              Text(l10n.settings, style: Theme.of(context).textTheme.titleLarge)
            ],
          ),
        ),
        const Divider(height: 5),
        Expanded(
          child: SizedBox(
            width: 500,
            child: ListView(
              children: [
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(l10n.storageSetting,
                      style: Theme.of(context).textTheme.titleLarge),
                  subtitle: Text(l10n.desktopStorageSettingDesc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => const Dialog(
                      child: SizedBox(
                        width: 500,
                        child: StorageConfigPage(),
                      ),
                    ),
                  ),
                ),
                
                // const Divider(height: 10),
                // ListTile(
                //   leading: const Icon(Icons.info),
                //   title: Text(l10n.about, style: const TextStyle(fontSize: 18)),
                //   onTap: () => showDialog(
                //     context: context,
                //     builder: (context) => const Dialog(
                //       child: SizedBox(
                //         width: 500,
                //         child: AboutRoute(),
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
