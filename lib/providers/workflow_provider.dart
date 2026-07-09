import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/workflow_service.dart';
import '../services/storage_service.dart';
import 'production_order_provider.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(FirebaseStorage.instance);
});

final workflowServiceProvider = Provider<WorkflowService>((ref) {
  return WorkflowService(
    ref.read(productionOrderRepositoryProvider),
    ref.read(historyServiceProvider),
    ref.read(storageServiceProvider),
  );
});
