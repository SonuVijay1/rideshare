import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/autocomplete_service.dart';
import '../../services/location_service.dart';

class LocationSearchScreen extends StatefulWidget {
  final String hintText;

  const LocationSearchScreen({super.key, required this.hintText});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AutocompleteService _autocompleteService = AutocompleteService();
  final LocationService _locationService = LocationService();

  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().length < 3) {
        setState(() => _suggestions = []);
        return;
      }

      setState(() => _isLoading = true);
      try {
        final results = await _autocompleteService.getSuggestions(query);
        if (mounted) {
          setState(() => _suggestions = results);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final loc = await _locationService.getCurrentLocationSuggestion();
      if (loc != null && mounted) {
        Navigator.pop(context, loc);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A1F25), Color(0xFF000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                if (_isLoading)
                  const LinearProgressIndicator(
                    color: Colors.white,
                    backgroundColor: Colors.white10,
                    minHeight: 2,
                  ),
                Expanded(
                  child: _suggestions.isEmpty && _controller.text.isEmpty
                      ? _buildEmptyState()
                      : _buildList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _suggestions = []);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location, color: Colors.blueAccent),
          ),
          title: const Text("Use current location",
              style: TextStyle(color: Colors.white)),
          onTap: _useCurrentLocation,
        ),
        // You can add "Recent Locations" here if you have that service available
      ],
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => Divider(
        color: Colors.white.withOpacity(0.05),
        height: 1,
        indent: 56,
      ),
      itemBuilder: (context, index) {
        final item = _suggestions[index];
        return ListTile(
          leading:
              const Icon(Icons.location_on_outlined, color: Colors.white54),
          title: Text(
            item['title'] ?? '',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            item['subtitle'] ?? '',
            style: const TextStyle(color: Colors.white38),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.pop(context, item),
        );
      },
    );
  }
}
