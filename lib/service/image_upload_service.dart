import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  // Pick image from gallery or camera
  static Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      return image;
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image: $e');
      }
      return null;
    }
  }

  // Pick multiple images
  static Future<List<XFile>?> pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      return images;
    } catch (e) {
      if (kDebugMode) {
        print('Error picking multiple images: $e');
      }
      return null;
    }
  }

  // Upload single image to Firebase Storage
  static Future<String?> uploadImage({
    required XFile imageFile,
    required String folder,
    String? fileName,
    Function(double)? onProgress,
  }) async {
    try {
      // Generate unique filename if not provided
      fileName ??= '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      
      // Create storage reference
      final Reference ref = _storage.ref().child('$folder/$fileName');
      
      // Upload file
      late UploadTask uploadTask;
      
      if (kIsWeb) {
        // For web platform
        final Uint8List imageData = await imageFile.readAsBytes();
        uploadTask = ref.putData(
          imageData,
          SettableMetadata(contentType: 'image/${imageFile.name.split('.').last}'),
        );
      } else {
        // For mobile platforms
        final File file = File(imageFile.path);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/${imageFile.name.split('.').last}'),
        );
      }

      // Listen to upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (kDebugMode) {
        print('Image uploaded successfully: $downloadUrl');
      }
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      return null;
    }
  }

  // Upload multiple images
  static Future<List<String>> uploadMultipleImages({
    required List<XFile> imageFiles,
    required String folder,
    Function(int completed, int total)? onProgress,
  }) async {
    final List<String> downloadUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      final String? url = await uploadImage(
        imageFile: imageFiles[i],
        folder: folder,
      );
      
      if (url != null) {
        downloadUrls.add(url);
      }
      
      // Report progress
      if (onProgress != null) {
        onProgress(i + 1, imageFiles.length);
      }
    }
    
    return downloadUrls;
  }

  // Delete image from Firebase Storage
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      
      if (kDebugMode) {
        print('Image deleted successfully: $imageUrl');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting image: $e');
      }
      return false;
    }
  }

  // Delete multiple images
  static Future<List<bool>> deleteMultipleImages(List<String> imageUrls) async {
    final List<bool> results = [];
    
    for (String url in imageUrls) {
      final bool success = await deleteImage(url);
      results.add(success);
    }
    
    return results;
  }

  // Get image file size in MB
  static Future<double> getImageSize(XFile imageFile) async {
    try {
      final int sizeInBytes = await imageFile.length();
      return sizeInBytes / (1024 * 1024); // Convert to MB
    } catch (e) {
      return 0.0;
    }
  }

  // Validate image file
  static bool isValidImage(XFile imageFile) {
    final List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    final String extension = imageFile.name.split('.').last.toLowerCase();
    return allowedExtensions.contains(extension);
  }

  // Get image dimensions (for mobile only)
  static Future<Map<String, int>?> getImageDimensions(XFile imageFile) async {
    if (kIsWeb) return null;
    
    try {
      final File file = File(imageFile.path);
      // This would require additional package like flutter_image_compress
      // For now, return null
      return null;
    } catch (e) {
      return null;
    }
  }

  // Show image source selection dialog
  static Future<ImageSource?> showImageSourceDialog(context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Sumber Gambar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  // Compress image quality based on file size
  static int getOptimalQuality(double sizeInMB) {
    if (sizeInMB > 5) return 60;
    if (sizeInMB > 3) return 70;
    if (sizeInMB > 1) return 80;
    return 85;
  }
}