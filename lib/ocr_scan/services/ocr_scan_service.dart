import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as ml_kit;
import 'package:ocr_scan_text/ocr_scan/model/scan_match_counter.dart';

import '../../ocr_scan_text.dart';
import '../render/scan_renderer.dart';

enum Mode {
  camera,
  static,
}

class OcrScanService {
  static Mode _actualMode = Mode.camera;
  static Mode get actualMode => _actualMode;
  List<ScanModule> scanModules;

  /// MLKit text detection object
  final ml_kit.TextRecognizer textRecognizer = ml_kit.TextRecognizer();

  OcrScanService(
    this.scanModules,
  );

  /// Launch the search for results from the image for all the modules started
  Future<OcrTextRecognizerResult?> processImage(
    ml_kit.InputImage inputImage,
    Size imageSize,
    ui.Image? background,
    Mode mode,
    List<ScanModule> scanModules,
    ml_kit.TextRecognizer? recognizer,
  ) async {
    _actualMode = mode;
    ml_kit.TextRecognizer textRecognizer =
        recognizer ?? ml_kit.TextRecognizer();

    /// Ask MLKit to return the list of TextBlocks in the image
    final recognizedText = await textRecognizer.processImage(inputImage);

    /// create a global String corresponding to the texts found by MLKIt
    String scannedText = '';
    List<ml_kit.TextElement> textBlocks = [];
    for (final textBlock in recognizedText.blocks) {
      for (final element in textBlock.lines) {
        for (final textBlock in element.elements) {
          textBlocks.add(textBlock);
          scannedText += " ${textBlock.text}";
        }
      }
    }

    /// Start the text search for each module
    Map<ScanModule, List<ScanMatchCounter>> mapModule =
        <ScanModule, List<ScanMatchCounter>>{};
    for (var scanModule in scanModules) {
      if (!scanModule.started) {
        continue;
      }

      /// Generate the results of each module
      List<ScanMatchCounter> scanLines = await scanModule.generateResult(
        recognizedText.blocks,
        scannedText,
        imageSize,
      );

      mapModule.putIfAbsent(
        scanModule,
        () => scanLines,
      );
    }

    /// Create a ScanRenderer to display the visual rendering of the results found
    var painter = ScanRenderer(
      mapScanModules: mapModule,
      imageRotation: inputImage.metadata?.rotation ??
          ml_kit.InputImageRotation.rotation90deg,
      imageSize: imageSize,
      background: background,
    );

    Map<ScanModule, List<ScanResult>> mapResult =
        <ScanModule, List<ScanResult>>{};
    mapModule.forEach((key, matchCounterList) {
      List<ScanResult> list = matchCounterList
          .where(
            (matchCounter) => matchCounter.validated == true,
          )
          .map<ScanResult>((e) => e.scanResult)
          .toList();

      if (list.isNotEmpty) {
        mapResult.putIfAbsent(key, () => list);
      }
    });

    await textRecognizer.close();
    if (mapResult.isEmpty) {
      return null;
    }

    return OcrTextRecognizerResult(
      CustomPaint(
        painter: painter,
      ),
      mapResult,
    );
  }
}

class OcrTextRecognizerResult {
  CustomPaint customPaint;
  Map<ScanModule, List<ScanResult>> mapResult;

  OcrTextRecognizerResult(this.customPaint, this.mapResult);
}
