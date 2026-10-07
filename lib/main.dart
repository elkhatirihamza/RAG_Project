import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

void main() => runApp(const RagApp());

class RagApp extends StatelessWidget {
  const RagApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Atlas RAG',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0e7490)),
          scaffoldBackgroundColor: const Color(0xfff7f8f5),
          useMaterial3: true,
          fontFamily: 'Avenir',
        ),
        home: const ChatPage(),
      );
}

class ChatMessage {
  const ChatMessage({required this.text, required this.user, this.sources = const []});
  final String text;
  final bool user;
  final List<Map<String, dynamic>> sources;
}

class DocumentItem {
  const DocumentItem({required this.id, required this.name, required this.pages});
  final String id;
  final String name;
  final int pages;

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
        id: json['id'] as String,
        name: json['name'] as String,
        pages: json['pages'] as int,
      );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final questionController = TextEditingController();
  final scrollController = ScrollController();
  final messages = <ChatMessage>[];
  final documents = <DocumentItem>[];
  final selectedIds = <String>{};
  bool loading = false;
  bool uploading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  @override
  void dispose() {
    questionController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadDocuments() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/api/documents'));
      if (response.statusCode != 200) throw Exception();
      final data = jsonDecode(response.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        documents
          ..clear()
          ..addAll(data.map((item) => DocumentItem.fromJson(item as Map<String, dynamic>)));
      });
    } catch (_) {
      if (mounted) setState(() => error = 'Connectez le backend pour charger vos documents.');
    }
  }

  Future<void> uploadDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'docx'],
      withData: true,
    );
    final picked = result?.files.single;
    if (picked == null || picked.bytes == null) return;
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/api/documents/upload'))
        ..files.add(http.MultipartFile.fromBytes('file', picked.bytes!, filename: picked.name));
      final response = await request.send();
      if (response.statusCode != 201) throw Exception(await response.stream.bytesToString());
      await loadDocuments();
    } catch (_) {
      if (mounted) setState(() => error = 'Indexation impossible. Vérifiez le backend et GOOGLE_API_KEY.');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> sendQuestion() async {
    final question = questionController.text.trim();
    if (question.isEmpty || loading) return;
    questionController.clear();
    setState(() {
      error = null;
      loading = true;
      messages.add(ChatMessage(text: question, user: true));
    });
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'conversation_id': 'default',
          'question': question,
          'document_ids': selectedIds.toList(),
          'history': messages.take(12).map((message) => {
                'role': message.user ? 'user' : 'assistant',
                'content': message.text,
              }).toList(),
        }),
      );
      if (response.statusCode != 200) throw Exception();
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() => messages.add(ChatMessage(
            text: data['answer'] as String,
            user: false,
            sources: (data['sources'] as List<dynamic>).cast<Map<String, dynamic>>(),
          )));
    } catch (_) {
      if (mounted) setState(() => error = 'Réponse indisponible. Vérifiez que le backend est lancé.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Row(children: [buildSidebar(), Expanded(child: buildChat())]),
        ),
      );

  Widget buildSidebar() => Container(
        width: 292,
        padding: const EdgeInsets.fromLTRB(22, 24, 18, 18),
        decoration: const BoxDecoration(
          color: Color(0xff103b42),
          borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.auto_awesome, color: Color(0xfff3c969)), SizedBox(width: 10), Text('ATLAS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 2.2))]),
          const SizedBox(height: 36),
          FilledButton.icon(
            onPressed: () => setState(messages.clear),
            icon: const Icon(Icons.add, size: 19),
            label: const Text('Nouveau chat'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xfff3c969), foregroundColor: const Color(0xff103b42), minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 30),
          const Text('CONVERSATIONS', style: TextStyle(color: Color(0xff8eb2b3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 13),
          sidebarRow(Icons.chat_bubble_outline, 'Exploration de documents', true),
          const SizedBox(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('DOCUMENTS', style: TextStyle(color: Color(0xff8eb2b3), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            IconButton(onPressed: uploadDocument, icon: const Icon(Icons.add, color: Color(0xfff3c969)), tooltip: 'Ajouter un document'),
          ]),
          Expanded(
            child: documents.isEmpty
                ? const Text('Aucun document indexé', style: TextStyle(color: Color(0xffb0c7c6), fontSize: 13))
                : ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final document = documents[index];
                      return CheckboxListTile(
                        value: selectedIds.contains(document.id),
                        onChanged: (value) => setState(() => value == true ? selectedIds.add(document.id) : selectedIds.remove(document.id)),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: const Color(0xfff3c969),
                        checkColor: const Color(0xff103b42),
                        title: Text(document.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text('${document.pages} page${document.pages > 1 ? 's' : ''}', style: const TextStyle(color: Color(0xff8eb2b3), fontSize: 11)),
                      );
                    },
                  ),
          ),
          const Divider(color: Color(0xff2e5b60)),
          const Text('Gemini connecté côté serveur', style: TextStyle(color: Color(0xff8eb2b3), fontSize: 12)),
        ]),
      );

  Widget sidebarRow(IconData icon, String label, bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: active ? const Color(0xff1c5056) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [Icon(icon, size: 18, color: const Color(0xfff3c969)), const SizedBox(width: 10), Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)))]),
      );

  Widget buildChat() => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 24, 34, 18),
          child: LayoutBuilder(builder: (context, constraints) {
            const title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RAG assistant', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xff173d42))),
              SizedBox(height: 3),
              Text('Vos documents, enfin consultables naturellement.', style: TextStyle(color: Color(0xff688081), fontSize: 13)),
            ]);
            const status = Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 8, color: Color(0xff23856f)),
                SizedBox(width: 7),
                Text('Prêt', style: TextStyle(color: Color(0xff17614f), fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            );
            if (constraints.maxWidth < 520) {
              return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, SizedBox(height: 10), Align(alignment: Alignment.centerRight, child: status)]);
            }
            return const Row(children: [title, Spacer(), status]);
          }),
        ),
        const Divider(height: 1, color: Color(0xffdfe7e3)),
        if (error != null) Padding(padding: const EdgeInsets.fromLTRB(34, 14, 34, 0), child: Align(alignment: Alignment.centerLeft, child: Text(error!, style: const TextStyle(color: Color(0xffb34b40), fontSize: 13)))),
        Expanded(child: messages.isEmpty ? emptyState() : ListView.builder(controller: scrollController, padding: const EdgeInsets.fromLTRB(34, 28, 34, 28), itemCount: messages.length, itemBuilder: (context, index) => messageBubble(messages[index]))),
        if (uploading) const LinearProgressIndicator(minHeight: 2, color: Color(0xff0e7490)),
        composer(),
      ]);

  Widget emptyState() => Center(child: SingleChildScrollView(padding: const EdgeInsets.all(34), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 70, height: 70, decoration: BoxDecoration(color: const Color(0xffdff0eb), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.menu_book_rounded, color: Color(0xff0e7490), size: 33)),
        const SizedBox(height: 22),
        const Text('Commencez par une question', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xff173d42))),
        const SizedBox(height: 9),
        const Text('Importez vos documents, puis demandez un résumé, une explication ou une comparaison.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xff688081), height: 1.5)),
        const SizedBox(height: 24),
        Wrap(spacing: 10, runSpacing: 10, children: ['Résume ce chapitre', 'Explique simplement', 'Compare les documents'].map((text) => ActionChip(label: Text(text), onPressed: () => questionController.text = text)).toList()),
      ])));

  Widget messageBubble(ChatMessage message) => Align(
        alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 22),
          constraints: const BoxConstraints(maxWidth: 760),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: message.user ? const Color(0xff103b42) : Colors.white,
            borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(message.user ? 18 : 4), bottomRight: Radius.circular(message.user ? 4 : 18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message.user ? 'VOUS' : 'ATLAS', style: TextStyle(color: message.user ? const Color(0xfff3c969) : const Color(0xff0e7490), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            const SizedBox(height: 8),
            SelectableText(message.text, style: TextStyle(color: message.user ? Colors.white : const Color(0xff29484a), height: 1.5, fontSize: 15)),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 17),
              const Divider(color: Color(0xffe2e9e5)),
              const SizedBox(height: 8),
              const Text('SOURCES', style: TextStyle(color: Color(0xff688081), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ...message.sources.map((source) => Padding(padding: const EdgeInsets.only(top: 7), child: Row(children: [const Icon(Icons.description_outlined, size: 16, color: Color(0xff0e7490)), const SizedBox(width: 7), Expanded(child: Text('${source['document']} · page ${source['page'] ?? 'n/a'}', style: const TextStyle(color: Color(0xff456a6b), fontSize: 12)))]))),
            ],
          ]),
        ),
      );

  Widget composer() => Padding(padding: const EdgeInsets.fromLTRB(34, 0, 34, 24), child: Container(padding: const EdgeInsets.fromLTRB(17, 6, 7, 6), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xffd6e3df)), borderRadius: BorderRadius.circular(17)), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        IconButton(onPressed: uploadDocument, icon: const Icon(Icons.attach_file, color: Color(0xff688081)), tooltip: 'Ajouter un document'),
        Expanded(child: TextField(controller: questionController, minLines: 1, maxLines: 5, onSubmitted: (_) => sendQuestion(), decoration: const InputDecoration(hintText: 'Posez votre question...', border: InputBorder.none))),
        IconButton(onPressed: loading ? null : sendQuestion, style: IconButton.styleFrom(backgroundColor: const Color(0xff0e7490), foregroundColor: Colors.white), icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward), tooltip: 'Envoyer'),
      ])));
}
