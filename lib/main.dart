import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const FFmpegApp());
}

class FFmpegApp extends StatelessWidget {
  const FFmpegApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FFmpeg Super Fast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? videoPath;
  String? audioPath;
  String mode = 'COPY';
  String resolution = '720p';
  bool isProcessing = false;
  String statusMessage = "Pilih file video & audio untuk memulai";

  @override
  void initState() {
    super.initState();
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<void> pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() => videoPath = result.files.single.path);
    }
  }

  Future<void> pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() => audioPath = result.files.single.path);
    }
  }

  Future<void> startProcess() async {
    if (videoPath == null || audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Harap pilih file Video dan Audio!')),
      );
      return;
    }

    setState(() {
      isProcessing = true;
      statusMessage = "Membaca durasi...";
    });

    try {
      var probeSession = await FFprobeKit.getMediaInformation(audioPath!);
      var mediaInfo = probeSession.getMediaInformation();
      String? durationStr = mediaInfo?.getDuration();
      double totalDuration = double.tryParse(durationStr ?? '0') ?? 0;

      String outputFileName = "output_${DateTime.now().millisecondsSinceEpoch}.mp4";
      String outputPath = "/storage/emulated/0/Download/$outputFileName";

      String ffmpegCommand = "";
      if (mode == 'COPY') {
        ffmpegCommand = "-stream_loop -1 -i \"$videoPath\" -i \"$audioPath\" -map 0:v:0 -map 1:a:0 -c:v copy -c:a copy -t $totalDuration -avoid_negative_ts make_zero \"$outputPath\"";
      } else {
        String scaleFlag = "scale=-2:720:flags=fast_bilinear";
        if (resolution == '360p') scaleFlag = "scale=-2:360:flags=fast_bilinear";
        if (resolution == '480p') scaleFlag = "scale=-2:480:flags=fast_bilinear";
        if (resolution == '1080p') scaleFlag = "scale=-2:1080:flags=fast_bilinear";

        ffmpegCommand = "-stream_loop -1 -i \"$videoPath\" -i \"$audioPath\" -map 0:v:0 -map 1:a:0 -vf $scaleFlag -c:v libx264 -preset ultrafast -crf 28 -pix_fmt yuv420p -c:a aac -b:a 128k -t $totalDuration -movflags +faststart \"$outputPath\"";
      }

      setState(() => statusMessage = "Proses penggabungan sedang berjalan...");

      FFmpegKit.executeAsync(ffmpegCommand, (session) async {
        final returnCode = await session.getReturnCode();
        setState(() => isProcessing = false);

        if (ReturnCode.isSuccess(returnCode)) {
          setState(() => statusMessage = "✅ BERHASIL! Disimpan di:\n$outputPath");
        } else {
          setState(() => statusMessage = "❌ GAGAL memproses video.");
        }
      });
    } catch (e) {
      setState(() {
        isProcessing = false;
        statusMessage = "Terjadi kesalahan: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🚀 FFmpeg Super Fast'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: pickVideo,
              icon: const Icon(Icons.movie),
              label: Text(videoPath == null ? "Pilih Video" : videoPath!.split('/').last),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: pickAudio,
              icon: const Icon(Icons.audiotrack),
              label: Text(audioPath == null ? "Pilih Audio" : audioPath!.split('/').last),
            ),
            const SizedBox(height: 20),
            DropdownButton<String>(
              value: mode,
              items: ['COPY', 'RESOLUSI'].map((m) => DropdownMenuItem(value: m, child: Text("Mode: $m"))).toList(),
              onChanged: (val) => setState(() => mode = val!),
            ),
            if (mode == 'RESOLUSI')
              DropdownButton<String>(
                value: resolution,
                items: ['360p', '480p', '720p', '1080p'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) => setState(() => resolution = val!),
              ),
            const SizedBox(height: 30),
            isProcessing
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: startProcess,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("GENERATE VIDEO", style: TextStyle(color: Colors.white)),
                  ),
            const SizedBox(height: 20),
            Text(statusMessage, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
