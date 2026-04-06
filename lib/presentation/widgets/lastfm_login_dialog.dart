import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LastFmLoginDialog extends StatefulWidget {
  final Function(String username, String password) onLogin;

  const LastFmLoginDialog({
    super.key,
    required this.onLogin,
  });

  @override
  State<LastFmLoginDialog> createState() => _LastFmLoginDialogState();
}

class _LastFmLoginDialogState extends State<LastFmLoginDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_usernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text('Please fill in all fields'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await widget.onLogin(
        _usernameController.text, _passwordController.text);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFD51007),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.music,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Last.fm Login'),
        ],
      ),
      description: const Text('Sign in to scrobble your plays'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadInput(
              controller: _usernameController,
              placeholder: const Text('Username'),
              leading: const Icon(LucideIcons.user, size: 16),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            ShadInput(
              controller: _passwordController,
              placeholder: const Text('Password'),
              leading: const Icon(LucideIcons.lock, size: 16),
              obscureText: true,
              enabled: !_isLoading,
              onSubmitted: (_) => _handleLogin(),
            ),
          ],
        ),
      ),
      actions: [
        ShadButton.ghost(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: _isLoading ? null : _handleLogin,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: ShadProgress(),
                )
              : const Text('Login'),
        ),
      ],
    );
  }
}
