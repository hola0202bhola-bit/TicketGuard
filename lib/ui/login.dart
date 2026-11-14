import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'design.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.client, this.onResetConnection});

  final SupabaseClient client;
  final VoidCallback? onResetConnection;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscured = true;
  String? _note;
  bool _error = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final email = _email.text.trim();
      final password = _password.text;
      const limit = Duration(seconds: 15);
      if (_register) {
        final response = await widget.client.auth
            .signUp(email: email, password: password)
            .timeout(limit);
        if (mounted && response.session == null) {
          setState(() {
            _register = false;
            _error = false;
            _note = 'Revisa tu correo para confirmar la cuenta y después inicia sesión.';
          });
        }
      } else {
        await widget.client.auth
            .signInWithPassword(email: email, password: password)
            .timeout(limit);
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = true;
          _note = switch (error.code) {
            'email_not_confirmed' => 'Confirma tu correo para iniciar sesión.',
            'invalid_credentials' => 'Revisa el correo y la contraseña.',
            'over_email_send_rate_limit' =>
              'Espera unos minutos antes de pedir otro correo.',
            'user_already_exists' => 'Ya existe una cuenta con ese correo.',
            _ =>
              'No pudimos completar el acceso. Revisa tus datos y la conexión.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _note = 'Sin respuesta del servidor. Revisa la conexión e inténtalo de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: Form(
            key: _form,
            child: BoundedList(
              children: [
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandMark(size: 64),
                ),
                const SizedBox(height: 22),
                Text('TicketGuard', style: text.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Tus comprobantes y garantías, en un solo lugar.',
                  style: text.bodyLarge?.copyWith(color: stone),
                ),
                const SizedBox(height: 35),
                Text(
                  _register ? 'Crea tu cuenta' : 'Inicia sesión',
                  style: text.headlineMedium,
                ),
                const SizedBox(height: 16),
                if (_note != null) ...[
                  Notice(_note!, warning: _error),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) =>
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Escribe un correo válido.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  autofillHints: [
                    _register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  obscureText: _obscured,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_busy) unawaited(_submit());
                  },
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscured
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: () => setState(() => _obscured = !_obscured),
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Escribe tu contraseña.';
                    }
                    if (_register && value.length < 8) {
                      return 'Usa al menos 8 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    _busy
                        ? 'Conectando…'
                        : (_register ? 'Crear cuenta' : 'Entrar'),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _register = !_register;
                          _note = null;
                        }),
                  child: Text(
                    _register ? 'Ya tengo cuenta' : 'Crear una cuenta',
                  ),
                ),
                if (widget.onResetConnection != null)
                  TextButton(
                    onPressed: _busy ? null : widget.onResetConnection,
                    child: const Text('Cambiar conexión'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
