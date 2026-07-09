import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AppIcons extends ThemeExtension<AppIcons> {
  const AppIcons();

  static const IconData dashboard = Symbols.dashboard;
  static const IconData orders = Symbols.assignment;
  static const IconData users = Symbols.group;
  static const IconData departments = Symbols.factory;
  static const IconData reports = Symbols.analytics;
  static const IconData settings = Symbols.settings;
  static const IconData logout = Symbols.logout;
  static const IconData add = Symbols.add;
  static const IconData edit = Symbols.edit;
  static const IconData delete = Symbols.delete;
  static const IconData search = Symbols.search;
  static const IconData filter = Symbols.filter_list;
  static const IconData refresh = Symbols.refresh;
  static const IconData visibility = Symbols.visibility;
  static const IconData check = Symbols.check_circle;
  static const IconData warning = Symbols.warning;
  static const IconData error = Symbols.error;
  static const IconData menu = Symbols.menu;
  static const IconData close = Symbols.close;
  static const IconData arrowForward = Symbols.arrow_forward;
  static const IconData arrowBack = Symbols.arrow_back;
  static const IconData glassProcessing = Icons.precision_manufacturing;
  static const IconData grinding = Symbols.water_drop;
  static const IconData assembly = Symbols.precision_manufacturing;
  static const IconData quality = Symbols.verified;
  static const IconData delivery = Symbols.local_shipping;
  static const IconData history = Symbols.history;
  static const IconData person = Symbols.person;
  static const IconData lock = Symbols.lock;
  static const IconData email = Symbols.mail;
  static const IconData calendar = Symbols.calendar_today;
  static const IconData upload = Symbols.upload_file;
  static const IconData download = Symbols.download;
  static const IconData play = Symbols.play_arrow;
  static const IconData pause = Symbols.pause;
  static const IconData hold = Symbols.pause_circle;
  static const IconData complete = Symbols.task_alt;
  static const IconData save = Symbols.save;
  static const IconData print = Symbols.print;
  static const IconData qr = Symbols.qr_code_2;
  static const IconData image = Symbols.image;
  static const IconData notifications = Symbols.notifications;
  static const IconData archive = Symbols.folder_open;
  static const IconData management = Symbols.monitoring;
  static const IconData audit = Symbols.fact_check;

  @override
  AppIcons copyWith() => this;

  @override
  AppIcons lerp(covariant ThemeExtension<AppIcons>? other, double t) => this;
}
