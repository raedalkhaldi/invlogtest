import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return AppBar(
      title: Text(title),
      centerTitle: true,
      elevation: 2,
      actions: [
        // Theme toggle button
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: Theme.of(context).appBarTheme.foregroundColor,
              ),
              onPressed: () {
                themeProvider.toggleTheme();
              },
              tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            ),
          ),
        ),
        // Additional actions if provided
        if (actions != null) ...actions!,
      ],
    );
  }
} 