import 'package:flutter/material.dart';
import 'package:img_syncer/desktop/settings_route.dart';

import 'package:img_syncer/gallery_body.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/state_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({Key? key}) : super(key: key);

  @override
  _DesktopHomePageState createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  int selectedIndex = 0;

  Widget body() {
    return IndexedStack(
      index: selectedIndex,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          return GalleryBody(
            useLocal: false,
            showAppBar: false,
            width: constraints.maxWidth,
          );
        }),
        const SettingRoute(),
      ],
    );
  }

  bool _isRefreshing = false;
  Future<void> refresh() async {
    if (stateModel.isDownloading() || stateModel.isUploading()) {
      return;
    }
    if (_isRefreshing) {
      return;
    }
    _isRefreshing = true;
    assetModel.refreshRemote(false);
    _isRefreshing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(82),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(25, 10, 10, 10),
            child: Row(
              children: [
                Container(
                  child: Image.asset(
                    'assets/icon/pho_icon.png',
                    width: 40,
                    height: 40,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Pho",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFamily: "Sriracha-Regular",
                      ),
                ),
                if (selectedIndex == 0)
                  Expanded(
                    child: Consumer<SettingModel>(
                        builder: (context, settingModel, child) => Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh_outlined),
                                  onPressed: refresh,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.grid_view),
                                  onPressed: settingModel.galleryColumCount > 4
                                      ? () async {
                                          settingModel.setGalleryColumCount(
                                              settingModel.galleryColumCount -
                                                  1);
                                          final prefs = await SharedPreferences
                                              .getInstance();
                                          await prefs.setInt(
                                              "galleryColumCount",
                                              settingModel.galleryColumCount);
                                        }
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.view_compact_outlined),
                                  onPressed: settingModel.galleryColumCount < 20
                                      ? () async {
                                          settingModel.setGalleryColumCount(
                                              settingModel.galleryColumCount +
                                                  1);
                                          final prefs = await SharedPreferences
                                              .getInstance();
                                          await prefs.setInt(
                                              "galleryColumCount",
                                              settingModel.galleryColumCount);
                                        }
                                      : null,
                                ),
                              ],
                            )),
                  ),
              ],
            ),
          ),
          const Divider(
              thickness: 1,
              height: 5),
        ]),
      ),
      body: Row(
        children: [
          Container(
            // width: 250,
            child: NavigationRail(
              selectedIndex: selectedIndex,
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.cloud_outlined),
                  label: Text(l10n.cloud),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(l10n.settings),
                ),
              ],
              onDestinationSelected: (value) {
                setState(() {
                  selectedIndex = value;
                });
              },
            ),
          ),
          Expanded(
            child: body(),
          ),
        ],
      ),
    );
  }
}
