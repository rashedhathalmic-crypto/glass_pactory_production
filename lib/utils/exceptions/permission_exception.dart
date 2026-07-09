import 'app_exception.dart';

class PermissionException extends AppException {
  const PermissionException(super.message, {super.code});
}
