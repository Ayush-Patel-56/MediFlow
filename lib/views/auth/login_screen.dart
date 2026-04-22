import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/firebase_service.dart';
import '../../firebase_options.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String role; // 'facility' or 'admin'
  const LoginScreen({super.key, required this.role});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _seedDatabase() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(firebaseServiceProvider).seedDemoData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database seeded! Log in using urban@mediflow.com / password123')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seeding: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final cred = await ref.read(firebaseServiceProvider).login(
            _emailController.text.trim(),
            _passwordController.text,
          );
      
      if (widget.role == 'facility') {
        final fac = await ref.read(firebaseServiceProvider).getFacility(cred.user!.uid);
        if (fac != null) {
          if (mounted) context.go('/facility/${fac.id}/overview');
        } else {
          throw Exception("No facility configuration found for this account.");
        }
      } else {
        // Admin
        if (mounted) context.go('/admin/overview');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString().split(']').last.trim()}')), // Clean error output
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFacility = widget.role == 'facility';
    final primaryColor = isFacility ? Colors.teal : Colors.indigo;

    return Scaffold(
      body: Row(
        children: [
          // LEFT: Illustration
          Expanded(
            child: Container(
              color: primaryColor.withValues(alpha: 0.05),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFacility ? Icons.vaccines : Icons.admin_panel_settings,
                      size: 200,
                      color: primaryColor.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      isFacility ? 'Facility Portal' : 'Admin Portal',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: primaryColor.withValues(alpha: 0.8),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 64),
                      child: Text(
                        isFacility
                            ? 'Manage your daily logs, track inventory, and forecast indents using AI.'
                            : 'Monitor global stock levels and dynamically optimize redistribution routes.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[700],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // RIGHT: Form
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Project: ${DefaultFirebaseOptions.web.projectId}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 10),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome Back',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please sign in to your secure account',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 48),

                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 48),
                      Center(
                        child: TextButton.icon(
                          onPressed: _isLoading ? null : _seedDatabase,
                          icon: const Icon(Icons.dataset),
                          label: const Text('Initialize / Seed Database'),
                          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                        ),
                      ),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Roles'),
                          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

