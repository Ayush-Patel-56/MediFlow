import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  final String role;

  const HelpPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = role == 'admin';
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'CMS Admin Help' : 'Facility Head Help'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                context,
                isAdmin 
                  ? 'Welcome to the Central Management System' 
                  : 'Welcome to the MediFlow Facility Portal',
                isAdmin
                  ? 'Manage system-wide logistics and optimize medical redistribution across all facilities.'
                  : 'Track your local inventory, predict demand with AI, and request supplies seamlessly.',
              ),
              const SizedBox(height: 48),
              Text(
                'How to use the application',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              isAdmin ? _buildAdminGuide(context) : _buildFacilityGuide(context),
              const SizedBox(height: 48),
              _buildCleanCard(
                context,
                Icons.lightbulb_outline,
                'Pro Tip',
                'Check the dashboard daily for system alerts. MediFlow AI works best when inventory logs are updated consistently.',
                Colors.orange.shade50,
                Colors.orange.shade900,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminGuide(BuildContext context) {
    return Column(
      children: [
        _buildStep(
          context,
          '1',
          'Facility Overview',
          'Monitor real-time inventory levels across all registered facilities. View total stock and critical shortage points at a glance.',
        ),
        _buildStep(
          context,
          '2',
          'Smart Routing',
          'Use the AI matching engine to identify redistribution opportunities. Shortages are automatically matched with surpluses based on proximity.',
        ),
        _buildStep(
          context,
          '3',
          'Plan Approval',
          'Review generated logistics paths and approve them to initiate medicine transfers across the network.',
        ),
      ],
    );
  }

  Widget _buildFacilityGuide(BuildContext context) {
    return Column(
      children: [
        _buildStep(
          context,
          '1',
          'Daily Logging',
          'Record distributed medicines in the Daily Log. This clean data fuels the AI forecasting engine for your facility.',
        ),
        _buildStep(
          context,
          '2',
          'AI Demand Forecast',
          'Predict future stock requirements by running the forecaster. Gemini AI analyzes your history to suggest optimal inventory levels.',
        ),
        _buildStep(
          context,
          '3',
          'Create Indents',
          'When stock is low, use the Indents tab to request more. AI-suggested quantities help minimize waste and ensure patient care.',
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context, String number, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanCard(BuildContext context, IconData icon, String title, String content, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(color: textColor.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
