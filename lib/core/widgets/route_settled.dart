import 'package:flutter/widgets.dart';

/// Tells a page when its route has finished animating in.
///
/// [routeSettled] is false while the page is still sliding in and becomes
/// true (with a rebuild) once the transition completes. Pages use it to hold
/// back their heavy parts — charts, long lists, Firestore queries — and show a
/// loading state instead. Building those in the same frames as the slide is
/// what makes a page transition stutter on mid-range phones.
mixin RouteSettledMixin<T extends StatefulWidget> on State<T> {
  Animation<double>? _routeAnimation;
  bool _routeSettled = false;

  bool get routeSettled => _routeSettled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSettled) return;
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = animation;
    if (animation == null || animation.isCompleted) {
      _routeSettled = true;
    } else {
      animation.addStatusListener(_onRouteStatus);
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    if (mounted) setState(() => _routeSettled = true);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    super.dispose();
  }
}
