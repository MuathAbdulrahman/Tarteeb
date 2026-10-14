import 'package:flutter/material.dart';

/// Habit icons available in the picker (keys are stored in the database).
const Map<String, IconData> kHabitIcons = {
  'check': Icons.check_circle_outline,
  'wallet': Icons.account_balance_wallet_outlined,
  'fitness': Icons.fitness_center,
  'walk': Icons.directions_walk,
  'run': Icons.directions_run,
  'book': Icons.menu_book_outlined,
  'bed': Icons.bedtime_outlined,
  'water': Icons.water_drop_outlined,
  'meditation': Icons.self_improvement,
  'pray': Icons.brightness_3_outlined,
  'food': Icons.restaurant_outlined,
  'no_sugar': Icons.do_not_disturb_alt,
  'study': Icons.school_outlined,
  'write': Icons.edit_note,
  'phone_off': Icons.phonelink_erase,
  'sun': Icons.wb_sunny_outlined,
  'heart': Icons.favorite_border,
  'pill': Icons.medication_outlined,
  'clean': Icons.cleaning_services_outlined,
  'language': Icons.translate,
};

IconData habitIcon(String key) => kHabitIcons[key] ?? Icons.check_circle_outline;

const Map<String, IconData> kExpenseIcons = {
  'food': Icons.restaurant_outlined,
  'groceries': Icons.local_grocery_store_outlined,
  'transport': Icons.directions_car_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'bills': Icons.receipt_long_outlined,
  'entertainment': Icons.movie_outlined,
  'health': Icons.local_hospital_outlined,
  'other': Icons.category_outlined,
};

IconData expenseIcon(String key) => kExpenseIcons[key] ?? Icons.category_outlined;

/// Colors offered for categories and habits.
const List<int> kPickerColors = [
  0xFF3B7DD8,
  0xFF2E9E8F,
  0xFFC77D2E,
  0xFF7E57C2,
  0xFFD8556B,
  0xFF4F9D5D,
  0xFF5C6BC0,
  0xFFE07A3F,
  0xFF7D8794,
  0xFF00838F,
];
