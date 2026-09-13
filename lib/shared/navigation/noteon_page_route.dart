import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Subtle fade + slide page route used for secondary Noteon screens.
class NoteonPageRoute<T> extends PageRouteBuilder<T> {
  NoteonPageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AppMotion.normal,
          reverseTransitionDuration: AppMotion.fast,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppMotion.standard,
              reverseCurve: Curves.easeInCubic,
            );
            final isRtl = Directionality.of(context) == TextDirection.rtl;
            final beginDx = isRtl ? -0.04 : 0.04;
            final offset = Tween<Offset>(
              begin: Offset(beginDx, 0),
              end: Offset.zero,
            ).animate(curved);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(position: offset, child: child),
            );
          },
        );
}
