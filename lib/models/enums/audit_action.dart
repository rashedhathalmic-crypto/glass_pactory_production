enum AuditAction {
  create,
  update,
  delete,
  transfer,
  approval,
  login,
  logout,
  userActivity;

  String get label => switch (this) {
        AuditAction.create => 'Create',
        AuditAction.update => 'Update',
        AuditAction.delete => 'Delete',
        AuditAction.transfer => 'Transfer',
        AuditAction.approval => 'Approval',
        AuditAction.login => 'Login',
        AuditAction.logout => 'Logout',
        AuditAction.userActivity => 'User Activity',
      };

  static AuditAction fromString(String value) {
    return AuditAction.values.firstWhere(
      (action) => action.name == value,
      orElse: () => AuditAction.userActivity,
    );
  }
}
