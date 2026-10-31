import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'tx.dart';

/// A predefined category for transactions.
class Category {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final TxType type;

  const Category({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.type,
  });
}

const List<Category> kCategories = [
  // ── Income ────────────────────────────────────────────────
  Category(
      id: 'salary',
      label: 'Salary',
      icon: LucideIcons.briefcase,
      color: Color(0xFF10B981),
      type: TxType.income),
  Category(
      id: 'freelance',
      label: 'Freelance',
      icon: LucideIcons.laptop,
      color: Color(0xFF84CC16),
      type: TxType.income),
  Category(
      id: 'investments',
      label: 'Investments',
      icon: LucideIcons.trendingUp,
      color: Color(0xFF14B8A6),
      type: TxType.income),
  Category(
      id: 'pocket-money',
      label: 'Pocket money',
      icon: LucideIcons.wallet,
      color: Color(0xFF22C55E),
      type: TxType.income),
  Category(
      id: 'scholarship',
      label: 'Scholarship',
      icon: LucideIcons.award,
      color: Color(0xFF0EA5E9),
      type: TxType.income),
  Category(
      id: 'family-transfer',
      label: 'Family transfer',
      icon: LucideIcons.users,
      color: Color(0xFF8B5CF6),
      type: TxType.income),
  Category(
      id: 'gift',
      label: 'Gift',
      icon: LucideIcons.gift,
      color: Color(0xFFF97316),
      type: TxType.income),
  Category(
      id: 'other-income',
      label: 'Other',
      icon: LucideIcons.banknote,
      color: Color(0xFFEAB308),
      type: TxType.income),

  // ── Expense ───────────────────────────────────────────────
  Category(
      id: 'groceries',
      label: 'Groceries',
      icon: LucideIcons.shoppingCart,
      color: Color(0xFFF59E0B),
      type: TxType.expense),
  Category(
      id: 'food',
      label: 'Food & dining',
      icon: LucideIcons.utensils,
      color: Color(0xFFEF4444),
      type: TxType.expense),
  Category(
      id: 'transport',
      label: 'Transport',
      icon: LucideIcons.car,
      color: Color(0xFF3B82F6),
      type: TxType.expense),
  Category(
      id: 'rent',
      label: 'Rent & housing',
      icon: LucideIcons.home,
      color: Color(0xFF8B5CF6),
      type: TxType.expense),
  Category(
      id: 'utilities',
      label: 'Utilities',
      icon: LucideIcons.zap,
      color: Color(0xFF06B6D4),
      type: TxType.expense),
  Category(
      id: 'entertainment',
      label: 'Entertainment',
      icon: LucideIcons.film,
      color: Color(0xFFEC4899),
      type: TxType.expense),
  Category(
      id: 'health',
      label: 'Health',
      icon: LucideIcons.heart,
      color: Color(0xFFF43F5E),
      type: TxType.expense),
  Category(
      id: 'shopping',
      label: 'Shopping',
      icon: LucideIcons.shoppingBag,
      color: Color(0xFFD946EF),
      type: TxType.expense),
  Category(
      id: 'travel',
      label: 'Travel',
      icon: LucideIcons.plane,
      color: Color(0xFF0EA5E9),
      type: TxType.expense),
  Category(
      id: 'education',
      label: 'Education',
      icon: LucideIcons.bookOpen,
      color: Color(0xFF6366F1),
      type: TxType.expense),
  Category(
      id: 'hostel',
      label: 'Hostel & mess',
      icon: LucideIcons.home,
      color: Color(0xFF7C3AED),
      type: TxType.expense),
  Category(
      id: 'study',
      label: 'Books & study',
      icon: LucideIcons.bookOpen,
      color: Color(0xFF4F46E5),
      type: TxType.expense),
  Category(
      id: 'bills',
      label: 'Bills',
      icon: LucideIcons.receipt,
      color: Color(0xFF64748B),
      type: TxType.expense),
  Category(
      id: 'other',
      label: 'Other',
      icon: LucideIcons.moreHorizontal,
      color: Color(0xFF94A3B8),
      type: TxType.expense),
];

Category categoryById(String id) => kCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => kCategories.last,
    );

/// Categories usable for the given transaction type.
List<Category> categoriesFor(TxType type) =>
    kCategories.where((c) => c.type == type).toList();

/// Best-effort category for an imported or detected description.
String categoryIdForText(String text, {bool income = false}) {
  final haystack = text.toLowerCase();
  if (income) {
    if (haystack.contains('scholarship') || haystack.contains('stipend')) {
      return 'scholarship';
    }
    if (haystack.contains('pocket money') ||
        haystack.contains('pocket-money')) {
      return 'pocket-money';
    }
    if (haystack.contains('family') || haystack.contains('parents')) {
      return 'family-transfer';
    }
    return 'other-income';
  }
  bool any(List<String> needles) => needles.any(haystack.contains);
  if (any([
    'blinkit',
    'zepto',
    'instamart',
    'bigbasket',
    'dmart',
    'grocer',
    'supermarket',
    'kirana'
  ])) {
    return 'groceries';
  }
  if (any([
    'swiggy',
    'zomato',
    'restaurant',
    'cafe',
    'coffee',
    'eats',
    'food',
    'dining',
    'bakery'
  ])) {
    return 'food';
  }
  if (any([
    'uber',
    'ola ',
    'rapido',
    'metro',
    'fuel',
    'petrol',
    'diesel',
    'cab',
    'toll'
  ])) {
    return 'transport';
  }
  if (any(['rent', 'landlord', 'housing'])) return 'rent';
  if (any([
    'amazon',
    'flipkart',
    'myntra',
    'ajio',
    'nykaa',
    'store',
    'shop',
    'mall'
  ])) {
    return 'shopping';
  }
  if (any([
    'electricity',
    'water bill',
    'broadband',
    'recharge',
    'airtel',
    'jio',
    'gas bill',
    'utility'
  ])) {
    return 'utilities';
  }
  if (any([
    'netflix',
    'spotify',
    'prime video',
    'hotstar',
    'bookmyshow',
    'cinema',
    'movie'
  ])) {
    return 'entertainment';
  }
  if (any(['pharmacy', 'apollo', 'hospital', 'clinic', 'doctor'])) {
    return 'health';
  }
  if (any(['flight', 'hotel', 'irctc', 'makemytrip', 'travel'])) {
    return 'travel';
  }
  if (any(['hostel', 'mess fee', 'mess bill', 'dorm', 'pg rent'])) {
    return 'hostel';
  }
  if (any(['school', 'college', 'course', 'udemy', 'tuition', 'book'])) {
    return 'education';
  }
  if (any(['bill', 'insurance', 'premium', 'subscription'])) return 'bills';
  return 'other';
}
