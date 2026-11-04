import 'package:flutter/widgets.dart';

/// A [StreamBuilder] that subscribes once per [cacheKey] instead of on every
/// rebuild.
///
/// `StreamBuilder(stream: service.watchSomething(id))` written inside a
/// `build` method creates a new Firestore listener each time the parent
/// rebuilds: the list flashes its loading state and every document is read
/// again. Here the stream is created when the widget first appears and again
/// only when [cacheKey] changes (for example a different user or group id).
class KeyedStreamBuilder<T> extends StatefulWidget {
  final Object? cacheKey;
  final Stream<T> Function() create;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  const KeyedStreamBuilder({
    super.key,
    required this.cacheKey,
    required this.create,
    required this.builder,
    this.initialData,
  });

  @override
  State<KeyedStreamBuilder<T>> createState() => _KeyedStreamBuilderState<T>();
}

class _KeyedStreamBuilderState<T> extends State<KeyedStreamBuilder<T>> {
  late Stream<T> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.create();
  }

  @override
  void didUpdateWidget(KeyedStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) _stream = widget.create();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        stream: _stream,
        initialData: widget.initialData,
        builder: widget.builder,
      );
}
