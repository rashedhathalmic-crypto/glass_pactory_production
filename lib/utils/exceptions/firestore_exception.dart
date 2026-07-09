import 'app_exception.dart';

class FirestoreException extends AppException {
  const FirestoreException(super.message, {super.code});
}
