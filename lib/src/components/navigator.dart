import 'package:flutter/material.dart';
import '../pages/shopping_list_page.dart';
import '../pages/recipes.dart';
import '../pages/registry.dart';
import '../pages/products_page.dart';

class Navigation extends StatelessWidget {
  final VoidCallback toggleTheme;

  const Navigation({super.key, required this.toggleTheme});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: TabBarView(
          children: [
            const ShoppingListPage(),
            const RecipesPage(),
            const RegistryPage(),
            ProductsPage(toggleTheme: toggleTheme),
          ],
        ),
        bottomNavigationBar: const BottomAppBar(
          padding: EdgeInsets.zero,
          child: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.shopping_cart_outlined)),
              Tab(icon: Icon(Icons.receipt_long_rounded)),
              Tab(icon: Icon(Icons.history)),
              Tab(icon: Icon(Icons.storefront_outlined)),
            ],
          ),
        ),
      ),
    );
  }
}
