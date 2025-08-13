// // lib/widgets/store_delivery_widgets.dart
// import 'package:flutter/material.dart';
// import 'package:toko_online_material/service/distance_service.dart';
// import 'package:toko_online_material/service/store_delevery_store.dart';

// /// Widget untuk menampilkan opsi pengiriman toko
// class StoreDeliveryOptionWidget extends StatelessWidget {
//   final StoreDeliveryOption option;
//   final bool isSelected;
//   final VoidCallback? onTap;
//   final bool showRecommendedBadge;

//   const StoreDeliveryOptionWidget({
//     super.key,
//     required this.option,
//     this.isSelected = false,
//     this.onTap,
//     this.showRecommendedBadge = true,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: isSelected 
//             ? [const Color(0xFF2E7D32).withOpacity(0.1), Colors.green.shade50]
//             : [Colors.white, Colors.white],
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//         ),
//         border: Border.all(
//           color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
//           width: isSelected ? 2 : 1,
//         ),
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: isSelected ? [
//           BoxShadow(
//             color: const Color(0xFF2E7D32).withOpacity(0.2),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ] : [],
//       ),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Row(
//             children: [
//               _buildIcon(),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: _buildContent(),
//               ),
//               _buildTrailing(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildIcon() {
//     return Container(
//       width: 50,
//       height: 50,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [const Color(0xFF2E7D32), Colors.green.shade400],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: const Color(0xFF2E7D32).withOpacity(0.3),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: const Icon(Icons.store, color: Colors.white, size: 24),
//     );
//   }

//   Widget _buildContent() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text(
//               option.name,
//               style: const TextStyle(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w600,
//                 color: Color(0xFF2D3748),
//               ),
//             ),
//             if (showRecommendedBadge) ...[
//               const SizedBox(width: 8),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [Colors.orange.shade400, Colors.orange.shade300],
//                   ),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Text(
//                   'REKOMENDASI',
//                   style: TextStyle(
//                     fontSize: 9,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ],
//           ],
//         ),
//         const SizedBox(height: 4),
//         Text(
//           option.description,
//           style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             _buildInfoChip(
//               Icons.location_on,
//               option.distance.distanceText,
//               Colors.blue[600]!,
//             ),
//             const SizedBox(width: 12),
//             _buildInfoChip(
//               Icons.access_time,
//               option.estimatedTime,
//               Colors.orange[600]!,
//             ),
//           ],
//         ),
//         if (option.distance.isEstimate) ...[
//           const SizedBox(height: 4),
//           Row(
//             children: [
//               Icon(Icons.info_outline, size: 12, color: Colors.grey[500]),
//               const SizedBox(width: 4),
//               Text(
//                 'Estimasi berdasarkan lokasi kota',
//                 style: TextStyle(
//                   fontSize: 10,
//                   color: Colors.grey[500],
//                   fontStyle: FontStyle.italic,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _buildInfoChip(IconData icon, String text, Color color) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, size: 14, color: color),
//         const SizedBox(width: 4),
//         Text(
//           text,
//           style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
//         ),
//       ],
//     );
//   }

//   Widget _buildTrailing() {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: [
//         Text(
//           option.formattedCost,
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             color: Color(0xFF2E7D32),
//           ),
//         ),
//         const SizedBox(height: 4),
//         if (isSelected) ...[
//           Container(
//             padding: const EdgeInsets.all(4),
//             decoration: const BoxDecoration(
//               color: Color(0xFF2E7D32),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.check,
//               color: Colors.white,
//               size: 16,
//             ),
//           ),
//         ] else ...[
//           Container(
//             width: 24,
//             height: 24,
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.grey.shade300, width: 2),
//               shape: BoxShape.circle,
//             ),
//           ),
//         ],
//       ],
//     );
//   }
// }

// /// Widget untuk menampilkan status ketersediaan pengiriman toko
// class StoreDeliveryAvailabilityWidget extends StatelessWidget {
//   final StoreDeliveryAvailability availability;
//   final VoidCallback? onTryAgain;

//   const StoreDeliveryAvailabilityWidget({
//     super.key,
//     required this.availability,
//     this.onTryAgain,
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (availability.isAvailable && availability.option != null) {
//       return _buildAvailableState();
//     } else {
//       return _buildUnavailableState();
//     }
//   }

//   Widget _buildAvailableState() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.green.shade50, Colors.green.shade100],
//           begin: Alignment.centerLeft,
//           end: Alignment.centerRight,
//         ),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.green.shade200),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.green.shade600,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Icon(Icons.check_circle, color: Colors.white, size: 20),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Pengiriman Toko Tersedia!',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.green.shade800,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       'Hemat biaya dengan pengiriman langsung dari toko',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.green.shade700,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               _buildFeature(Icons.local_shipping, 'Pengiriman Cepat'),
//               const SizedBox(width: 16),
//               _buildFeature(Icons.verified_user, 'Terpercaya'),
//               const SizedBox(width: 16),
//               _buildFeature(Icons.savings, 'Hemat Biaya'),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildUnavailableState() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade400,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Pengiriman Toko Tidak Tersedia',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Color(0xFF2D3748),
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       availability.reason ?? 'Alasan tidak diketahui',
//                       style: TextStyle(
//                         fontSize: 12,
//                         color: Colors.grey[600],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           if (onTryAgain != null) ...[
//             const SizedBox(height: 12),
//             SizedBox(
//               width: double.infinity,
//               child: OutlinedButton.icon(
//                 onPressed: onTryAgain,
//                 icon: const Icon(Icons.refresh, size: 16),
//                 label: const Text('Coba Lagi'),
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: const Color(0xFF2E7D32),
//                   side: const BorderSide(color: Color(0xFF2E7D32)),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildFeature(IconData icon, String text) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, size: 16, color: Colors.green.shade700),
//         const SizedBox(width: 4),
//         Text(
//           text,
//           style: TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w500,
//             color: Colors.green.shade700,
//           ),
//         ),
//       ],
//     );
//   }
// }

// /// Widget untuk menampilkan informasi pengiriman toko dalam checkout
// class StoreDeliveryCheckoutInfo extends StatelessWidget {
//   final StoreDeliveryOption option;
//   final bool showFullDetails;

//   const StoreDeliveryCheckoutInfo({
//     super.key,
//     required this.option,
//     this.showFullDetails = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.green.shade50, Colors.white],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.green.shade200),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [const Color(0xFF2E7D32), Colors.green.shade400],
//                   ),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: const Icon(Icons.store, color: Colors.white, size: 20),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Text(
//                           option.name,
//                           style: TextStyle(
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.green.shade800,
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: Colors.green.shade600,
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: const Text(
//                             'DIPILIH',
//                             style: TextStyle(
//                               fontSize: 9,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       option.description,
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: Colors.green.shade700,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Text(
//                 option.formattedCost,
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.green.shade800,
//                 ),
//               ),
//             ],
//           ),
//           if (showFullDetails) ...[
//             const SizedBox(height: 16),
//             const Divider(height: 1),
//             const SizedBox(height: 16),
//             _buildDetailRow(Icons.location_on, 'Jarak', option.distance.distanceText),
//             _buildDetailRow(Icons.access_time, 'Estimasi', option.estimatedTime),
//             _buildDetailRow(Icons.local_shipping, 'Pengiriman', 'Langsung dari Toko Barokah'),
//             if (option.distance.isEstimate)
//               _buildDetailRow(
//                 Icons.info_outline,
//                 'Catatan',
//                 'Jarak berdasarkan estimasi kota',
//                 isNote: true,
//               ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailRow(IconData icon, String label, String value, {bool isNote = false}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(
//             icon,
//             size: 16,
//             color: isNote ? Colors.orange.shade600 : Colors.green.shade600,
//           ),
//           const SizedBox(width: 8),
//           SizedBox(
//             width: 80,
//             child: Text(
//               label,
//               style: TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey[700],
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               value,
//               style: TextStyle(
//                 fontSize: 13,
//                 color: isNote ? Colors.orange.shade700 : const Color(0xFF2D3748),
//                 fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Widget untuk menampilkan loading state saat mengecek ketersediaan
// class StoreDeliveryLoadingWidget extends StatelessWidget {
//   final String message;

//   const StoreDeliveryLoadingWidget({
//     super.key,
//     this.message = 'Mengecek ketersediaan pengiriman toko...',
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.blue.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.blue.shade200),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           SizedBox(
//             width: 40,
//             height: 40,
//             child: CircularProgressIndicator(
//               strokeWidth: 3,
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Text(
//             message,
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//               color: Colors.blue.shade700,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Mohon tunggu sebentar...',
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.blue.shade600,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Widget untuk menampilkan banner promosi pengiriman toko
// class StoreDeliveryPromoBanner extends StatelessWidget {
//   final VoidCallback? onTap;
//   final String? customMessage;

//   const StoreDeliveryPromoBanner({
//     super.key,
//     this.onTap,
//     this.customMessage,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(16),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(16),
//         child: Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 const Color(0xFF2E7D32),
//                 Colors.green.shade400,
//                 Colors.green.shade300,
//               ],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color(0xFF2E7D32).withOpacity(0.3),
//                 blurRadius: 12,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: const Icon(
//                   Icons.local_offer,
//                   color: Colors.white,
//                   size: 28,
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Pengiriman Toko Tersedia!',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       customMessage ?? 'Hemat biaya pengiriman untuk wilayah sekitar toko',
//                       style: const TextStyle(
//                         fontSize: 13,
//                         color: Colors.white,
//                         height: 1.3,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         _buildFeatureBadge('Cepat'),
//                         const SizedBox(width: 8),
//                         _buildFeatureBadge('Murah'),
//                         const SizedBox(width: 8),
//                         _buildFeatureBadge('Terpercaya'),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               if (onTap != null)
//                 const Icon(
//                   Icons.arrow_forward_ios,
//                   color: Colors.white,
//                   size: 16,
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildFeatureBadge(String text) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white.withOpacity(0.3)),
//       ),
//       child: Text(
//         text,
//         style: const TextStyle(
//           fontSize: 10,
//           fontWeight: FontWeight.w600,
//           color: Colors.white,
//         ),
//       ),
//     );
//   }
// }