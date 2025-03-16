import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/utils/toast/common.dart';
import 'package:anx_reader/widgets/settings/link_icon.dart';
import 'package:anx_reader/utils/check_update.dart';
import 'package:anx_reader/widgets/settings/show_donate_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:url_launcher/url_launcher.dart';

class About extends StatefulWidget {
  const About({
    super.key,
    this.leadingColor = false,
  });
  final bool leadingColor;

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> {
  String version = '';

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    final pubspecContent = await rootBundle.loadString('pubspec.yaml');
    final pubspec = Pubspec.parse(pubspecContent);
    setState(() {
      version = pubspec.version.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(L10n.of(context).app_about),
      leading: Icon(Icons.info_outline,
          color: widget.leadingColor
              ? Theme.of(context).colorScheme.primary
              : null),
      onTap: () => openAboutDialog(context),
    );
  }

  void openAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 500,
            minWidth: 300,
          ),
          child: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 5),
                    child: Center(
                      child: Text(
                        'Anx',
                        style: TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                      title: Text(L10n.of(context).app_version),
                      subtitle: Text(version +
                          (kDebugMode ? ' (debug)' : '')),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: version));
                        AnxToast.show(L10n.of(context).notes_page_copied);
                      }),
                  ListTile(
                      title: Text(L10n.of(context).about_check_for_updates),
                      onTap: () => checkUpdate(true)),
                  ListTile(
                    title: Text(L10n.of(context).app_donate),
                    onTap: () {
                      showDonateDialog(context);
                    },
                  ),
                  ListTile(
                    title: Text(L10n.of(context).app_license),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Anx',
                        applicationVersion: version,
                      );
                    },
                  ),
                  ListTile(
                    title: Text(L10n.of(context).app_author),
                    onTap: () {
                      launchUrl(
                        Uri.parse(
                            'https://github.com/Anxcye/anx-reader/graphs/contributors'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      linkIcon(
                          icon: IonIcons.logo_github,
                          url: 'https://github.com/Anxcye/anx-reader',
                          mode: LaunchMode.externalApplication),
                      linkIcon(
                          icon: Icons.telegram,
                          url: 'https://t.me/AnxReader',
                          mode: LaunchMode.externalApplication),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ));
      },
    );
  }
}
