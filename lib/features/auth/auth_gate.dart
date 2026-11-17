import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' show ClientException;
import 'package:provider/provider.dart';
import 'package:sasatap/features/saved/saved_tag_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _authRedirectUrl = String.fromEnvironment('SUPABASE_AUTH_REDIRECT_URL');

typedef AuthenticatedHomeBuilder =
    Widget Function({
      required String? accountEmail,
      required Future<void> Function() onSignOut,
    });

class SupabaseAuthGate extends StatelessWidget {
  const SupabaseAuthGate({
    super.key,
    required this.client,
    required this.preferences,
    required this.homeBuilder,
  });

  final SupabaseClient client;
  final SharedPreferences preferences;
  final AuthenticatedHomeBuilder homeBuilder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _AuthLoading();
          }
          return const _AuthPage();
        }
        return _AuthenticatedHome(
          key: ValueKey(session.user.id),
          client: client,
          preferences: preferences,
          user: session.user,
          homeBuilder: homeBuilder,
        );
      },
    );
  }
}

class SupabaseConfigurationPage extends StatelessWidget {
  const SupabaseConfigurationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'SasaTap cloud setup required',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY with '
                  '--dart-define or --dart-define-from-file, then restart the '
                  'app. Saved tags are not available until authentication is '
                  'configured.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  const _AuthenticatedHome({
    super.key,
    required this.client,
    required this.preferences,
    required this.user,
    required this.homeBuilder,
  });

  final SupabaseClient client;
  final SharedPreferences preferences;
  final User user;
  final AuthenticatedHomeBuilder homeBuilder;

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  late final SavedTagRepository _savedTags;
  late Future<void> _loaded;

  @override
  void initState() {
    super.initState();
    _savedTags = SavedTagRepository(
      widget.preferences,
      userId: widget.user.id,
      client: widget.client,
    );
    _loaded = _savedTags.load();
  }

  @override
  void dispose() {
    _savedTags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loaded,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            message: snapshot.error.toString(),
            onRetry: () => setState(() {
              _loaded = _savedTags.load();
            }),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _AuthLoading();
        }
        return ChangeNotifierProvider<SavedTagRepository>.value(
          value: _savedTags,
          child: widget.homeBuilder(
            accountEmail: widget.user.email,
            onSignOut: () => widget.client.auth.signOut(),
          ),
        );
      },
    );
  }
}

enum _AuthMode { password, createAccount, magicLink }

class _AuthPage extends StatefulWidget {
  const _AuthPage();

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _AuthMode _mode = _AuthMode.password;
  bool _isSubmitting = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _message = null;
      _error = null;
    });
    final client = Supabase.instance.client;
    try {
      if (_mode == _AuthMode.magicLink) {
        await client.auth.signInWithOtp(
          email: _email.text.trim(),
          emailRedirectTo: _authRedirectUrl.isEmpty ? null : _authRedirectUrl,
        );
        _message = 'Check your email for a sign-in link.';
      } else if (_mode == _AuthMode.createAccount) {
        final response = await client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          emailRedirectTo: _authRedirectUrl.isEmpty ? null : _authRedirectUrl,
        );
        if (response.session == null) {
          _message = 'Check your email to confirm your new account.';
        }
      } else {
        await client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      _error = error.message;
    } on ClientException catch (error) {
      _error = 'Could not reach the sign-in service. $error';
    } on TimeoutException catch (error) {
      _error = 'The sign-in request timed out. $error';
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMagicLink = _mode == _AuthMode.magicLink;
    final isCreateAccount = _mode == _AuthMode.createAccount;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.contactless, size: 42, color: scheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        isCreateAccount
                            ? 'Create your SasaTap account'
                            : 'Welcome to SasaTap',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your saved tags are private to your account. You can '
                        'use SasaTap without joining an organization.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty || !email.contains('@')) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      if (!isMagicLink) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: isCreateAccount
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if ((value ?? '').length < 8) {
                              return 'Use at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: scheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          style: TextStyle(color: scheme.primary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isMagicLink
                                    ? 'Send magic link'
                                    : isCreateAccount
                                    ? 'Create account'
                                    : 'Sign in',
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() {
                                _mode = switch (_mode) {
                                  _AuthMode.password => _AuthMode.createAccount,
                                  _AuthMode.createAccount => _AuthMode.password,
                                  _AuthMode.magicLink => _AuthMode.password,
                                };
                                _error = null;
                                _message = null;
                              }),
                        child: Text(
                          isCreateAccount
                              ? 'Already have an account? Sign in'
                              : 'Create an account with a password',
                        ),
                      ),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() {
                                _mode = isMagicLink
                                    ? _AuthMode.password
                                    : _AuthMode.magicLink;
                                _error = null;
                                _message = null;
                              }),
                        child: Text(
                          isMagicLink
                              ? 'Use email and password'
                              : 'Sign in with a magic link',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Saved tags could not be loaded.'),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
