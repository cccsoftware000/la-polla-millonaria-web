import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../auth/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

  final PageController controller = PageController();

  int currentPage = 0;

  final List<Map<String, String>> pages = [

    {
      "title": "Predice marcadores\ny gana millones",
      "subtitle":
      "Participa en jornadas únicas y demuestra que sabes de fútbol.",
      "icon": "⚽"
    },

    {
      "title": "Acumulados\ncada vez más grandes",
      "subtitle":
      "Mientras más crezca el premio, más épica será la experiencia.",
      "icon": "🔥"
    },

    {
      "title": "Crea tus apuestas\nen segundos",
      "subtitle":
      "Rápido, simple y diseñado para vivir el fútbol al máximo.",
      "icon": "🏆"
    },
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.background,
              Color(0xFF111827),
              Color(0xFF7B2FF7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  itemBuilder: (_, index) {

                    final item = pages[index];

                    return Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          Text(
                            item["icon"]!,
                            style: const TextStyle(
                              fontSize: 110,
                            ),
                          ),

                          const SizedBox(height: 40),

                          Text(
                            item["title"]!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 25),

                          Text(
                            item["subtitle"]!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 17,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                      (index) {

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: currentPage == index ? 30 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: currentPage == index
                            ? Colors.white
                            : Colors.white24,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: GestureDetector(
                  onTap: () async {

                    final prefs =
                    await SharedPreferences.getInstance();

                    await prefs.setBool(
                      'hasSeenOnboarding',
                      true,
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WelcomeScreen(), // 👈 Cambiar LoginScreen por WelcomeScreen
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF7B2FF7),
                          Color(0xFFFF3B5C),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.5),
                          blurRadius: 25,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "INICIAR",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}