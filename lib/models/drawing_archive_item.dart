class DrawingArchiveItem {
  const DrawingArchiveItem({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.projectName,
    required this.drawingNumber,
    required this.glassType,
    required this.pdfUrl,
    required this.dxfUrl,
    this.createdAt,
  });

  final String orderId;
  final String orderNumber;
  final String customerName;
  final String projectName;
  final String drawingNumber;
  final String glassType;
  final String pdfUrl;
  final String dxfUrl;
  final DateTime? createdAt;

  bool get hasPdf => pdfUrl.isNotEmpty;
  bool get hasDxf => dxfUrl.isNotEmpty;
}
