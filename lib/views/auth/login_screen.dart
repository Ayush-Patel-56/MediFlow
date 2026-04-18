import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/facility.dart';
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
  List<Facility> _facilities = [];
  Facility? _selectedFacility;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.role == 'facility') {
      _loadFacilities();
    }
  }

  Future<void> _loadFacilities() async {
    setState(() => _isLoading = true);
    try {
      final facs = await ref.read(firebaseServiceProvider).getFacilities();
      setState(() {
        _facilities = facs;
        if (facs.isNotEmpty) _selectedFacility = facs.first;
      });
    } catch (e) {
      print('Error loading facilities: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seedDatabase() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(firebaseServiceProvider).seedDemoData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database seeded successfully!')),
      );
      if (widget.role == 'facility') {
        _loadFacilities();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seeding: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (widget.role == 'facility') {
        if (_selectedFacility != null) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _selectedFacility!.email,
            password: _passwordController.text.trim(),
          );
          if (mounted) context.go('/facility/${_selectedFacility!.id}/overview');
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) context.go('/admin/overview');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
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
              color: primaryColor.withOpacity(0.05),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFacility ? Icons.vaccines : Icons.admin_panel_settings,
                      size: 200,
                      color: primaryColor.withOpacity(0.2),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      isFacility ? 'Facility Portal' : 'Admin Portal',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: primaryColor.withOpacity(0.8),
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
                        'Please sign in to your account',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 48),

                      if (isFacility) ...[
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (_facilities.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.orange),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'No facilities found. Please initialize the database below.',
                                    style: TextStyle(color: Colors.orange[800]),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          DropdownButtonFormField<Facility>(
                            decoration: InputDecoration(
                              labelText: 'Select Facility',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            value: _selectedFacility,
                            items: _facilities.map((f) {
                              return DropdownMenuItem(
                                value: f,
                                child: Text(f.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedFacility = val);
                            },
                          ),
                        const SizedBox(height: 24),
                      ],

                      if (!isFacility) ...[
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Admin Email',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
                          onPressed: (_isLoading || (isFacility && _facilities.isEmpty)) ? null : _login,
                          child: const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
