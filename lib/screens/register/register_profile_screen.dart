import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/user_service.dart';
import '../home/home_screen.dart';

// En register_profile_screen.dart
class RegisterProfileScreen extends StatefulWidget {
  final String? phone; // Añadir esta línea
  final String? prefillEmail;
  final String? prefillName;

  const RegisterProfileScreen({
    super.key,
    this.phone,
    this.prefillEmail,
    this.prefillName,
  }); // Modificar esta línea

  @override
  State<RegisterProfileScreen> createState() => _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends State<RegisterProfileScreen> {
  final UserService userService = UserService();

  final TextEditingController nameController = TextEditingController();

  bool isLoading = false;

  int selectedAvatar = 0;

  final List<String> avatars = ["⚽", "🔥", "🦁", "🐺", "👑", "💎", "🚀", "🏆"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              AppColors.midnightBlue,
              AppColors.primaryPurple,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 35),

                    const Text(
                      'Completa\nTu Perfil',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Elige un nombre y un avatar para comenzar.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 45),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: TextField(
                        controller: nameController,
                        maxLength: 15,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          hintText: 'Tu nombre',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 45),

                    const Text(
                      'Selecciona tu avatar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 25),

                    SizedBox(
                      height: 95,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: avatars.length,
                        itemBuilder: (_, index) {
                          final isSelected = selectedAvatar == index;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedAvatar = index;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(right: 15),
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: isSelected
                                    ? const LinearGradient(
                                        colors: [
                                          AppColors.primaryPurple,
                                          AppColors.energeticRed,
                                        ],
                                      )
                                    : null,
                                color: isSelected
                                    ? null
                                    : Colors.white.withOpacity(0.06),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryPurple
                                              .withOpacity(0.5),
                                          blurRadius: 25,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Text(
                                  avatars[index],
                                  style: const TextStyle(fontSize: 38),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const Spacer(),

                    GestureDetector(
                      onTap: () async {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ingresa tu nombre')),
                          );

                          return;
                        }

                        setState(() {
                          isLoading = true;
                        });

                        try {
                          await userService.createUser(
                            name: nameController.text.trim(),

                            avatar: avatars[selectedAvatar],
                          );

                          setState(() {
                            isLoading = false;
                          });

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                            (route) => false,
                          );
                        } catch (e) {
                          setState(() {
                            isLoading = false;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text(e.toString()),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primaryPurple,
                              AppColors.energeticRed,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.4),
                              blurRadius: 25,
                            ),
                          ],
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'COMPLETAR REGISTRO',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
