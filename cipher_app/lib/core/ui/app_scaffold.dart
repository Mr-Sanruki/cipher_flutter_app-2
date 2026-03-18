import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final bool scroll;

  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.all(24),
    this.scroll = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: body,
    );

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: Center(
          child: scroll
              ? SingleChildScrollView(
                  padding: padding,
                  child: content,
                )
              : Padding(
                  padding: padding,
                  child: content,
                ),
        ),
      ),
    );
  }
}
