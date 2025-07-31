import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

// Function to show image viewer
void showImageViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  String? productName,
}) {
  if (imageUrls.isEmpty) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ImageViewerPage(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
        productName: productName,
      ),
    ),
  );
}

class ImageViewerPage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? productName;

  const ImageViewerPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.productName,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleAppBar() {
    setState(() {
      _showAppBar = !_showAppBar;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showAppBar
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.5),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: widget.productName != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.productName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_currentIndex + 1} dari ${widget.imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '${_currentIndex + 1} dari ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {
                    // Implement share functionality
                    _shareImage();
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'download':
                        _downloadImage();
                        break;
                      case 'info':
                        _showImageInfo();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download),
                          SizedBox(width: 12),
                          Text('Download'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline),
                          SizedBox(width: 12),
                          Text('Info Gambar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          // Image Gallery
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(widget.imageUrls[index]),
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2.0,
                heroAttributes: PhotoViewHeroAttributes(
                  tag: 'image_$index',
                ),
                onTapUp: (context, details, controllerValue) {
                  _toggleAppBar();
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Gagal memuat gambar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(
              color: Colors.black,
            ),
          ),

          // Image Indicator (Dots)
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showAppBar ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.imageUrls.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Navigation Arrows (for larger screens)
          if (widget.imageUrls.length > 1 && MediaQuery.of(context).size.width > 600) ...[
            // Previous Arrow
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showAppBar ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: IconButton(
                    onPressed: _currentIndex > 0
                        ? () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: _currentIndex > 0
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),

            // Next Arrow
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showAppBar ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: IconButton(
                    onPressed: _currentIndex < widget.imageUrls.length - 1
                        ? () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        : null,
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      color: _currentIndex < widget.imageUrls.length - 1
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Gesture Instructions (Show briefly on first load)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              opacity: _showAppBar ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tap untuk sembunyikan menu • Pinch untuk zoom • Swipe untuk gambar lain',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareImage() {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur share akan segera hadir'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _downloadImage() {
    // Implement download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mengunduh gambar ${_currentIndex + 1}...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showImageInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Info Gambar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Nama Produk:', widget.productName ?? 'Tidak diketahui'),
            _buildInfoRow('Gambar:', '${_currentIndex + 1} dari ${widget.imageUrls.length}'),
            _buildInfoRow('URL:', widget.imageUrls[_currentIndex]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Simple Image Viewer Widget (for embedding in other screens)
class SimpleImageViewer extends StatelessWidget {
  final List<String> imageUrls;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const SimpleImageViewer({
    super.key,
    required this.imageUrls,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius,
        ),
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            size: 48,
            color: Colors.grey,
          ),
        ),
      );
    }

    if (imageUrls.length == 1) {
      return GestureDetector(
        onTap: () => showImageViewer(context, imageUrls: imageUrls),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
          ),
          child: ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: CachedNetworkImage(
              imageUrl: imageUrls.first,
              height: height,
              width: double.infinity,
              fit: fit,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.error, color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => showImageViewer(
              context,
              imageUrls: imageUrls,
              initialIndex: index,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: borderRadius ?? BorderRadius.zero,
                    child: CachedNetworkImage(
                      imageUrl: imageUrls[index],
                      height: height,
                      width: double.infinity,
                      fit: fit,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                  if (imageUrls.length > 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${index + 1}/${imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}