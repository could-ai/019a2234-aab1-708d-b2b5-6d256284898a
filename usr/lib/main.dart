import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus File Share',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const FileShareHomePage(),
    );
  }
}

class FileShareHomePage extends StatefulWidget {
  const FileShareHomePage({super.key});

  @override
  State<FileShareHomePage> createState() => _FileShareHomePageState();
}

class _FileShareHomePageState extends State<FileShareHomePage> {
  List<File> _postedFiles = [];
  Directory? _sharedDir;

  @override
  void initState() {
    super.initState();
    _initializeSharedDirectory();
    _loadPostedFiles();
  }

  Future<void> _initializeSharedDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    _sharedDir = Directory('${directory.path}/shared_files');
    if (!await _sharedDir!.exists()) {
      await _sharedDir!.create(recursive: true);
    }
  }

  Future<void> _loadPostedFiles() async {
    if (_sharedDir == null) await _initializeSharedDirectory();
    final files = _sharedDir!.listSync().whereType<File>().toList();
    setState(() {
      _postedFiles = files;
    });
  }

  Future<void> _postFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final newFile = await file.copy('${_sharedDir!.path}/$fileName');

      setState(() {
        _postedFiles.add(newFile);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File "$fileName" posted successfully!')),
      );
    }
  }

  Future<void> _downloadFile(File file) async {
    // Request storage permission for download
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission required for download')),
      );
      return;
    }

    try {
      final downloadsDir = await getExternalStorageDirectory();
      final fileName = file.path.split('/').last;
      final downloadPath = '${downloadsDir!.path}/$fileName';
      await file.copy(downloadPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded to: $downloadPath')),
      );

      // Optionally open the file
      final result = await OpenFilex.open(downloadPath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file automatically')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus File Share'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _postedFiles.isEmpty
          ? const Center(
              child: Text(
                'No files posted yet.\nTap the + button to post your first file!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _postedFiles.length,
              itemBuilder: (context, index) {
                final file = _postedFiles[index];
                final fileName = file.path.split('/').last;
                final fileSize = file.lengthSync();
                final fileSizeText = fileSize < 1024
                    ? '$fileSize B'
                    : fileSize < 1024 * 1024
                        ? '${(fileSize / 1024).toStringAsFixed(1)} KB'
                        : '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(fileName),
                    subtitle: Text('Size: $fileSizeText'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _downloadFile(file),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _postFile,
        tooltip: 'Post a file',
        child: const Icon(Icons.add),
      ),
    );
  }
}
