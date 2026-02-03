import 'package:flutter/material.dart';
import 'package:deeplink_sdk/deeplink_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeeplinkExampleApp());
}

class DeeplinkExampleApp extends StatelessWidget {
  const DeeplinkExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deeplink SDK Testbed',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TestbedScreen(),
    );
  }
}

class TestbedScreen extends StatefulWidget {
  const TestbedScreen({super.key});

  @override
  State<TestbedScreen> createState() => _TestbedScreenState();
}

class _TestbedScreenState extends State<TestbedScreen> {
  final Deeplink _deeplink = Deeplink();

  Map<String, dynamic>? _initResult;
  bool _initDone = false;
  final List<Uri> _incomingUris = [];
  final ScrollController _listScroll = ScrollController();

  static const String _sampleNativeUrl = 'https://example.com/native';
  static const String _sampleWebUrl = 'https://example.com/fallback';

  @override
  void initState() {
    super.initState();
    _runInit();
    _listenToIncomingLinks();
  }

  Future<void> _runInit() async {
    final result = await _deeplink.init();
    if (mounted) {
      setState(() {
        _initResult = result;
        _initDone = true;
      });
    }
  }

  void _listenToIncomingLinks() {
    _deeplink.uriStream.listen((Uri uri) {
      if (mounted) {
        setState(() {
          _incomingUris.insert(0, uri);
          if (_incomingUris.length > 50) _incomingUris.removeLast();
        });
        _listScroll.hasClients
            ? _listScroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut)
            : null;
      }
    });
  }

  Future<void> _openSmartLink() async {
    final launched = await _deeplink.openSmartLink(_sampleNativeUrl, _sampleWebUrl);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(launched ? 'Opened link' : 'Could not open link')),
      );
    }
  }

  @override
  void dispose() {
    _listScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deeplink SDK Testbed'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            '1. Attribution (init)',
            _initDone
                ? (_initResult != null
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _initResult!.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      )
                    : const Text('Not first run (or non-mobile): no install track call. Result: null.'))
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          _section(
            '2. Incoming links (uriStream)',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Tap a link (App Link / custom scheme) to open this app. Latest links:'),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: _incomingUris.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No links received yet.', style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      : ListView.builder(
                          controller: _listScroll,
                          itemCount: _incomingUris.length,
                          itemBuilder: (_, i) {
                            final uri = _incomingUris[i];
                            return ListTile(
                              dense: true,
                              title: SelectableText(uri.toString(), style: const TextStyle(fontSize: 12)),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _section(
            '3. Smart routing (openSmartLink)',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Try native URL first; fallback to web URL.'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _openSmartLink,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open smart link'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
