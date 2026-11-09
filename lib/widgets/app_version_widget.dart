// lib/widgets/app_version_widget.dart

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionWidget extends StatelessWidget {
  final Color? textColor;
  final double fontSize;

  const AppVersionWidget({
    Key? key,
    this.textColor,
    this.fontSize = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        String displayVersion = "v1.2.9"; // Fallback de secours
        
        if (snapshot.hasData) {
          final info = snapshot.data!;
          displayVersion = "v${info.version} (${info.buildNumber})";
        }

        return Text(
          "EasyLocation Enterprise • $displayVersion",
          style: TextStyle(
            color: textColor ?? Colors.white.withOpacity(0.7),
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}