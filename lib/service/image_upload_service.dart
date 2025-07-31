import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Pick single image from camera or gallery
  static Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Pick multiple images from gallery
  static Future<List<XFile>?> pickMultipleImages({int maxImages = 10}) async {
    try {
      final List<XFile>? images = await _picker.pickMultiImage (
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (images != null && images.length > maxImages) {
        return images.take(maxImages).toList();
      }
      
      return images;
    } catch (e) {
      print('Error picking multiple images: $e');
      return null;
    }
  }

  // Show dialog to choose image source
  static Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Sumber Gambar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );
  }

  // Get image file size in MB
  static Future<double> getImageSize(XFile image) async {
    final File file = File(image.path);
    final int fileSizeInBytes = await file.length();
    final double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    return fileSizeInMB;
  }

  // Upload single image to Firebase Storage
  static Future<String> uploadImage({
    required XFile imageFile,
    required String folder,
    String? customName,
  }) async {
    try {
      final String fileName = customName ?? 
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      
      final Reference ref = _storage.ref().child('$folder/$fileName');
      
      final UploadTask uploadTask = ref.putFile(File(imageFile.path));
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Gagal mengupload gambar: $e');
    }
  }

  // Upload multiple images to Firebase Storage
  static Future<List<String>> uploadMultipleImages({
    required List<XFile> imageFiles,
    required String folder,
    Function(int completed, int total)? onProgress,
  }) async {
    final List<String> downloadUrls = [];
    
    try {
      for (int i = 0; i < imageFiles.length; i++) {
        final String fileName = 
            '${DateTime.now().millisecondsSinceEpoch}_$i${path.extension(imageFiles[i].path)}';
        
        final Reference ref = _storage.ref().child('$folder/$fileName');
        final UploadTask uploadTask = ref.putFile(File(imageFiles[i].path));
        
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        
        downloadUrls.add(downloadUrl);
        
        // Call progress callback
        onProgress?.call(i + 1, imageFiles.length);
      }
      
      return downloadUrls;
    } catch (e) {
      print('Error uploading multiple images: $e');
      throw Exception('Gagal mengupload gambar: $e');
    }
  }

  // Delete image from Firebase Storage
  static Future<void> deleteImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting image: $e');
      // Don't throw error for delete operations to avoid blocking user actions
    }
  }

  // Delete multiple images from Firebase Storage
  static Future<void> deleteMultipleImages(List<String> imageUrls) async {
    try {
      final List<Future<void>> deleteTasks = imageUrls
          .map((url) => deleteImage(url))
          .toList();
      
      await Future.wait(deleteTasks);
    } catch (e) {
      print('Error deleting multiple images: $e');
      // Don't throw error for delete operations
    }
  }

  // Compress image before upload (optional)
  static Future<XFile?> compressImage({
    required XFile imageFile,
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    try {
      // This would require image compression package like flutter_image_compress
      // For now, we use the built-in compression from ImagePicker
      return imageFile;
    } catch (e) {
      print('Error compressing image: $e');
      return imageFile;
    }
  }

  // Get image dimensions
  static Future<Size?> getImageDimensions(XFile imageFile) async {
    try {
      final File file = File(imageFile.path);
      // This would require image package to get dimensions
      // For now, return null
      return null;
    } catch (e) {
      print('Error getting image dimensions: $e');
      return null;
    }
  }

  // Validate image file
  static bool isValidImageFile(XFile imageFile) {
    final String extension = path.extension(imageFile.path).toLowerCase();
    final List<String> validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    
    return validExtensions.contains(extension);
  }

  // Get image file extension
  static String getImageExtension(XFile imageFile) {
    return path.extension(imageFile.path).toLowerCase();
  }

  // Generate unique filename
  static String generateUniqueFileName({
    String? originalName,
    String? extension,
  }) {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String ext = extension ?? '.jpg';
    
    if (originalName != null) {
      final String nameWithoutExt = path.basenameWithoutExtension(originalName);
      return '${timestamp}_${nameWithoutExt}$ext';
    }
    
    return '$timestamp$ext';
  }

  // Batch upload with retry mechanism
  static Future<List<String>> uploadImagesWithRetry({
    required List<XFile> imageFiles,
    required String folder,
    int maxRetries = 3,
    Function(int completed, int total)? onProgress,
    Function(String error)? onError,
  }) async {
    final List<String> downloadUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      int retryCount = 0;
      bool uploaded = false;
      
      while (retryCount < maxRetries && !uploaded) {
        try {
          final String url = await uploadImage(
            imageFile: imageFiles[i],
            folder: folder,
          );
          
          downloadUrls.add(url);
          uploaded = true;
          onProgress?.call(i + 1, imageFiles.length);
        } catch (e) {
          retryCount++;
          if (retryCount >= maxRetries) {
            onError?.call('Gagal mengupload gambar ${i + 1} setelah $maxRetries percobaan: $e');
            throw Exception('Gagal mengupload gambar ${i + 1}');
          }
          
          // Wait before retry
          await Future.delayed(Duration(seconds: retryCount));
        }
      }
    }
    
    return downloadUrls;
  }

  // Clear image cache (if using cached_network_image)
  static Future<void> clearImageCache() async {
    try {
      // This would clear cached_network_image cache
      // await CachedNetworkImage.evictFromCache(imageUrl);
    } catch (e) {
      print('Error clearing image cache: $e');
    }
  }
}